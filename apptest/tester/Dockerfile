FROM python:3.11-slim

# Marketplace-required OCI annotation (set via build arg for CI/CD).
ARG MP_SERVICE_NAME=services/molecular-audit-core.endpoints.glassbox-bio-public.cloud.goog
LABEL com.googleapis.cloudmarketplace.product.service.name=${MP_SERVICE_NAME}

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    jq \
    curl \
    tar \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /bin/kubectl \
    https://storage.googleapis.com/kubernetes-release/release/v1.27.0/bin/linux/amd64/kubectl \
      && chmod 755 /bin/kubectl

COPY tests/basic-suite.yaml /tests/basic-suite.yaml
COPY run_tests.py /run_tests.py
COPY fixtures/test/ /fixtures/test/

WORKDIR /
RUN pip install --no-cache-dir pyyaml
ENTRYPOINT ["python", "/run_tests.py"]
