# Support Matrix

## Supported runtimes

| Profile  | Run mode   | Runtime image repository                                                                           | Expected runtime | Resource baseline                       |
| -------- | ---------- | -------------------------------------------------------------------------------------------------- | ---------------- | --------------------------------------- |
| Standard | `standard` | `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit`            | 2-6h             | 2-4 vCPU, 8-16Gi RAM, 50Gi PVC          |
| Deep     | `deep`     | `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deep-tools` | 4-8h             | 4-8 vCPU, 32-64Gi RAM, 1 GPU, 200Gi PVC |

## Storage backends

| Backend | Status | Notes |
| --- | --- | --- |
| PVC | Supported | Default in the chart and customer workflow |
| GCS Fuse (GKE CSI) | Supported | Requires bucket, Workload Identity, and cluster GCS Fuse support |

## Entitlement/auth model

| Mode                                    | Status                        | Notes                                 |
| --------------------------------------- | ----------------------------- | ------------------------------------- |
| Workload Identity + OIDC principal auth | Required for customer runtime | Identity-only entitlement enforcement |
| Static entitlement token                | Not required                  | Do not configure in customer runtime  |

## Kubernetes objects created

- `Job` (runtime execution)
- `PersistentVolumeClaim` (PVC mode)
- `ConfigMap`
- `ServiceAccount`
- No console/UI resources in the current chart
- Required `ubbagent` sidecar for Marketplace-metered deployments

## Out-of-scope/non-supported

- Synthetic/mock scientific input substitution
- Non-GKE clusters for GCS Fuse mode without compatible CSI driver
