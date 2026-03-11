ARG DEPLOYER_BASE_IMAGE=gcr.io/cloud-marketplace-tools/k8s/deployer_helm:0.12.0
FROM ${DEPLOYER_BASE_IMAGE}

RUN mkdir -p /data /data-test

# Primary install bundle
COPY manifest/ /data/manifest/
COPY schema.yaml /data/schema.yaml

# Marketplace verification bundle (schema + tester manifest overrides)
COPY apptest/deployer/ /data-test/

ENV HELM_CHART=/data/manifest/chart
ENV HELM_VALUES=/data/manifest/chart/values.yaml
ENV APP_CR=/data/manifest/application.yaml
ENV SCHEMA=/data/schema.yaml

# Use the base image deploy script (Helm deployer).
ENTRYPOINT ["/bin/bash", "/bin/deploy.sh"]
