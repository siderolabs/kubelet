## Using the builder this way keeps us from having to install wget and adding an extra
## fat step that just does a chmod on the kubelet binary

ARG BASE_IMAGE=registry.k8s.io/build-image/debian-iptables:bookworm-v1.0.0
ARG SLIM_PACKAGES="ca-certificates libcap2 ethtool iproute2 nfs-common socat util-linux"

FROM alpine:latest AS builder-amd64

ARG TARGETARCH
ARG KUBELET_VER
ARG KUBELET_SHA512_AMD64
ARG KUBELET_URL=https://dl.k8s.io/release/${KUBELET_VER}/bin/linux/${TARGETARCH}/kubelet

RUN wget -q -O /kubelet ${KUBELET_URL} \
  && sha512sum /kubelet \
  && echo "${KUBELET_SHA512_AMD64}  /kubelet" | sha512sum -cw \
  && chmod +x /kubelet

FROM alpine:latest AS builder-arm64

ARG TARGETARCH
ARG KUBELET_VER
ARG KUBELET_SHA512_ARM64
ARG KUBELET_URL=https://dl.k8s.io/release/${KUBELET_VER}/bin/linux/${TARGETARCH}/kubelet

RUN wget -q -O /kubelet ${KUBELET_URL} \
  && sha512sum /kubelet \
  && echo "${KUBELET_SHA512_ARM64}  /kubelet" | sha512sum -cw \
  && chmod +x /kubelet

ARG TARGETARCH
FROM builder-${TARGETARCH} AS builder

########################

FROM ${BASE_IMAGE} AS container-fat

RUN clean-install \
  --allow-change-held-packages \
  ${SLIM_PACKAGES} \
  bash \
  ceph-common \
  cifs-utils \
  e2fsprogs \
  ethtool \
  glusterfs-client \
  jq \
  procps \
  ucf \
  udev \
  xfsprogs

COPY --from=builder /kubelet /usr/local/bin/kubelet

# Add wrapper for iscsiadm
COPY files/iscsiadm /usr/local/sbin/iscsiadm

LABEL org.opencontainers.image.source="https://github.com/siderolabs/kubelet"

ENTRYPOINT ["/usr/local/bin/kubelet"]

########################

FROM ${BASE_IMAGE} AS container-slim

RUN clean-install \
  --allow-change-held-packages \
  ${SLIM_PACKAGES}

COPY --from=builder /kubelet /usr/local/bin/kubelet

LABEL org.opencontainers.image.source="https://github.com/siderolabs/kubelet"

ENTRYPOINT ["/usr/local/bin/kubelet"]
