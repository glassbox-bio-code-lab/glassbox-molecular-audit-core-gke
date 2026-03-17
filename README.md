<p align="center">
  <img
    src="https://res.cloudinary.com/dpaosk5m5/image/upload/v1770865259/gbx_bio_logo_vpnsjd.png"
    alt="Glassbox Bio"
    width="520"
  />
</p>

<br/>

# Glassbox Bio Target Diligence Core

Google Cloud Marketplace Deployment Bundle (Helm chart + schema + examples)

![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![Marketplace](https://img.shields.io/badge/Google%20Cloud-Marketplace-4285F4)
![Helm](https://img.shields.io/badge/Helm-supported-0F1689)

<br/>
<br/>

## Scope of this Repository

This repository contains the public configuration, documentation, and examples
required to distribute the Glassbox Bio Target Diligence Core Kubernetes app on
Google Cloud Marketplace.

It does **not** contain:

- Proprietary audit logic or scoring models
- Computational analysis modules
- Internal datasets or knowledge graphs
- Customer-specific configuration

<br/>
<br/>

This directory is the public, customer-facing repository root for Google Cloud Marketplace submission. It contains deployable manifests, chart configuration, examples, and customer/operator documentation.

Customer runtime uses identity-only entitlement checks. The Kubernetes Job authenticates to the hosted entitlement service with Workload Identity, and entitlement is resolved from the customer GSA principal. Customer deployments do not require a customer-managed entitlement token or any provisioning credential.

Run all public bundle commands from this repository root.

## Scope

- `manifest/` Helm chart, Application CR, and Marketplace deploy bundle
- `schema.yaml` Marketplace UI schema and parameter wiring
- `examples/` install values and end-to-end install script
- `docs/` runbook, input contract, and support matrix

## Customer Quickstart

Validate the bundle first:

```bash
make bundle-preflight
```

Published runtime repositories:

- Standard: `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit`
- Deep: `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deep-tools`

Primary customer docs:

- [Customer runbook](./docs/RUNBOOK_CUSTOMER.md)
- [Support matrix](./docs/SUPPORT_MATRIX.md)
- [Input expectations](./docs/INPUT_EXPECTATIONS.md)

Consumption tracking:

- The Marketplace runtime pod templates include the required partner label:
  - `goog-partner-solution=isol_plb32_001kf00001e8runiab_pwayyor5jqd3hikviwgqy5hwrx2hnpn5`
- The standard/deep audit Job pods also declare explicit resource requests and limits.
- The verification tester pod also carries the same pod-level consumption label and explicit resources.

## Runtime Image Builds

The published runtime images already include the required `models/` and `data/`
artifacts. Rebuilding runtime images from the public repository is not part of
the supported customer workflow because the asset bundles are not distributed in
this repo.

## Quick start

### Marketplace (one-click)

Deploy directly from Google Cloud Marketplace:

https://console.cloud.google.com/marketplace/product/glassbox-bio/molecular-audit-core
The Marketplace UI handles image wiring and configuration values.

<br/>
<br/>

### CLI (helm)

We officially support two opinionated deployment profiles. Choose one:
<br/>
<br/>

| Profile               | Expected runtime range | Rough cost range | Required cluster resources                      | When to use it                                                      |
| --------------------- | ---------------------- | ---------------- | ----------------------------------------------- | ------------------------------------------------------------------- |
| Standard (CPU)        | 2-6h                   | $$               | 2–4 vCPU, 8–16Gi RAM, 50Gi PVC                  | Default choice for most audits; balanced speed vs cost              |
| Deep / GPU (optional) | 4-8h                   | $$$              | 4–8 vCPU, 32–64Gi RAM, 1x NVIDIA GPU, 200Gi PVC | Deep evidence expansion, docking-heavy or GPU-accelerated workflows |

<br/>
<br/>

## Standard

```bash
export WORKLOAD_IDENTITY_GSA="your-sa@project.iam.gserviceaccount.com"
export GSA_PROJECT_ID="your-gsa-project-id"
export CLUSTER_PROJECT_ID="your-gke-project-id"
export PROJECT_ID="test"
export CATEGORY_ID="SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ"
export MARKETPLACE_REPORTING_SECRET="marketplace-reporting-secret"
export UBBAGENT_IMAGE_REPO="REGION-docker.pkg.dev/PROJECT/REPO/ubbagent"
export UBBAGENT_IMAGE_TAG="1.0.0"

# Bare digest only. The standard target selects the standard public repository automatically.
export STANDARD_IMAGE_DIGEST="sha256:c48760f3e5f089fe0c35f2f11c6d6c876b8cc210632913bef82b98537faae065"

# Required once per KSA/GSA pair so the in-cluster KSA can mint the OIDC bearer token
# used by the entitlement service.
gcloud iam service-accounts add-iam-policy-binding "${WORKLOAD_IDENTITY_GSA}" \
  --project="${GSA_PROJECT_ID}" \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:${CLUSTER_PROJECT_ID}.svc.id.goog[glassbox-mol-audit/glassbox-mol-audit-sa]"

make customer-run-standard PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" STANDARD_IMAGE_DIGEST="${STANDARD_IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"

# Equivalent step-by-step flow:
make deploy-manifest-infra-standard STANDARD_IMAGE_DIGEST="${STANDARD_IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}"
make stage-manifest-input-standard PROJECT_ID="${PROJECT_ID}"
make deploy-manifest-job-standard PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"
make fetch-manifest-output-standard RUN_ID="${RUN_ID}"
```

If the runner fails with `Missing Authorization bearer token` or `iam.serviceAccounts.getOpenIdToken denied`, the GSA is missing the `roles/iam.workloadIdentityUser` binding for Kubernetes service account `glassbox-mol-audit/glassbox-mol-audit-sa`.

Artifact retrieval note:

- Runtime outputs are written in-cluster first under `/data/output/<run_id>/`.
- `make customer-run-standard` includes the fetch step automatically.
- If you run the step-by-step flow instead, artifacts are not copied to your workstation until `make fetch-manifest-output-standard` completes.
- Local download path: `./e2e/downloads/<run_id>/`
- To confirm the latest run id locally: `cat .last_manifest_run_id.standard`

Bundle validation:

```bash
make bundle-preflight
```

## Deep

```bash

export WORKLOAD_IDENTITY_GSA="your-sa@project.iam.gserviceaccount.com"
export MARKETPLACE_REPORTING_SECRET="marketplace-reporting-secret"
export UBBAGENT_IMAGE_REPO="REGION-docker.pkg.dev/PROJECT/REPO/ubbagent"
export UBBAGENT_IMAGE_TAG="1.0.0"

export PROJECT_ID="test"
export CATEGORY_ID="SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ"

# Bare digest only. The deep target selects the deep public repository automatically.
export DEEP_IMAGE_DIGEST="sha256:7754aa922cffe73963027d20d9b71aa0edcc015f1ae8445ec021b6032b84db28"

make customer-run-deep PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" DEEP_IMAGE_DIGEST="${DEEP_IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"

# Equivalent step-by-step flow:
make deploy-manifest-infra-deep DEEP_IMAGE_DIGEST="${DEEP_IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}"
make stage-manifest-input-deep PROJECT_ID="${PROJECT_ID}"
make deploy-manifest-job-deep PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}" MARKETPLACE_REPORTING_SECRET="${MARKETPLACE_REPORTING_SECRET}" UBBAGENT_IMAGE_REPO="${UBBAGENT_IMAGE_REPO}" UBBAGENT_IMAGE_TAG="${UBBAGENT_IMAGE_TAG}"
make fetch-manifest-output-deep  RUN_ID="${RUN_ID}"

```

Operator note:

- Deep mode requires the deep runtime image and GPU-capable scheduling for the actual audit job.
- Deep mode requires a compatible GPU node pool with available capacity in the target zone. If no matching GPU node can be scheduled or autoscaled, the deep job will remain pending until capacity is available.
- The PVC staging/fetch helper intentionally uses a lightweight utility image and does not use the deep runtime image.
- Do not repoint the PVC helper at the deep-tools image; that helper only copies data into and out of `/data`.

Customer runtime note:

- Use Workload Identity plus `config.entitlementAuthMode=google`.
- The entitlement service authorizes the run from the caller principal.
- Do not set any customer entitlement token or any provisioning credential in customer runtime configuration.

## Runtime Profiles

- Standard runtime image:
  - `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit`
- Deep runtime image:
  - `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deep-tools`
- Entitlement plan:
  - `gbx_target_diligence_core`
- Usage metrics:
  - `standard_audit_run`
  - `deep_audit_run`

The standard wrapper targets always use `STANDARD_IMAGE_*`. The deep wrapper targets always use `DEEP_IMAGE_*`. Digests must be bare `sha256:...` values, not full image references. The supported Marketplace path also requires `MARKETPLACE_REPORTING_SECRET` plus the `UBBAGENT_IMAGE_*` values so metering is configured at deploy time.

Sample customer input for the public command path is staged from:

- `e2e/sample_input/<project_id>/01_sources/`

Variable meaning:

- `INPUT_ROOT` = parent folder that holds projects
- `PROJECT_ID` = name of the project folder that holds the individual experiment data

For example, if your inputs are stored at `e2e/sample_input/my_project/01_sources/...`, set:

```bash
export PROJECT_ID="my_project"
```

To stage a different parent directory, override `INPUT_ROOT` when invoking the
customer target. Example:

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

That command expects inputs at:

- `/absolute/path/to/input_root/my_project/01_sources/`

## Uninstall

Finally, to uninstall all artifacts and teardown, run from the root directory:

```bash

 ./tools/clean_uninstall.sh --namespace glassbox-mol-audit --release glassbox-mol-audit --yes

# If you want the data PVC removed too
./tools/clean_uninstall.sh --namespace glassbox-mol-audit --release glassbox-mol-audit --delete-pvc --yes
```

- use it for the uninstall verification step
- do not use it for normal runs
- the safe first test is the first command without deleting the namespace
