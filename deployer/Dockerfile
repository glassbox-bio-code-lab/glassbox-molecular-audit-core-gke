# Go 1.25.9 includes the fix for CVE-2026-27143 in the toolchain used to build kubectl and helm.
ARG GOLANG_BUILD_IMAGE=golang:1.25.9
ARG HELM_VERSION=v3.20.1
ARG KUBECTL_VERSION=v1.34.3
ARG MARKETPLACE_TOOLS_REF=744d114ffa5ed6eec5b3154301162cdf4fab92b0

FROM alpine:3.22 AS marketplace-tools
ARG MARKETPLACE_TOOLS_REF
RUN apk add --no-cache git
RUN git clone https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools.git /marketplace-k8s-app-tools \
    && cd /marketplace-k8s-app-tools \
    && git checkout "${MARKETPLACE_TOOLS_REF}" \
    && rm -rf .git

FROM ${GOLANG_BUILD_IMAGE} AS kubectl-builder
ARG KUBECTL_VERSION
WORKDIR /src
RUN curl -fsSLo kubernetes-src.tar.gz "https://github.com/kubernetes/kubernetes/archive/refs/tags/${KUBECTL_VERSION}.tar.gz" \
    && tar -xzf kubernetes-src.tar.gz --strip-components=1 \
    && /usr/local/go/bin/go mod edit \
      -require=golang.org/x/net@v0.38.0 \
      -require=golang.org/x/oauth2@v0.27.0 \
      -require=github.com/moby/spdystream@v0.5.1 \
    && /usr/local/go/bin/go work vendor \
    && /usr/local/go/bin/go list -mod=vendor -m github.com/moby/spdystream \
    && PATH=/usr/local/go/bin:$PATH make kubectl KUBE_VERBOSE=0 \
    && install -D _output/local/go/bin/kubectl /out/kubectl

FROM ${GOLANG_BUILD_IMAGE} AS helm-builder
ARG HELM_VERSION
WORKDIR /src
RUN curl -fsSLo helm-src.tar.gz "https://github.com/helm/helm/archive/refs/tags/${HELM_VERSION}.tar.gz" \
    && tar -xzf helm-src.tar.gz --strip-components=1 \
    && /usr/local/go/bin/go get \
      golang.org/x/crypto@v0.46.0 \
      golang.org/x/net@v0.48.0 \
      golang.org/x/oauth2@v0.34.0 \
      google.golang.org/grpc@v1.79.3 \
      google.golang.org/protobuf@v1.36.10 \
    && /usr/local/go/bin/go mod download \
    && CGO_ENABLED=0 /usr/local/go/bin/go build -trimpath -o /out/helm ./cmd/helm

FROM ubuntu:22.04
ARG HELM_VERSION
ARG KUBECTL_VERSION
ARG MP_SERVICE_NAME=services/molecular-audit-core.endpoints.glassbox-bio-public.cloud.goog

LABEL com.googleapis.cloudmarketplace.product.service.name=${MP_SERVICE_NAME}

RUN apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      gettext \
      jq \
      python3 \
      python3-pip \
      python-is-python3 \
    && python3 -m pip install --no-cache-dir --upgrade "pip>=24.0" \
    && python3 -m pip install --no-cache-dir --upgrade \
      "pyOpenSSL>=26,<27" \
      "pyyaml>=6,<7" \
      "cryptography>=46.0.7,<47" \
    && python3 -c 'import importlib.metadata as m; v=tuple(int(p) for p in m.version("cryptography").split(".")[:3]); assert (46,0,7) <= v < (47,0,0), m.version("cryptography"); print("cryptography validation ok:", m.version("cryptography"))' \
    && apt-get purge -y python3-pip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=kubectl-builder /out/kubectl /opt/kubectl/1.34/kubectl
COPY --from=helm-builder /out/helm /usr/bin/helm
COPY --from=marketplace-tools /marketplace-k8s-app-tools/marketplace/deployer_helm_base/ /bin/
COPY --from=marketplace-tools /marketplace-k8s-app-tools/marketplace/deployer_util/ /bin/

RUN chmod 0755 /opt/kubectl/1.34/kubectl /usr/bin/helm /bin/*.sh /bin/*.py \
    && ln -snf /opt/kubectl/1.34 /opt/kubectl/default

ENV PATH="/opt/kubectl/default:${PATH}"

RUN mkdir -p /data/chart /data-test/chart

# Primary install bundle in the layout expected by deployer_helm:create_manifests.sh
COPY manifest/chart/ /tmp/marketplace-main/chart/
RUN tar -czf /data/chart/chart-bundle.tar.gz -C /tmp/marketplace-main chart \
    && rm -rf /tmp/marketplace-main
COPY schema.yaml /data/schema.yaml

# Verification overlay in the layout expected by deployer_helm:create_manifests.sh
COPY apptest/deployer/manifest/chart/values.yaml /tmp/marketplace-test/chart/values.yaml
RUN tar -czf /data-test/chart/chart-bundle.tar.gz -C /tmp/marketplace-test chart \
    && rm -rf /tmp/marketplace-test
COPY apptest/deployer/schema.yaml /data-test/schema.yaml

ENV SCHEMA=/data/schema.yaml
ENV WAIT_FOR_READY_TIMEOUT=1800
ENV TESTER_TIMEOUT=1800

# Use the base image deploy script (Helm deployer).
ENTRYPOINT ["/bin/bash", "/bin/deploy.sh"]
