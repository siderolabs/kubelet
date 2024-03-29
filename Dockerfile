## Using the builder this way keeps us from having to install wget and adding an extra
## fat step that just does a chmod on the kubelet binary

FROM alpine:latest as builder-amd64

ARG TARGETARCH
ARG KUBELET_VER
ARG KUBELET_SHA512_AMD64
ARG KUBELET_URL=https://dl.k8s.io/release/${KUBELET_VER}/bin/linux/${TARGETARCH}/kubelet

RUN wget -q -O /kubelet ${KUBELET_URL} \
  && sha512sum /kubelet \
  && echo "${KUBELET_SHA512_AMD64}  /kubelet" | sha512sum -cw \
  && chmod +x /kubelet

FROM alpine:latest as builder-arm64

ARG TARGETARCH
ARG KUBELET_VER
ARG KUBELET_SHA512_ARM64
ARG KUBELET_URL=https://dl.k8s.io/release/${KUBELET_VER}/bin/linux/${TARGETARCH}/kubelet

RUN wget -q -O /kubelet ${KUBELET_URL} \
  && sha512sum /kubelet \
  && echo "${KUBELET_SHA512_ARM64}  /kubelet" | sha512sum -cw \
  && chmod +x /kubelet

ARG TARGETARCH
FROM builder-${TARGETARCH} as builder

FROM registry.k8s.io/build-image/debian-iptables:bookworm-v1.0.0 as container

RUN clean-install \
  --allow-change-held-packages \
  procps \
  bash \
  ca-certificates \
  libcap2 \
  cifs-utils \
  e2fsprogs \
  xfsprogs \
  ethtool \
  glusterfs-client \
  iproute2 \
  jq \
  nfs-common \
  socat \
  ucf \
  udev \
  util-linux \
  ceph-common

COPY --from=builder /kubelet /usr/local/bin/kubelet

# Add wrapper for iscsiadm
COPY files/iscsiadm /usr/local/sbin/iscsiadm

LABEL org.opencontainers.image.source https://github.com/siderolabs/kubelet

ENTRYPOINT ["/usr/local/bin/kubelet"]
