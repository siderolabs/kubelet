REGISTRY ?= ghcr.io
USERNAME ?= siderolabs
SHA ?= $(shell git describe --match=none --always --abbrev=8 --dirty)
TAG ?= $(shell git describe --tag --always --dirty)
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
REGISTRY_AND_USERNAME := $(REGISTRY)/$(USERNAME)
NAME := kubelet
KUBELET_VER := v1.21.13
KUBELET_SHA512_AMD64 := 2af58bbb71e6c14e89517ff5b1a1d5467941f9985c50e157506af3880a58f5cd195b4f722ba2e4ca0c092b11ba987b929413e0cbf4d8f42103026aa6c3eba63d
KUBELET_SHA512_ARM64 := dd14f2041e0d2c6b2f3c398d4fb5c001e95ca849f7215c7cf0091c856c12b84b45185775dae121f9b30ff1c537fa33e6248bd326b9e25f3c2fca04069eb44a81

BUILD := docker buildx build
PLATFORM ?= linux/amd64,linux/arm64
PROGRESS ?= auto
PUSH ?= false
COMMON_ARGS := --file=Dockerfile
COMMON_ARGS += --progress=$(PROGRESS)
COMMON_ARGS += --platform=$(PLATFORM)
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
