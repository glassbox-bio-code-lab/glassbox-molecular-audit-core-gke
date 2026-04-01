from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
import time
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile, WebSocket, WebSocketDisconnect, Query
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from kubernetes import client, config
from kubernetes.client import ApiException


APP_VERSION = os.getenv("GBX_CONSOLE_VERSION", "1.0.1")
NAMESPACE_DEFAULT = os.getenv("POD_NAMESPACE", "glassbox-mol-audit")
RUNNER_IMAGE = os.getenv(
    "GBX_RUNNER_IMAGE",
    "us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit:1.0.1",
)
RUNNER_SA = os.getenv("GBX_RUNNER_SERVICE_ACCOUNT", "default")

# Where uploads and run bundles are stored (should be a PVC/GCS mount).
DATA_ROOT = Path(os.getenv("GBX_DATA_ROOT", "/data")).resolve()
UPLOADS_DIR = DATA_ROOT / "uploads"
BUNDLES_DIR = DATA_ROOT / "bundles"

POLL_INTERVAL_SEC = float(os.getenv("GBX_STATUS_POLL_INTERVAL_SEC", "2.0"))
LOG_TAIL_LINES = int(os.getenv("GBX_LOG_TAIL_LINES", "200"))

# Basic schema enforcement (extend as you like)
REQUIRED_INPUTS = ["targets.csv", "compounds.csv", "assays.csv", "sources.json"]


# -----------------------
# Kubernetes client setup
# -----------------------
def _load_kube() -> None:
    try:
        config.load_incluster_config()
    except Exception:
        config.load_kube_config()


_load_kube()
core = client.CoreV1Api()
batch = client.BatchV1Api()

app = FastAPI(title="Glassbox In-Cluster Console", version=APP_VERSION)

# If you have a built React bundle, mount it.
UI_DIR = os.getenv("GBX_UI_DIR", "")
if UI_DIR and Path(UI_DIR).exists():
    app.mount("/", StaticFiles(directory=UI_DIR, html=True), name="ui")


# -----------------------
# Models
# -----------------------
@dataclass
class PreflightIssue:
    level: str  # "error" | "warning"
    code: str
    message: str
    path: Optional[str] = None


@dataclass
class PreflightResult:
    status: str  # "pass" | "warn" | "fail"
    issues: List[PreflightIssue]
    recommended_profile: str  # starter|standard|gpu
    inputs: Dict[str, Dict[str, Any]]  # file -> {path, sha256, bytes}
    generated_at: str
    validator_version: str


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _safe_run_id(prefix: str = "run") -> str:
    return f"{prefix}_{hashlib.sha256(f'{time.time()}'.encode()).hexdigest()[:12]}"


def _ensure_dirs() -> None:
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    BUNDLES_DIR.mkdir(parents=True, exist_ok=True)


_ensure_dirs()


# -----------------------
# Preflight validation
# -----------------------
def validate_inputs(run_id: str, run_dir: Path) -> PreflightResult:
    issues: List[PreflightIssue] = []
    inputs_meta: Dict[str, Dict[str, Any]] = {}

    # Required files present
    for req in REQUIRED_INPUTS:
        p = run_dir / req
        if not p.exists():
            issues.append(PreflightIssue(
                level="error",
                code="missing_required_file",
                message=f"Missing required input: {req}",
                path=req,
            ))
        else:
            sha = _sha256_file(p)
            inputs_meta[req] = {"path": str(p), "sha256": sha, "bytes": p.stat().st_size}

    # Lightweight content checks (extend with your real schema rules)
    for csv_name in ["targets.csv", "compounds.csv", "assays.csv"]:
        p = run_dir / csv_name
        if p.exists():
            first_line = p.read_text(errors="ignore").splitlines()[:1]
            if not first_line or "," not in first_line[0]:
                issues.append(PreflightIssue(
                    level="warning",
                    code="csv_header_suspect",
                    message=f"{csv_name} header may be malformed.",
                    path=csv_name,
                ))

    # sources.json must parse
    sj = run_dir / "sources.json"
    if sj.exists():
        try:
            json.loads(sj.read_text(encoding="utf-8"))
        except Exception:
            issues.append(PreflightIssue(
                level="error",
                code="sources_json_invalid",
                message="sources.json is not valid JSON.",
                path="sources.json",
            ))

    has_error = any(i.level == "error" for i in issues)
    has_warn = any(i.level == "warning" for i in issues)
    status = "fail" if has_error else ("warn" if has_warn else "pass")

    total_bytes = sum(v["bytes"] for v in inputs_meta.values()) if inputs_meta else 0
    if total_bytes < 5_000_000:
        profile = "starter"
    elif total_bytes < 50_000_000:
        profile = "standard"
    else:
        profile = "gpu"

    return PreflightResult(
        status=status,
        issues=issues,
        recommended_profile=profile,
        inputs=inputs_meta,
        generated_at=_utc_now(),
        validator_version=APP_VERSION,
    )


def generate_run_bundle(run_id: str, run_dir: Path, preflight: PreflightResult) -> Path:
    bundle_dir = BUNDLES_DIR / run_id
    bundle_dir.mkdir(parents=True, exist_ok=True)

    (bundle_dir / "preflight_report.json").write_text(
        json.dumps(asdict(preflight), indent=2, sort_keys=True),
        encoding="utf-8",
    )

    input_hashes = {k: v["sha256"] for k, v in preflight.inputs.items()}
    (bundle_dir / "inputs_hashes.json").write_text(
        json.dumps(input_hashes, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    values_yaml = f"""# Generated by Glassbox Preflight ({APP_VERSION})
config:
  projectId: "{run_id}"
  runId: "{run_id}"
profile: "{preflight.recommended_profile}"
"""
    (bundle_dir / "values.generated.yaml").write_text(values_yaml, encoding="utf-8")

    return bundle_dir


# -----------------------
# Kubernetes job launcher
# -----------------------
def _job_name_for(run_id: str) -> str:
    base = re.sub(r"[^a-z0-9-]+", "-", run_id.lower())
    base = base.strip("-")
    return f"gbx-audit-{base[:40]}"


def create_runner_job(namespace: str, run_id: str, input_dir: Path, bundle_dir: Path) -> str:
    job_name = _job_name_for(run_id)
    if not RUNNER_IMAGE.strip():
        raise RuntimeError(
            "GBX_RUNNER_IMAGE is required. Set it to a region-appropriate Artifact Registry image reference."
        )

    env = [
        client.V1EnvVar(name="GBX_RUN_ID", value=run_id),
        client.V1EnvVar(name="GBX_INPUT_DIR", value=str(input_dir)),
        client.V1EnvVar(name="GBX_BUNDLE_DIR", value=str(bundle_dir)),
    ]
    for env_name in (
        "GOOGLE_CLOUD_REGION",
        "GOOGLE_CLOUD_LOCATION",
        "GBX_DEPLOY_REGION",
        "GBX_DEPLOY_LOCATION",
        "GBX_DATA_RESIDENCY",
        "GBX_EGRESS_MODE",
        "GBX_OPTIONAL_ANALYTICS_ENABLED",
        "GBX_ALLOWED_EGRESS_DOMAINS",
        "GBX_REGION_TRACEABILITY",
        "TZ",
    ):
        value = (os.getenv(env_name) or "").strip()
        if value:
            env.append(client.V1EnvVar(name=env_name, value=value))

    volume_name = "gbx-data"
    pvc_name = os.getenv("GBX_DATA_PVC", "glassbox-mol-audit-data")

    volumes = [client.V1Volume(
        name=volume_name,
        persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(claim_name=pvc_name)
    )]

    mounts = [client.V1VolumeMount(name=volume_name, mount_path=str(DATA_ROOT))]

    container = client.V1Container(
        name="runner",
        image=RUNNER_IMAGE,
        image_pull_policy="IfNotPresent",
        env=env,
        volume_mounts=mounts,
    )

    template = client.V1PodTemplateSpec(
        metadata=client.V1ObjectMeta(labels={"app": "glassbox-mol-audit", "run-id": run_id}),
        spec=client.V1PodSpec(
            restart_policy="Never",
            service_account_name=RUNNER_SA,
            containers=[container],
            volumes=volumes,
        )
    )

    job_spec = client.V1JobSpec(template=template, backoff_limit=0)
    job = client.V1Job(
        api_version="batch/v1",
        kind="Job",
        metadata=client.V1ObjectMeta(name=job_name, labels={"app": "glassbox-mol-audit", "run-id": run_id}),
        spec=job_spec,
    )

    try:
        batch.create_namespaced_job(namespace=namespace, body=job)
    except ApiException as e:
        if e.status == 409:
            return job_name
        raise

    return job_name


# -----------------------
# API endpoints
# -----------------------
@app.get("/api/version")
def api_version() -> JSONResponse:
    return JSONResponse({"version": APP_VERSION})


@app.post("/api/preflight")
async def api_preflight(
    project_id: str = Form(...),
    files: List[UploadFile] = File(...),
):
    run_id = _safe_run_id(prefix=project_id)
    run_dir = UPLOADS_DIR / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    saved = 0
    for f in files:
        name = Path(f.filename).name
        dest = run_dir / name
        content = await f.read()
        dest.write_bytes(content)
        saved += 1

    if saved == 0:
        raise HTTPException(status_code=400, detail="No files uploaded.")

    preflight = validate_inputs(run_id, run_dir)
    bundle_dir = generate_run_bundle(run_id, run_dir, preflight)

    return JSONResponse({
        "run_id": run_id,
        "preflight": asdict(preflight),
        "bundle_dir": str(bundle_dir),
        "uploads_dir": str(run_dir),
    })


@app.post("/api/run")
def api_run(
    run_id: str,
    namespace: str = NAMESPACE_DEFAULT,
):
    run_dir = UPLOADS_DIR / run_id
    bundle_dir = BUNDLES_DIR / run_id
    if not run_dir.exists() or not bundle_dir.exists():
        raise HTTPException(status_code=404, detail="run_id not found. Run preflight first.")

    pf_path = bundle_dir / "preflight_report.json"
    if pf_path.exists():
        pf = json.loads(pf_path.read_text(encoding="utf-8"))
        if pf.get("status") == "fail":
            raise HTTPException(status_code=400, detail="Preflight failed. Fix inputs before running.")

    job_name = create_runner_job(namespace, run_id, run_dir, bundle_dir)
    return JSONResponse({"run_id": run_id, "namespace": namespace, "job": job_name})


# -----------------------
# WebSocket: live status + optional logs
# -----------------------
async def _send(ws: WebSocket, payload: Dict[str, Any]) -> None:
    await ws.send_text(json.dumps(payload, separators=(",", ":"), ensure_ascii=False))


def _job_done(job_obj: client.V1Job) -> bool:
    st = job_obj.status
    if not st:
        return False
    if (st.succeeded or 0) > 0 or (st.failed or 0) > 0:
        return True
    if st.conditions:
        for c in st.conditions:
            if c.type in ("Complete", "Failed") and c.status == "True":
                return True
    return False


def _list_pods_for_job(namespace: str, job_name: str) -> List[client.V1Pod]:
    return core.list_namespaced_pod(namespace=namespace, label_selector=f"job-name={job_name}").items


def _pick_pod(pods: List[client.V1Pod]) -> Optional[client.V1Pod]:
    if not pods:
        return None
    running = [p for p in pods if getattr(p.status, "phase", "") == "Running"]
    if running:
        return running[0]
    pods.sort(key=lambda p: getattr(p.metadata, "creation_timestamp", None) or 0, reverse=True)
    return pods[0]


@app.websocket("/ws/status")
async def ws_status(
    ws: WebSocket,
    namespace: str = Query(...),
    job: str = Query(...),
    follow_logs: int = Query(1),
    container: Optional[str] = Query(None),
):
    await ws.accept()
    last_log: Optional[str] = None

    try:
        while True:
            try:
                job_obj = batch.read_namespaced_job(name=job, namespace=namespace)
            except ApiException as e:
                await _send(ws, {"type": "error", "error": "job_not_found", "detail": str(e)})
                await asyncio.sleep(POLL_INTERVAL_SEC)
                continue

            pods = _list_pods_for_job(namespace, job)
            pod = _pick_pod(pods)

            pod_view = None
            if pod:
                st = pod.status
                pod_view = {
                    "name": pod.metadata.name,
                    "phase": getattr(st, "phase", None),
                    "start_time": getattr(st, "start_time", None).isoformat() if getattr(st, "start_time", None) else None,
                    "pod_ip": getattr(st, "pod_ip", None),
                    "host_ip": getattr(st, "host_ip", None),
                }
                if st.container_statuses:
                    pod_view["containers"] = []
                    for cs in st.container_statuses:
                        state = "unknown"
                        detail = {}
                        if cs.state:
                            if cs.state.running:
                                state = "running"
                                detail = {"started_at": cs.state.running.started_at.isoformat() if cs.state.running.started_at else None}
                            elif cs.state.waiting:
                                state = "waiting"
                                detail = {"reason": cs.state.waiting.reason, "message": cs.state.waiting.message}
                            elif cs.state.terminated:
                                state = "terminated"
                                detail = {
                                    "reason": cs.state.terminated.reason,
                                    "message": cs.state.terminated.message,
                                    "exit_code": cs.state.terminated.exit_code,
                                    "finished_at": cs.state.terminated.finished_at.isoformat() if cs.state.terminated.finished_at else None,
                                }
                        pod_view["containers"].append({
                            "name": cs.name,
                            "ready": cs.ready,
                            "restart_count": cs.restart_count,
                            "state": state,
                            **detail,
                        })

            logs = None
            if follow_logs and pod:
                try:
                    txt = core.read_namespaced_pod_log(
                        name=pod.metadata.name,
                        namespace=namespace,
                        container=container,
                        tail_lines=LOG_TAIL_LINES,
                        timestamps=True,
                    )
                    if txt != last_log:
                        logs = txt
                        last_log = txt
                except ApiException:
                    logs = None

            st = job_obj.status or client.V1JobStatus()
            payload = {
                "type": "status",
                "ts": time.time(),
                "job": {
                    "name": job_obj.metadata.name,
                    "namespace": namespace,
                    "active": int(getattr(st, "active", 0) or 0),
                    "succeeded": int(getattr(st, "succeeded", 0) or 0),
                    "failed": int(getattr(st, "failed", 0) or 0),
                    "start_time": getattr(st, "start_time", None).isoformat() if getattr(st, "start_time", None) else None,
                    "completion_time": getattr(st, "completion_time", None).isoformat() if getattr(st, "completion_time", None) else None,
                },
                "pod": pod_view,
                "logs": logs,
            }

            await _send(ws, payload)

            if _job_done(job_obj):
                await _send(ws, {"type": "done", "ts": time.time(), "job": payload["job"]})
                await ws.close()
                return

            await asyncio.sleep(POLL_INTERVAL_SEC)

    except WebSocketDisconnect:
        return
