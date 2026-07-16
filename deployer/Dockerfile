ARG DEPLOYER_BASE_IMAGE=gcr.io/cloud-marketplace-tools/k8s/deployer_helm:0.12.12
# Go 1.25.12 includes current stdlib fixes in the toolchain used to build kubectl and helm.
ARG GOLANG_BUILD_IMAGE=golang:1.25.12
ARG RUST_BUILD_IMAGE=rust:1.91-bullseye
ARG HELM_VERSION=v3.20.1
ARG KUBECTL_130_VERSION=v1.30.14
ARG KUBECTL_131_VERSION=v1.31.14

FROM ${GOLANG_BUILD_IMAGE} AS kubectl-130-builder
ARG KUBECTL_130_VERSION
WORKDIR /src
RUN curl -fsSLo kubernetes-src.tar.gz "https://github.com/kubernetes/kubernetes/archive/refs/tags/${KUBECTL_130_VERSION}.tar.gz" \
    && tar -xzf kubernetes-src.tar.gz --strip-components=1 \
    && /usr/local/go/bin/go mod edit \
      -require=github.com/moby/spdystream@v0.5.1 \
      -require=golang.org/x/crypto@v0.52.0 \
      -require=golang.org/x/net@v0.54.0 \
      -require=golang.org/x/oauth2@v0.34.0 \
    && /usr/local/go/bin/go work vendor \
    && PATH=/usr/local/go/bin:$PATH make kubectl KUBE_VERBOSE=0 \
    && install -D _output/local/go/bin/kubectl /out/kubectl

FROM ${GOLANG_BUILD_IMAGE} AS kubectl-131-builder
ARG KUBECTL_131_VERSION
WORKDIR /src
RUN curl -fsSLo kubernetes-src.tar.gz "https://github.com/kubernetes/kubernetes/archive/refs/tags/${KUBECTL_131_VERSION}.tar.gz" \
    && tar -xzf kubernetes-src.tar.gz --strip-components=1 \
    && /usr/local/go/bin/go mod edit \
      -require=github.com/moby/spdystream@v0.5.1 \
      -require=golang.org/x/crypto@v0.52.0 \
      -require=golang.org/x/net@v0.54.0 \
      -require=golang.org/x/oauth2@v0.34.0 \
    && /usr/local/go/bin/go work vendor \
    && PATH=/usr/local/go/bin:$PATH make kubectl KUBE_VERBOSE=0 \
    && install -D _output/local/go/bin/kubectl /out/kubectl

FROM ${GOLANG_BUILD_IMAGE} AS helm-builder
ARG HELM_VERSION
WORKDIR /src
RUN curl -fsSLo helm-src.tar.gz "https://github.com/helm/helm/archive/refs/tags/${HELM_VERSION}.tar.gz" \
    && tar -xzf helm-src.tar.gz --strip-components=1 \
    && /usr/local/go/bin/go get \
      github.com/containerd/containerd@v1.7.33 \
      golang.org/x/crypto@v0.52.0 \
      golang.org/x/net@v0.54.0 \
      golang.org/x/oauth2@v0.34.0 \
      google.golang.org/grpc@v1.79.3 \
      google.golang.org/protobuf@v1.36.10 \
      oras.land/oras-go/v2@v2.6.1 \
    && /usr/local/go/bin/go mod download \
    && CGO_ENABLED=0 /usr/local/go/bin/go build -trimpath -o /out/helm ./cmd/helm

FROM ${RUST_BUILD_IMAGE} AS rust-toolchain

FROM ${DEPLOYER_BASE_IMAGE} AS cryptography-builder
COPY --from=rust-toolchain /usr/local/cargo /usr/local/cargo
COPY --from=rust-toolchain /usr/local/rustup /usr/local/rustup
ENV PATH=/usr/local/cargo/bin:${PATH} \
    CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup
RUN apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get install -y --no-install-recommends \
      build-essential \
      libssl-dev \
      pkg-config \
      python3-dev \
    && python3 -m pip install --no-cache-dir --upgrade "pip>=24.0" \
    && python3 -m pip wheel --no-cache-dir --no-deps --no-binary=cryptography \
      --wheel-dir /wheels "cryptography>=48.0.1,<49"

FROM ${DEPLOYER_BASE_IMAGE}
ARG HELM_VERSION
ARG KUBECTL_130_VERSION
ARG KUBECTL_131_VERSION
ARG MP_SERVICE_NAME=services/molecular-audit-core.endpoints.glassbox-bio-public.cloud.goog

LABEL com.googleapis.cloudmarketplace.product.service.name=${MP_SERVICE_NAME}

RUN apt-get update \
    && apt-get dist-upgrade -y \
    && python3 -m pip install --no-cache-dir --upgrade "pip>=24.0" \
    && rm -rf /var/lib/apt/lists/*

COPY --from=cryptography-builder /wheels/ /tmp/cryptography-wheels/
RUN python3 -m pip install --no-cache-dir --upgrade \
      /tmp/cryptography-wheels/cryptography-*.whl \
      "pyOpenSSL>=26,<27" \
    && rm -rf /tmp/cryptography-wheels \
    && apt-get purge -y python3-pip wget gnupg2 \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=kubectl-130-builder /out/kubectl /opt/kubectl/1.30/kubectl
COPY --from=kubectl-131-builder /out/kubectl /opt/kubectl/1.31/kubectl
COPY --from=helm-builder /out/helm /usr/bin/helm

RUN chmod 0755 /opt/kubectl/1.30/kubectl /opt/kubectl/1.31/kubectl /usr/bin/helm \
    && ln -snf /opt/kubectl/1.31 /opt/kubectl/default

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
