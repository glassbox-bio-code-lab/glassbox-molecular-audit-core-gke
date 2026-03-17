#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="glassbox-mol-audit"
APP_NAME="glassbox-mol-audit"
RUN_MODE="${RUN_MODE:-standard}"
STANDARD_IMAGE_REPO="${STANDARD_IMAGE_REPO:-}"
DEEP_IMAGE_REPO="${DEEP_IMAGE_REPO:-}"
IMAGE_REPO="${IMAGE_REPO:-}"
IMAGE_TAG="${IMAGE_TAG:-1.0.0}"
ARTIFACT_REGISTRY_HOST="${ARTIFACT_REGISTRY_HOST:-}"
STANDARD_IMAGE_PATH="${STANDARD_IMAGE_PATH:-glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit}"
DEEP_IMAGE_PATH="${DEEP_IMAGE_PATH:-glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deep-tools}"

if [[ -z "${STANDARD_IMAGE_REPO}" && -n "${ARTIFACT_REGISTRY_HOST}" ]]; then
  STANDARD_IMAGE_REPO="${ARTIFACT_REGISTRY_HOST}/${STANDARD_IMAGE_PATH}"
fi
if [[ -z "${DEEP_IMAGE_REPO}" && -n "${ARTIFACT_REGISTRY_HOST}" ]]; then
  DEEP_IMAGE_REPO="${ARTIFACT_REGISTRY_HOST}/${DEEP_IMAGE_PATH}"
fi

if [[ -z "${IMAGE_REPO}" ]]; then
  if [[ "${RUN_MODE}" == "deep" ]]; then
    IMAGE_REPO="${DEEP_IMAGE_REPO}"
  else
    IMAGE_REPO="${STANDARD_IMAGE_REPO}"
  fi
fi
if [[ -z "${IMAGE_REPO}" ]]; then
  echo "ERROR: IMAGE_REPO is required. Set IMAGE_REPO directly or provide ARTIFACT_REGISTRY_HOST." >&2
  exit 1
fi

helm upgrade --install "${APP_NAME}" ./manifest/chart \
  --namespace "${NAMESPACE}" --create-namespace \
  -f ./manifest/chart/values-standard.yaml \
  $([[ "${RUN_MODE}" == "deep" ]] && echo "-f ./manifest/chart/values-gpu.yaml") \
  --set image.repository="${IMAGE_REPO}" \
  --set image.tag="${IMAGE_TAG}" \
  --set config.projectId="mol_audit_demo" \
  --set config.runMode="${RUN_MODE}"
