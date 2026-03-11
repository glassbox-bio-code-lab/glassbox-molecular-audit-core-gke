# Glassbox Bio Molecular Audit Helm Chart

This directory contains the Helm chart for the Glassbox Bio Molecular Audit runtime.

Operational and reviewer instructions live at the repository root:

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
  --set image.repository=us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit \
  --set image.digest=sha256:REPLACE_ME
```

Deep profile:

```bash
helm upgrade --install glassbox-mol-audit ./manifest/chart \
  --namespace glassbox-mol-audit \
  --create-namespace \
  -f ./manifest/chart/values-standard.yaml \
  -f ./manifest/chart/values-gpu.yaml \
  --set image.repository=us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit-deep-tools \
  --set image.digest=sha256:REPLACE_ME \
  --set config.runMode=deep
```

## Notes

- `config.runMode=standard|deep` selects the runtime mode.
- `ubbagent.metricNameStandard` and `ubbagent.metricNameDeep` are the mode-aware Marketplace usage metrics.
- The deep/GPU overlay requires a compatible GPU node pool with available capacity in the target zone.
- The V1 chart does not render any console/UI resources; the reserved `console` values block is kept only as a placeholder for a future product.
- Internal release validation uses `../../../docs/MARKETPLACE_REVIEW_CHECKLIST.md`.
