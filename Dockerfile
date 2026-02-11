## Using the builder this way keeps us from having to install wget and adding an extra
## fat step that just does a chmod on the kubelet binary

ARG BASE_IMAGE=registry.k8s.io/build-image/debian-iptables:bookworm-v1.0.0
ARG SLIM_PACKAGES="ca-certificates libcap2 nfs-common util-linux"
ARG FAT_PACKAGES="bash ceph-common cifs-utils e2fsprogs glusterfs-client jq procps ucf udev xfsprogs socat iproute2 ethtool"

FROM alpine:latest AS builder

RUN apk add --no-cache cosign

ARG TARGETARCH
ARG KUBELET_VER
ARG KUBELET_URL=https://dl.k8s.io/release/${KUBELET_VER}/bin/linux/${TARGETARCH}/kubelet

RUN wget -q -O /kubelet ${KUBELET_URL}
RUN wget -q -O /kubelet.sig ${KUBELET_URL}.sig
RUN wget -q -O /kubelet.cert ${KUBELET_URL}.cert

# see https://kubernetes.io/docs/tasks/administer-cluster/verify-signed-artifacts/
RUN cosign verify-blob "/kubelet" \
  --signature "/kubelet.sig" \
  --certificate "/kubelet.cert" \
  --certificate-identity krel-staging@k8s-releng-prod.iam.gserviceaccount.com \
  --certificate-oidc-issuer https://accounts.google.com

RUN chmod +x /kubelet

########################

FROM ${BASE_IMAGE} AS base-updated
RUN <<EOF
  apt-get update
  apt-get upgrade -y
  apt-get clean -y
  rm -rf \
    /var/cache/debconf/* \
    /var/lib/apt/lists/* \
    /var/log/* \
    /tmp/* \
    /var/tmp/*
EOF

FROM scratch AS base
COPY --from=base-updated / /

########################

FROM base AS container-fat

ARG SLIM_PACKAGES
RUN clean-install \
  --allow-change-held-packages \
  ${SLIM_PACKAGES} \
  ${FAT_PACKAGES}

COPY --from=builder /kubelet /usr/local/bin/kubelet

# Add wrapper for iscsiadm
COPY files/iscsiadm /usr/local/sbin/iscsiadm

LABEL org.opencontainers.image.source="https://github.com/siderolabs/kubelet"

ENTRYPOINT ["/usr/local/bin/kubelet"]

########################

FROM base AS container-slim

ARG SLIM_PACKAGES
RUN clean-install \
  --allow-change-held-packages \
  ${SLIM_PACKAGES}

COPY --from=builder /kubelet /usr/local/bin/kubelet

LABEL org.opencontainers.image.source="https://github.com/siderolabs/kubelet"

ENTRYPOINT ["/usr/local/bin/kubelet"]
