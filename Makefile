REGISTRY ?= ghcr.io
USERNAME ?= talos-systems
SHA ?= $(shell git describe --match=none --always --abbrev=8 --dirty)
TAG ?= $(shell git describe --tag --always --dirty)
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
REGISTRY_AND_USERNAME := $(REGISTRY)/$(USERNAME)
NAME := kubelet
KUBELET_VER := v1.21.0-beta.0
KUBELET_SHA512_AMD64 := 770af1699a9539d1bf233565df06b60eda084c84d11c4a661ec75a46696ea7478058d7202b5706c4617342133cab95d894a63d295c828156699df5b6d7ba7a5d
KUBELET_SHA512_ARM64 := a6826303664090359d13569f0255f027eddff4d2201a2cb87ef5e6b9f1491293e92ba4f56074c8c2a17bb5ab93d8c14965debde580ca01e2603754a84ada22e0

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
