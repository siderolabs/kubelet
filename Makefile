REGISTRY ?= ghcr.io
USERNAME ?= siderolabs
SHA ?= $(shell git describe --match=none --always --abbrev=8 --dirty)
TAG ?= $(shell git describe --tag --always --dirty)
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
REGISTRY_AND_USERNAME := $(REGISTRY)/$(USERNAME)
NAME := kubelet
KUBELET_VER := v1.23.17
KUBELET_SHA512_AMD64 := 549b58ecfbbf76778fdfa30e1f6ef5e5e16d24ea707209576428d4b3014fd963d4a05463ec78194c1b536548016e7c45f2d9c0e36df41d260ba835fca792052e
KUBELET_SHA512_ARM64 := 956783f07234501aac856764d1aed571d8e35f36c64aa022e105c6a76233d8fcf8645989936372787d9f2e37b8605c70ef55bbfecfdff52a4de7c598d1581c71

BUILD := docker buildx build
PLATFORM ?= linux/amd64,linux/arm64
PROGRESS ?= auto
PUSH ?= false
COMMON_ARGS := --file=Dockerfile
COMMON_ARGS += --progress=$(PROGRESS)
COMMON_ARGS += --platform=$(PLATFORM)
COMMON_ARGS += --provenance=false
COMMON_ARGS += --build-arg=REGISTRY_AND_USERNAME=$(REGISTRY_AND_USERNAME)
COMMON_ARGS += --build-arg=NAME=$(NAME)
COMMON_ARGS += --build-arg=TAG=$(TAG)
COMMON_ARGS += --build-arg=KUBELET_VER=$(KUBELET_VER)
COMMON_ARGS += --build-arg=KUBELET_SHA512_AMD64=$(KUBELET_SHA512_AMD64)
COMMON_ARGS += --build-arg=KUBELET_SHA512_ARM64=$(KUBELET_SHA512_ARM64)

all: container

target-%: ## Builds the specified target defined in the Dockerfile. The build result will remain only in the build cache.
	@$(BUILD) \
		--target=$* \
		$(COMMON_ARGS) \
		$(TARGET_ARGS) .

local-%: ## Builds the specified target defined in the Dockerfile using the local output type. The build result will be output to the specified local destination.
	@$(MAKE) target-$* TARGET_ARGS="--output=type=local,dest=$(DEST) $(TARGET_ARGS)"

docker-%: ## Builds the specified target defined in the Dockerfile using the default output type.
	@$(MAKE) target-$* TARGET_ARGS="--tag $(REGISTRY_AND_USERNAME)/$(NAME):$(TAG) $(TARGET_ARGS)"

.PHONY: container
container:
	@$(MAKE) docker-$@ TARGET_ARGS="--push=$(PUSH)"

.PHONY: update-sha
update-sha: update-sha-amd64 update-sha-arm64 ## Updates the kubelet sha512 checksums in the Makefile.

update-sha-%:
	sha512=`curl -sL https://storage.googleapis.com/kubernetes-release/release/$(KUBELET_VER)/bin/linux/${*}/kubelet.sha512`; \
		sed -i "s/KUBELET_SHA512_$(shell echo '$*' | tr '[:lower:]' '[:upper:]') := .*/KUBELET_SHA512_$(shell echo '$*' | tr '[:lower:]' '[:upper:]') := $${sha512}/" Makefile
