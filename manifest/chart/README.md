# Glassbox Bio Molecular Audit Helm Chart

This directory contains the Helm chart for the Glassbox Bio Molecular Audit runtime.

Customer installation instructions live at the repository root:

- [Root README](../../README.md)
- [Customer runbook](../../docs/RUNBOOK_CUSTOMER.md)

## Profiles

- `values-standard.yaml`: standard CPU profile
- `values-gpu.yaml`: deep/GPU overlay, used with `config.runMode=deep`

## Example

```bash
helm upgrade --install glassbox-mol-audit ./manifest/chart \
  --namespace glassbox-mol-audit \
  --create-namespace \
  -f ./manifest/chart/values-standard.yaml \
  --set config.gcpRegion=europe-west4 \
  --set image.repository=europe-docker.pkg.dev/PROJECT/REPOSITORY/glassbox-mol-audit \
  --set image.digest=sha256:REPLACE_ME
```

Deep profile:

```bash
helm upgrade --install glassbox-mol-audit ./manifest/chart \
  --namespace glassbox-mol-audit \
  --create-namespace \
  -f ./manifest/chart/values-standard.yaml \
  -f ./manifest/chart/values-gpu.yaml \
  --set config.gcpRegion=europe-west4 \
  --set image.repository=europe-docker.pkg.dev/PROJECT/REPOSITORY/glassbox-mol-audit-deep-tools \
  --set image.digest=sha256:REPLACE_ME \
  --set config.runMode=deep
```

## Notes

- `config.runMode=standard|deep` selects the runtime mode.
- `config.gcpRegion`, `config.dataResidency`, and `config.egressMode` should be set explicitly for each deployment.
- `ubbagent.metricNameStandard` and `ubbagent.metricNameDeep` are the mode-aware Marketplace usage metrics.
- Supported Marketplace deployments must set `marketplace.reportingSecret`, enable `ubbagent`, and provide `ubbagent.image.repository` plus either tag or digest values.
- The deep/GPU overlay requires a compatible GPU node pool with available capacity in the target zone.
- The V1 chart does not render any console/UI resources; the reserved `console` values block is kept only as a placeholder for a future product.
