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




## Contents

- `manifest/` - Marketplace deployment bundle (Helm chart, schema, Application CR).
- `docs/` - User guide, operations guide, and verification notes.
- `examples/` - Sample values files and CLI commands.
<br/>
<br/>

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
| Standard (CPU)        | 10-15 min              | $$               | 2–4 vCPU, 8–16Gi RAM, 50Gi PVC                  | Default choice for most audits; balanced speed vs cost              |
| Deep / GPU (optional) | 15-30 min              | $$$              | 4–8 vCPU, 32–64Gi RAM, 1x NVIDIA GPU, 200Gi PVC | Deep evidence expansion, docking-heavy or GPU-accelerated workflows |
<br/>
<br/>

```bash
helm upgrade --install molecular-audit-core ./manifest/chart \
  --namespace molecular-audit-core --create-namespace \
  -f ./manifest/chart/values-standard.yaml \
  -f ./examples/values-gcs.yaml \
  --set storage.gcs.bucket=YOUR_BUCKET \
  --set workloadIdentity.gcpServiceAccount=your-sa@project.iam.gserviceaccount.com \
  --set image.repository=us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit \
  --set image.tag=2026.03.10-v0.3 \
  --set console.image.repository=us-central1-docker.pkg.dev/glassbox-marketplace-prod/glassbox-bio-molecular-audit/molecular-audit-core/console \
  --set console.image.tag=2026.03.10-v0.3 \
  --set config.projectId=YOUR_PROJECT_ID
```
<br/>

Or run with Makefile
```bash
## Standard

```bash

export WORKLOAD_IDENTITY_GSA="your-sa@project.iam.gserviceaccount.com"
export PROJECT_ID="test"
export CATEGORY_ID="SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ"

# Bare digest only. The standard target selects the standard public repository automatically.
export IMAGE_DIGEST="sha256:aba9fa19c286a87e9d406dcd74f69d998f041a9aaf7d5c9023c1058195752356"

make deploy-manifest-infra-standard IMAGE_DIGEST="${IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}"
make stage-manifest-input-standard PROJECT_ID="${PROJECT_ID}" IMAGE_DIGEST="${IMAGE_DIGEST}"
make deploy-manifest-job-standard PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" IMAGE_DIGEST="${IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}"
make fetch-manifest-output-standard IMAGE_DIGEST="${IMAGE_DIGEST}"
```

## Deep

```bash

export WORKLOAD_IDENTITY_GSA="your-sa@project.iam.gserviceaccount.com"

export PROJECT_ID="test"
export CATEGORY_ID="SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ"

# Bare digest only. The deep target selects the deep public repository automatically.
export IMAGE_DIGEST="sha256:a0f32e6184ca2dcdb16c39e642e895add74c1da4bd3455d9a39b4a801e504f37"

make deploy-manifest-infra-deep IMAGE_DIGEST="${IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}"
make stage-manifest-input-deep PROJECT_ID="${PROJECT_ID}" IMAGE_DIGEST="${IMAGE_DIGEST}"
make deploy-manifest-job-deep PROJECT_ID="${PROJECT_ID}" CATEGORY_ID="${CATEGORY_ID}" IMAGE_DIGEST="${IMAGE_DIGEST}" WORKLOAD_IDENTITY_GSA="${WORKLOAD_IDENTITY_GSA}"
make fetch-manifest-output-deep IMAGE_DIGEST="${IMAGE_DIGEST}"
```


For the full runbook and verification flow, see `docs/RUNBOOK_CUSTOMER.md`.
<br/>
<br/>

## Marketplace Architecture (V1)

![Marketplace Architecture V1](docs/marketplace_architecture_v1.png)
<br/>
<br/>

## System Architecture (Detailed)

![System Architecture](docs/architecture_v1.png)

<br/>
<br/>



## Security Model

- Images are pulled from Google Artifact Registry.
- Customer data remains within the customer's GCP project.
- No audit data is transmitted outside the configured environment.
- Optional Workload Identity integration supported.



<br/>
<br/>

## Cryptographic Provenance Seal Completed audit runs may include a dual-channel, tamper-evident provenance seal. ![Cryptographic Provenance Seal](docs/provenance_seal.png) ### Verification Each seal can be independently verified: https://verify.glassbox-bio.com
**Seal Model**

- Signing key: Google Cloud KMS (private)
- Hashing: SHA-256
- Verification: Public verification endpoint
- Data boundary: Customer data does not egress; verification transmits metadata only


<br/>
<br/>


## Glassbox Bio Target Diligence Core
Deployment bundle provided here contains configuration and public artifacts only.

For full product information, methodology, and security documentation:

👉 https://www.glassbox-bio.com












