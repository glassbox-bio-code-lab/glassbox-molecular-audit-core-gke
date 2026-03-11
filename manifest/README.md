# Marketplace Deployment Bundle

This folder contains the Kubernetes configuration used to deploy Glassbox Bio
Molecular Audit.

## Contents

- `chart/` - Helm chart used by Marketplace and CLI installs.
- `application.yaml` - Application custom resource template (envsubst).
- `manifests.yaml` - Placeholder for Click-to-Deploy structure parity.
- `../schema.yaml` - Marketplace schema consumed by the deployer image.

## Supported deployment profiles

We support two deployment profiles. Choose exactly one:

| Profile        | Expected runtime range | Rough cost range | Required cluster resources                      | When to use it                                                      |
| -------------- | ---------------------- | ---------------- | ----------------------------------------------- | ------------------------------------------------------------------- |
| Standard (CPU) | 2–6h (cap 6h)          | $$$              | 2–4 vCPU, 8–16Gi RAM, 50Gi PVC                  | Default choice for most audits; balanced speed vs cost              |
| Deep / GPU     | 4–8h (cap 8h)          | $$$$             | 4–8 vCPU, 32–64Gi RAM, 1x NVIDIA GPU, 200Gi PVC | Deep evidence expansion, docking-heavy or GPU-accelerated workflows |

Values files:

- `chart/values-standard.yaml`
- `chart/values-gpu.yaml`

## How Marketplace uses this bundle

Marketplace deploys the Helm chart using `schema.yaml` (repo root) to
collect user inputs and supply them as Helm values. The Application resource is
applied alongside the chart so that users can manage the app as a single unit.

Billing model for this bundle:

- One Marketplace plan: `gbx_target_diligence_core`
- Two usage metrics under that single plan: `standard_audit_run` and `deep_audit_run`
- The deployed run mode determines which metric is emitted for a completed run

## Deployer image

The Marketplace deployer bundle is defined by `github/deployer/Dockerfile`.
That image copies:

- `manifest/` -> `/data/manifest/`
- `schema.yaml` -> `/data/schema.yaml`

The deployer invokes Helm using `/data/schema.yaml` and
`/data/manifest/application.yaml`.

For internal build/publish steps, use `../../docs/RUNBOOK_PUBLISHER.md`.
For internal release validation evidence, use `../../docs/MARKETPLACE_REVIEW_CHECKLIST.md`.
