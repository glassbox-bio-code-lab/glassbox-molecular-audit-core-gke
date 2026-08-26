# Release 1.1.0 image manifest

Status: the release images are published to `glassbox-bio-public`, match the digests below, and the deployer passed the official Marketplace package verifier on 2026-08-26. Marketplace Full Preview and the customer-billed Standard scientific workload remain release gates; Deep also requires a GPU-capable validation cluster.

Use this deployer tag for the Google Cloud Marketplace release:

```text
us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deployer:1.1.0
```

The `1.1.0` component images are immutable at these digests:

| Role | Production image | Digest |
| --- | --- | --- |
| Standard runtime | `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit:1.1.0` | `sha256:fc3f267a130f5a08fcd91cb0f1fc20ec6471c4812c0747df222cd2e205904251` |
| Deep runtime | `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deep-tools:1.1.0` | `sha256:30612ef01f510578314fd973a1dbb3fb5ce944d6d4e62da49d7d4e08dcde06ef` |
| Deployer | `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deployer:1.1.0` | `sha256:75e6c5b69dac14c01d217a040a69ffc894f035adf603e09cc5ea822229f33d19` |
| Marketplace tester | `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/tester:1.1.0` | `sha256:744c0e4829ed8913b51eb64bcf9c0e9d8190edeae77c11473b050b1777aeec2b` |
| UBB agent | `us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/ubbagent:1.1.0` | `sha256:03375864c4e0f35654651a8b145dda5cdf1c8742964f7fc0aeb022fda386459a` |

For runtime launches, use the bare digest value in the corresponding Helm or launcher digest field. Do not substitute a mutable tag.
