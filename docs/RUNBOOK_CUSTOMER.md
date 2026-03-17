# Customer Runbook (Marketplace Helm Deployment)

This runbook describes the customer-facing operator flow for deploying and
running Glassbox Bio Molecular Audit from the repository root.

## Prerequisites

- GKE cluster access with the correct `kubectl` context
- Helm v3
- A Workload Identity GSA with permission to call the entitlement service
- Published runtime image digests for the standard and deep images

## Required environment variables

Set these before running any of the `make` targets:

```bash
export WORKLOAD_IDENTITY_GSA="your-sa@project.iam.gserviceaccount.com"
export PROJECT_ID="test"
export CATEGORY_ID="SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ"
export STANDARD_IMAGE_DIGEST="sha256:REPLACE_WITH_PUBLISHED_STANDARD_DIGEST"
export DEEP_IMAGE_DIGEST="sha256:REPLACE_WITH_PUBLISHED_DEEP_DIGEST"
export MARKETPLACE_REPORTING_SECRET="marketplace-reporting-secret"
export UBBAGENT_IMAGE_REPO="REGION-docker.pkg.dev/PROJECT/REPO/ubbagent"
export UBBAGENT_IMAGE_TAG="1.0.0"
```

## Preflight validation

Validate the bundle before deploying:

```bash
make bundle-preflight
```

## Standard run

### One-command flow

```bash
make customer-run-standard PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" STANDARD_IMAGE_DIGEST="${STANDARD_IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"
```

### Step-by-step flow

```bash
make deploy-manifest-infra-standard STANDARD_IMAGE_DIGEST="${STANDARD_IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}"
make stage-manifest-input-standard PROJECT_ID="${PROJECT_ID}"
make deploy-manifest-job-standard PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"
make fetch-manifest-output-standard
```

## Deep run

### Requirements

- Deep mode uses the deep-tools runtime image.
- The target cluster must have a compatible GPU node pool.
- The target zone must have GPU capacity available, or the job can remain pending.

### One-command flow

```bash
make customer-run-deep PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" DEEP_IMAGE_DIGEST="${DEEP_IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"
```

### Step-by-step flow

```bash
make deploy-manifest-infra-deep DEEP_IMAGE_DIGEST="${DEEP_IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}"
make stage-manifest-input-deep PROJECT_ID="${PROJECT_ID}"
make deploy-manifest-job-deep PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"
make fetch-manifest-output-deep
```

## Output retrieval behavior

- The runtime writes artifacts to the mounted volume first under `/data/output/<run_id>/`.
- `make customer-run-standard` and `make customer-run-deep` include the fetch step automatically.
- In the step-by-step flow, the local customer copy is created only when `make fetch-manifest-output-standard` or `make fetch-manifest-output-deep` completes.
- The PVC staging/fetch helper is intentionally separate from the runtime image. Deep jobs use the deep-tools runtime image, but the helper pod stays lightweight and should not be changed to the deep runtime image.
- Default local download path: `./e2e/downloads/<run_id>/`
- To see the most recent standard run id: `cat .last_manifest_run_id.standard`
- To see the most recent deep run id: `cat .last_manifest_run_id.deep`

## Input contract

Expected source layout:

```text
e2e/sample_input/<project_id>/01_sources/
```

Required files:

- `sources.json`
- `portfolio_selected.csv`

Additional details:

- `docs/INPUT_EXPECTATIONS.md`

Variable meanings:

- `INPUT_ROOT`: parent directory that contains project folders
- `PROJECT_ID`: project folder name inside `INPUT_ROOT`

Examples:

- `PROJECT_ID="test"` stages `e2e/sample_input/test/`
- `PROJECT_ID="my_project"` stages `e2e/sample_input/my_project/`

To use a different input root:

```bash
make customer-run-standard \
  INPUT_ROOT="/absolute/path/to/input_root" \
  PROJECT_ID="my_project" \
  CATEGORY_ID="${CATEGORY_ID}" \
  WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" \
  MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" \
  UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" \
  UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"
```

Expected layout in that case:

```text
/absolute/path/to/input_root/my_project/01_sources/
```

## Common failure cases

- Missing category: set a non-empty `CATEGORY_ID`
- Entitlement auth failures (`401/403`): verify Workload Identity mapping and Cloud Run caller authorization
- Staging path failure: verify the local path `e2e/sample_input/<project_id>/`

## Cleanup

```bash
./tools/clean_uninstall.sh --namespace glassbox-mol-audit --release glassbox-mol-audit --yes
```
