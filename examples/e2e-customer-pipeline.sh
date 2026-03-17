#!/usr/bin/env bash
set -euo pipefail

# End-to-end "customer" pipeline for the Marketplace bundle.
# Requires: kubectl auth to a cluster, helm v3.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CHART_DIR="${GITHUB_ROOT}/manifest/chart"

APP_NAME="${APP_NAME:-glassbox-mol-audit}"
NAMESPACE="${NAMESPACE:-glassbox-mol-audit}"
PROFILE_VALUES="${PROFILE_VALUES:-${CHART_DIR}/values-standard.yaml}" # add values-gpu.yaml for deep runs
RUN_MODE="${RUN_MODE:-standard}" # "standard" or "deep"

STANDARD_IMAGE_REPO="${STANDARD_IMAGE_REPO:-}"
DEEP_IMAGE_REPO="${DEEP_IMAGE_REPO:-}"
IMAGE_REPO="${IMAGE_REPO:-}"
IMAGE_TAG="${IMAGE_TAG:-1.0.0}"
PROJECT_ID="${PROJECT_ID:-test}"
CATEGORY_ID="${CATEGORY_ID:-SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ}"
ENTITLEMENT_URL="${ENTITLEMENT_URL:-}"
GCP_REGION="${GCP_REGION:-}"
GCP_LOCATION="${GCP_LOCATION:-${GCP_REGION}}"
MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET:-}"
UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO:-}"
UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG:-1.0.0}"
UBBAGENT_IMAGE_DIGEST="${UBBAGENT_IMAGE_DIGEST:-}"
DATA_RESIDENCY="${DATA_RESIDENCY:-strict}"
EGRESS_MODE="${EGRESS_MODE:-STRICT_LOCAL}"
OPTIONAL_ANALYTICS="${OPTIONAL_ANALYTICS:-0}"
ALLOWED_EGRESS_DOMAINS="${ALLOWED_EGRESS_DOMAINS:-}"
ARTIFACT_REGISTRY_HOST="${ARTIFACT_REGISTRY_HOST:-}"
STANDARD_IMAGE_PATH="${STANDARD_IMAGE_PATH:-glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit}"
DEEP_IMAGE_PATH="${DEEP_IMAGE_PATH:-glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deep-tools}"

if [[ -z "${STANDARD_IMAGE_REPO}" && -n "${ARTIFACT_REGISTRY_HOST}" ]]; then
  STANDARD_IMAGE_REPO="${ARTIFACT_REGISTRY_HOST}/${STANDARD_IMAGE_PATH}"
fi
if [[ -z "${DEEP_IMAGE_REPO}" && -n "${ARTIFACT_REGISTRY_HOST}" ]]; then
  DEEP_IMAGE_REPO="${ARTIFACT_REGISTRY_HOST}/${DEEP_IMAGE_PATH}"
fi

# Optional: deterministic run_id (also controls output subdir name).
RUN_ID="${RUN_ID:-}"

# Identity-only entitlement auth (Workload Identity identity token).
ENTITLEMENT_AUTH_MODE="${ENTITLEMENT_AUTH_MODE:-google}"
ENTITLEMENT_AUDIENCE="${ENTITLEMENT_AUDIENCE:-${ENTITLEMENT_URL}}"
WORKLOAD_IDENTITY_ENABLED="${WORKLOAD_IDENTITY_ENABLED:-1}"
WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA:-}"   # your-sa@project.iam.gserviceaccount.com

# Use the on-disk sample input bundle by default.
SAMPLE_INPUT_DIR="${SAMPLE_INPUT_DIR:-${GITHUB_ROOT}/e2e/sample_input/test}"
PVC_NAME="${PVC_NAME:-${APP_NAME}-data}"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BLUE=$'\033[1;34m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
  C_CYAN=$'\033[1;36m'
else
  C_RESET=""
  C_BLUE=""
  C_GREEN=""
  C_YELLOW=""
  C_CYAN=""
fi

e2e() { echo "${C_BLUE}[e2e]${C_RESET} $*"; }
ok() { echo "${C_GREEN}[e2e]${C_RESET} $*"; }
warn() { echo "${C_YELLOW}[e2e]${C_RESET} $*"; }
accent() { echo "${C_CYAN}$*${C_RESET}"; }
link() {
  local label="$1"
  local target="$2"
  # OSC-8 hyperlink: supported by most modern terminals.
  printf '\033]8;;%s\033\\%s\033]8;;\033\\\n' "${target}" "${label}"
}

if [[ -z "${IMAGE_REPO}" ]]; then
  if [[ "${RUN_MODE}" == "deep" ]]; then
    IMAGE_REPO="${DEEP_IMAGE_REPO}"
  else
    IMAGE_REPO="${STANDARD_IMAGE_REPO}"
  fi
fi

if [[ -z "${CATEGORY_ID}" ]]; then
  echo "[e2e] ERROR: CATEGORY_ID is required (job.enabled=true requires config.categoryId)"
  exit 1
fi
if [[ -z "${GCP_REGION}" ]]; then
  echo "[e2e] ERROR: GCP_REGION is required"
  exit 1
fi
if [[ -z "${IMAGE_REPO}" ]]; then
  echo "[e2e] ERROR: IMAGE_REPO is required. Set IMAGE_REPO directly or provide ARTIFACT_REGISTRY_HOST."
  exit 1
fi
if [[ -z "${ENTITLEMENT_URL}" ]]; then
  echo "[e2e] ERROR: ENTITLEMENT_URL is required"
  exit 1
fi
if [[ -z "${MARKETPLACE_REPORTING_SECRET}" ]]; then
  echo "[e2e] ERROR: MARKETPLACE_REPORTING_SECRET is required for Marketplace-metered deployments"
  exit 1
fi
if [[ -z "${UBBAGENT_IMAGE_REPO}" ]]; then
  echo "[e2e] ERROR: UBBAGENT_IMAGE_REPO is required for Marketplace-metered deployments"
  exit 1
fi

if [[ "${WORKLOAD_IDENTITY_ENABLED}" == "1" && -z "${WORKLOAD_IDENTITY_GSA}" ]]; then
  echo "[e2e] ERROR: WORKLOAD_IDENTITY_GSA is required when WORKLOAD_IDENTITY_ENABLED=1"
  exit 1
fi

e2e "namespace=${NAMESPACE} app=${APP_NAME} image=${IMAGE_REPO}:${IMAGE_TAG}"
e2e "NOTE: identity-only entitlements: the runner authenticates with Workload Identity (Authorization bearer token)."

HELM_AUTH_ARGS=()
HELM_VALUES_ARGS=()
for vf in ${PROFILE_VALUES}; do
  HELM_VALUES_ARGS+=(-f "${vf}")
done
if [[ -n "${RUN_ID}" ]]; then
  HELM_AUTH_ARGS+=(--set "config.runId=${RUN_ID}")
fi
if [[ -n "${RUN_MODE}" ]]; then
  HELM_AUTH_ARGS+=(--set "config.runMode=${RUN_MODE}")
fi
if [[ -n "${ENTITLEMENT_AUTH_MODE}" ]]; then
  HELM_AUTH_ARGS+=(--set "config.entitlementAuthMode=${ENTITLEMENT_AUTH_MODE}")
fi
if [[ -n "${ENTITLEMENT_AUDIENCE}" ]]; then
  HELM_AUTH_ARGS+=(--set "config.entitlementAudience=${ENTITLEMENT_AUDIENCE}")
fi
if [[ "${WORKLOAD_IDENTITY_ENABLED}" == "1" ]]; then
  HELM_AUTH_ARGS+=(--set "workloadIdentity.enabled=true")
  if [[ -n "${WORKLOAD_IDENTITY_GSA}" ]]; then
    HELM_AUTH_ARGS+=(--set "workloadIdentity.gcpServiceAccount=${WORKLOAD_IDENTITY_GSA}")
  fi
fi
UBB_HELM_ARGS=(
  --set "ubbagent.enabled=true"
  --set-string "marketplace.reportingSecret=${MARKETPLACE_REPORTING_SECRET}"
  --set-string "ubbagent.image.repository=${UBBAGENT_IMAGE_REPO}"
)
if [[ -n "${UBBAGENT_IMAGE_DIGEST}" ]]; then
  UBB_HELM_ARGS+=(--set-string "ubbagent.image.digest=${UBBAGENT_IMAGE_DIGEST}")
else
  UBB_HELM_ARGS+=(--set-string "ubbagent.image.tag=${UBBAGENT_IMAGE_TAG}")
fi

echo "[e2e] installing chart (phase 1: create infra, job disabled)"
helm upgrade --install "${APP_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  "${HELM_VALUES_ARGS[@]}" \
  --set job.enabled=false \
  --set image.repository="${IMAGE_REPO}" \
  --set image.tag="${IMAGE_TAG}" \
  --set config.projectId="${PROJECT_ID}" \
  --set config.gcpRegion="${GCP_REGION}" \
  --set config.gcpLocation="${GCP_LOCATION}" \
  --set config.dataResidency="${DATA_RESIDENCY}" \
  --set config.egressMode="${EGRESS_MODE}" \
  --set config.optionalAnalytics="${OPTIONAL_ANALYTICS}" \
  --set config.allowedEgressDomains="${ALLOWED_EGRESS_DOMAINS}" \
  --set config.categoryId="${CATEGORY_ID}" \
  --set config.entitlementUrl="${ENTITLEMENT_URL}" \
  "${UBB_HELM_ARGS[@]}" \
  "${HELM_AUTH_ARGS[@]}"

echo "[e2e] checking pvc ${PVC_NAME} (if using pvc storage)"
kubectl -n "${NAMESPACE}" get pvc "${PVC_NAME}" >/dev/null 2>&1 || true

# Prevent RWO PVC multi-attach if a previous run left the output reader pod around.
kubectl -n "${NAMESPACE}" delete pod gbx-output-reader --ignore-not-found >/dev/null 2>&1 || true

echo "[e2e] staging sample inputs into ${PVC_NAME} (PVC mode only)"
if kubectl -n "${NAMESPACE}" get pvc "${PVC_NAME}" >/dev/null 2>&1; then
  echo "[e2e] note: do not wait for PVC Bound here; WaitForFirstConsumer storage classes bind only after the helper pod mounts the claim"
  kubectl -n "${NAMESPACE}" delete pod gbx-input-writer --ignore-not-found
  kubectl -n "${NAMESPACE}" apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: gbx-input-writer
spec:
  restartPolicy: Never
  containers:
    - name: writer
      # Avoid external images (docker.io) in Marketplace environments. Reuse the runner image.
      image: "${IMAGE_REPO}:${IMAGE_TAG}"
      imagePullPolicy: IfNotPresent
      securityContext:
        runAsUser: 0
      command: ["bash","-lc"]
      args:
        - |
          set -euo pipefail
          mkdir -p "/data/input/${PROJECT_ID}"
          echo "[e2e] writer pod ready for kubectl cp into /data/input/${PROJECT_ID}"
          sleep 3600
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: "${PVC_NAME}"
YAML
  kubectl -n "${NAMESPACE}" wait --for=condition=Ready pod/gbx-input-writer --timeout=5m

  if [[ ! -d "${SAMPLE_INPUT_DIR}/01_sources" ]]; then
    echo "[e2e] ERROR: sample input dir not found: ${SAMPLE_INPUT_DIR}/01_sources"
    exit 1
  fi

  echo "[e2e] copying ${SAMPLE_INPUT_DIR}/01_sources -> pvc:/data/input/${PROJECT_ID}/"
  kubectl -n "${NAMESPACE}" cp "${SAMPLE_INPUT_DIR}/01_sources" "gbx-input-writer:/data/input/${PROJECT_ID}"
  # The job container runs as a non-root user; ensure the project dir is writable for staging artifacts.
  kubectl -n "${NAMESPACE}" exec gbx-input-writer -- sh -c "chmod -R a+rwX /data/input/${PROJECT_ID} || true"
  echo "[e2e] verifying inputs exist in pvc"
  kubectl -n "${NAMESPACE}" exec gbx-input-writer -- sh -c "ls -la /data/input/${PROJECT_ID}/01_sources && test -f /data/input/${PROJECT_ID}/01_sources/sources.json"

  kubectl -n "${NAMESPACE}" delete pod gbx-input-writer --ignore-not-found
fi

echo "[e2e] installing chart (phase 2: enable job)"
# Prevent RWO PVC multi-attach before starting the job pod.
kubectl -n "${NAMESPACE}" delete pod gbx-output-reader --ignore-not-found >/dev/null 2>&1 || true
helm upgrade --install "${APP_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  "${HELM_VALUES_ARGS[@]}" \
  --set job.enabled=true \
  --set image.repository="${IMAGE_REPO}" \
  --set image.tag="${IMAGE_TAG}" \
  --set config.projectId="${PROJECT_ID}" \
  --set config.gcpRegion="${GCP_REGION}" \
  --set config.gcpLocation="${GCP_LOCATION}" \
  --set config.dataResidency="${DATA_RESIDENCY}" \
  --set config.egressMode="${EGRESS_MODE}" \
  --set config.optionalAnalytics="${OPTIONAL_ANALYTICS}" \
  --set config.allowedEgressDomains="${ALLOWED_EGRESS_DOMAINS}" \
  --set config.categoryId="${CATEGORY_ID}" \
  --set config.entitlementUrl="${ENTITLEMENT_URL}" \
  "${UBB_HELM_ARGS[@]}" \
  "${HELM_AUTH_ARGS[@]}"

echo "[e2e] job status"
kubectl -n "${NAMESPACE}" get job "${APP_NAME}" -o wide || true
kubectl -n "${NAMESPACE}" describe job "${APP_NAME}" | sed -n '1,120p' || true

echo "[e2e] streaming job logs (best-effort)"
kubectl -n "${NAMESPACE}" logs "job/${APP_NAME}" --all-containers --timestamps --tail=200 || true

echo "[e2e] waiting for job completion "
deadline=$(( $(date +%s) + 8*60*60 ))
while true; do
  if kubectl -n "${NAMESPACE}" get job "${APP_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null | grep -q True; then
    break
  fi
  if kubectl -n "${NAMESPACE}" get job "${APP_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null | grep -q True; then
    echo "[e2e] job failed"
    kubectl -n "${NAMESPACE}" logs "job/${APP_NAME}" --all-containers --timestamps --tail=500 || true
    exit 1
  fi
  if [[ "$(date +%s)" -ge "${deadline}" ]]; then
    echo "[e2e] timeout waiting for job"
    kubectl -n "${NAMESPACE}" get job "${APP_NAME}" -o wide || true
    exit 1
  fi
  sleep 10
done

e2e "final job logs"
kubectl -n "${NAMESPACE}" logs "job/${APP_NAME}" --all-containers --timestamps --tail=500

e2e "resolving output artifact location"
if kubectl -n "${NAMESPACE}" get pvc "${PVC_NAME}" >/dev/null 2>&1; then
  kubectl -n "${NAMESPACE}" delete pod gbx-output-reader --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n "${NAMESPACE}" apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: gbx-output-reader
spec:
  restartPolicy: Never
  containers:
    - name: reader
      image: "${IMAGE_REPO}:${IMAGE_TAG}"
      imagePullPolicy: IfNotPresent
      command: ["sh","-c"]
      args: ["sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: "${PVC_NAME}"
YAML
  kubectl -n "${NAMESPACE}" wait --for=condition=Ready pod/gbx-output-reader --timeout=5m >/dev/null

  RUN_OUTPUT_DIR=""
  if [[ -n "${RUN_ID}" ]]; then
    if kubectl -n "${NAMESPACE}" exec gbx-output-reader -- sh -c "test -d /data/output/${RUN_ID}"; then
      RUN_OUTPUT_DIR="/data/output/${RUN_ID}"
    fi
  fi
  if [[ -z "${RUN_OUTPUT_DIR}" ]]; then
    RUN_OUTPUT_DIR="$(kubectl -n "${NAMESPACE}" exec gbx-output-reader -- sh -c 'ls -1dt /data/output/* 2>/dev/null | head -n1' || true)"
  fi

  if [[ -n "${RUN_OUTPUT_DIR}" ]]; then
    ok "output directory (PVC): ${RUN_OUTPUT_DIR}"
    e2e "key artifacts:"
    kubectl -n "${NAMESPACE}" exec gbx-output-reader -- sh -c \
      "find '${RUN_OUTPUT_DIR}' -maxdepth 3 -type f \\( -name summary.json -o -name run_manifest.json -o -name preseal.json -o -name seal.json -o -name seal.sig -o -name seal.svg -o -name VERIFY.png -o -name phase_5_computational_safety.html -o -name phase_5_fastfail_summary.html -o -name phase_5_fastfail_summary.json -o -name phase_5_pipeline_analytics_snapshot.html -o -name phase_5_pipeline_analytics_snapshot.json \\) | sort" \
      | sed "s|^|${C_CYAN}[e2e]   ${C_RESET}|"

    COPY_CMD="kubectl -n \"${NAMESPACE}\" cp gbx-output-reader:${RUN_OUTPUT_DIR} ./e2e/downloads/$(basename "${RUN_OUTPUT_DIR}")"
    LOCAL_HINT="${GITHUB_ROOT}/e2e/downloads/$(basename "${RUN_OUTPUT_DIR}")"
    FILE_URL="file://${LOCAL_HINT}"
    e2e "copy command:"
    accent "[e2e]   ${COPY_CMD}"
    e2e "clickable local path:"
    link "${LOCAL_HINT}" "${FILE_URL}"
    e2e "file URL (fallback):"
    accent "[e2e]   ${FILE_URL}"
    if command -v wslpath >/dev/null 2>&1; then
      WIN_PATH="$(wslpath -w "${LOCAL_HINT}" 2>/dev/null || true)"
      if [[ -n "${WIN_PATH}" ]]; then
        e2e "open in Explorer (fallback):"
        accent "[e2e]   explorer.exe \"${WIN_PATH}\""
      fi
    fi

    # Always download outputs locally for the supported customer workflow.
    # Note: kubectl cp requires the pod to be Running (not Succeeded), hence the long sleep above.
    LOCAL_OUTPUT_DIR="${LOCAL_OUTPUT_DIR:-${LOCAL_HINT}}"
    mkdir -p "$(dirname "${LOCAL_OUTPUT_DIR}")"
    if kubectl -n "${NAMESPACE}" cp "gbx-output-reader:${RUN_OUTPUT_DIR}" "${LOCAL_OUTPUT_DIR}"; then
      ok "downloaded outputs to: ${LOCAL_OUTPUT_DIR}"
    else
      warn "download failed (kubectl cp). Re-run:"
      accent "[e2e]   ${COPY_CMD}"
    fi

    LOCAL_FILE_URL="file://${LOCAL_OUTPUT_DIR}"
    e2e "open locally:"
    accent "[e2e]   ${LOCAL_OUTPUT_DIR}"
    e2e "file URL (fallback):"
    accent "[e2e]   ${LOCAL_FILE_URL}"
    if command -v wslpath >/dev/null 2>&1; then
      WIN_PATH="$(wslpath -w "${LOCAL_OUTPUT_DIR}" 2>/dev/null || true)"
      if [[ -n "${WIN_PATH}" ]]; then
        e2e "Windows path:"
        accent "[e2e]   ${WIN_PATH}"
        e2e "open in Explorer:"
        accent "[e2e]   explorer.exe \"${WIN_PATH}\""
      fi
    fi
  else
    warn "WARNING: could not resolve run output directory under /data/output"
  fi
fi

ok "done"
