#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./tools/clean_uninstall.sh --namespace <ns> --release <name> [options]

Required:
  --namespace <ns>            Kubernetes namespace of the release
  --release <name>            Helm release name (for example: glassbox-mol-audit)

Optional:
  --delete-pvc                Delete release PVC if still present after helm uninstall
  --delete-namespace          Delete namespace after release teardown
  --delete-reporting-secret   Delete Marketplace reporting secret (off by default)
  --reporting-secret <name>   Explicit reporting secret name to delete
  --timeout <seconds>         Wait timeout per phase (default: 180)
  --yes                       Non-interactive mode (skip confirmation)
  -h, --help                  Show this help

Notes:
  - Safe default keeps external reporting secret and namespace.
  - Helper pods created by runbook/e2e are cleaned:
      gbx-input-writer, gbx-output-reader
EOF
}

NAMESPACE=""
RELEASE=""
DELETE_PVC="0"
DELETE_NAMESPACE="0"
DELETE_REPORTING_SECRET="0"
REPORTING_SECRET_NAME=""
TIMEOUT_SECONDS="180"
AUTO_YES="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="${2:-}"
      shift 2
      ;;
    --release)
      RELEASE="${2:-}"
      shift 2
      ;;
    --delete-pvc)
      DELETE_PVC="1"
      shift
      ;;
    --delete-namespace)
      DELETE_NAMESPACE="1"
      shift
      ;;
    --delete-reporting-secret)
      DELETE_REPORTING_SECRET="1"
      shift
      ;;
    --reporting-secret)
      REPORTING_SECRET_NAME="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      shift 2
      ;;
    --yes)
      AUTO_YES="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${NAMESPACE}" || -z "${RELEASE}" ]]; then
  echo "[ERROR] --namespace and --release are required." >&2
  usage
  exit 2
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[ERROR] kubectl not found in PATH." >&2
  exit 2
fi
if ! command -v helm >/dev/null 2>&1; then
  echo "[ERROR] helm not found in PATH." >&2
  exit 2
fi

echo "[INFO] Context: $(kubectl config current-context 2>/dev/null || echo unknown)"
echo "[INFO] Namespace: ${NAMESPACE}"
echo "[INFO] Release: ${RELEASE}"
echo "[INFO] Options: delete_pvc=${DELETE_PVC} delete_namespace=${DELETE_NAMESPACE} delete_reporting_secret=${DELETE_REPORTING_SECRET}"

if [[ "${AUTO_YES}" != "1" ]]; then
  read -r -p "Proceed with uninstall? (yes/no): " ans
  if [[ "${ans}" != "yes" ]]; then
    echo "[INFO] Cancelled."
    exit 0
  fi
fi

RELEASE_PVC="${RELEASE}-data"
if [[ "${DELETE_REPORTING_SECRET}" == "1" ]]; then
  if [[ -z "${REPORTING_SECRET_NAME}" ]]; then
    # Try best-effort detection from live jobs first.
    REPORTING_SECRET_NAME="$(kubectl -n "${NAMESPACE}" get jobs -l "app.kubernetes.io/instance=${RELEASE}" -o jsonpath='{.items[0].spec.template.spec.volumes[?(@.name=="marketplace-reporting")].secret.secretName}' 2>/dev/null || true)"
  fi
fi

echo "[INFO] Removing helper pods (runbook/e2e leftovers)..."
kubectl -n "${NAMESPACE}" delete pod gbx-input-writer --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "${NAMESPACE}" delete pod gbx-output-reader --ignore-not-found >/dev/null 2>&1 || true

echo "[INFO] Removing release helper objects before helm uninstall..."
kubectl -n "${NAMESPACE}" delete pod "${RELEASE}-tester" --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "${NAMESPACE}" delete job "${RELEASE}" --ignore-not-found >/dev/null 2>&1 || true

if helm -n "${NAMESPACE}" status "${RELEASE}" >/dev/null 2>&1; then
  echo "[INFO] helm uninstall ${RELEASE}"
  helm -n "${NAMESPACE}" uninstall "${RELEASE}" --wait --timeout "${TIMEOUT_SECONDS}s"
else
  echo "[WARN] Helm release not found; skipping helm uninstall."
fi

echo "[INFO] Waiting for release-labeled resources to disappear..."
kubectl -n "${NAMESPACE}" wait --for=delete pod,job,configmap,service,serviceaccount,role,rolebinding -l "app.kubernetes.io/instance=${RELEASE}" --timeout "${TIMEOUT_SECONDS}s" >/dev/null 2>&1 || true

if [[ "${DELETE_PVC}" == "1" ]]; then
  echo "[INFO] Deleting PVC (data loss): ${RELEASE_PVC}"
  kubectl -n "${NAMESPACE}" delete pvc "${RELEASE_PVC}" --ignore-not-found >/dev/null 2>&1 || true
fi

if [[ "${DELETE_REPORTING_SECRET}" == "1" ]]; then
  if [[ -n "${REPORTING_SECRET_NAME}" ]]; then
    echo "[INFO] Deleting reporting secret: ${REPORTING_SECRET_NAME}"
    kubectl -n "${NAMESPACE}" delete secret "${REPORTING_SECRET_NAME}" --ignore-not-found >/dev/null 2>&1 || true
  else
    echo "[WARN] --delete-reporting-secret was set but reporting secret name could not be resolved."
  fi
fi

if [[ "${DELETE_NAMESPACE}" == "1" ]]; then
  echo "[INFO] Deleting namespace: ${NAMESPACE}"
  kubectl delete namespace "${NAMESPACE}" --wait=true --timeout="${TIMEOUT_SECONDS}s" >/dev/null 2>&1 || true
fi

echo "[INFO] Post-check:"
if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl -n "${NAMESPACE}" get all,cm,secret,sa,role,rolebinding,pvc 2>/dev/null | sed -n '1,120p' || true
else
  echo "  namespace/${NAMESPACE} not found"
fi

echo "[PASS] Uninstall workflow completed."
