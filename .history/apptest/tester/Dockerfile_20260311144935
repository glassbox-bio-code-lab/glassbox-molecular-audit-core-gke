FROM python:3.11-slim

# Marketplace-required OCI annotation (set via build arg for CI/CD).
ARG MP_SERVICE_NAME=services/molecular-audit-core.endpoints.glassbox-bio-public.cloud.goog
LABEL com.googleapis.cloudmarketplace.product.service.name=${MP_SERVICE_NAME}

ARG KUBECTL_VERSION=v1.34.3

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    jq \
    curl \
    tar \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /bin/kubectl \
    https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
      && chmod 755 /bin/kubectl

COPY tests/basic-suite.yaml /tests/basic-suite.yaml
COPY run_tests.py /run_tests.py
COPY fixtures/test/ /fixtures/test/

WORKDIR /
RUN pip install --no-cache-dir pyyaml
ENTRYPOINT ["python", "/run_tests.py"]
