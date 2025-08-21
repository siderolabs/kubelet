REGISTRY ?= ghcr.io
USERNAME ?= siderolabs
SHA ?= $(shell git describe --match=none --always --abbrev=8 --dirty)
TAG ?= $(shell git describe --tag --always --dirty)
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
REGISTRY_AND_USERNAME := $(REGISTRY)/$(USERNAME)
NAME := kubelet
KUBELET_VER := v1.34.0-rc.2
KUBELET_SHA512_AMD64 := 9ac0ab9c877d44fd5493564c2fa12f77b470006ddbcfe9a60d908e319527c2a362f549dcf7043e039c2f50fef9f94fcc5ada7b02a6384516d3d09e9c1f0c5d7f
KUBELET_SHA512_ARM64 := 250427af77aebc9d0cf5a19e3204e7bdd64a83badee9fb343fd8463802f6761f4a5cb9f1ada92504dee5d4c16ef84804630aabbe6f470558f1956ff2009dcde2

# For kubelet versions >= 1.31.0, the slim image is the default one, and previous image is labeled as -fat.
# For kubelet versions < 1.31.0, the fat image is the default one, and previous image is labeled as -slim.
USE_SLIM := $(shell (printf "%s\n" "$(KUBELET_VER)" "v1.30.99" | sort -V -C) && echo false || echo true)

ifeq ($(USE_SLIM),true)
	SLIM_TAG_SUFFIX :=
	FAT_TAG_SUFFIX := -fat
else
	SLIM_TAG_SUFFIX := -slim
	FAT_TAG_SUFFIX :=
endif

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

KRES_IMAGE ?= ghcr.io/siderolabs/kres:latest

all: container

target-%: ## Builds the specified target defined in the Dockerfile. The build result will remain only in the build cache.
	@$(BUILD) \
		--target=$* \
		$(COMMON_ARGS) \
		$(TARGET_ARGS) .

local-%: ## Builds the specified target defined in the Dockerfile using the local output type. The build result will be output to the specified local destination.
	@$(MAKE) target-$* TARGET_ARGS="--output=type=local,dest=$(DEST) $(TARGET_ARGS)"

docker-%: ## Builds the specified target defined in the Dockerfile using the default output type.
	@$(MAKE) target-$*-fat TARGET_ARGS="--tag $(REGISTRY_AND_USERNAME)/$(NAME):$(TAG)$(FAT_TAG_SUFFIX) $(TARGET_ARGS)"
	@$(MAKE) target-$*-slim TARGET_ARGS="--tag $(REGISTRY_AND_USERNAME)/$(NAME):$(TAG)$(SLIM_TAG_SUFFIX) $(TARGET_ARGS)"

.PHONY: container
container:
	@$(MAKE) docker-$@ TARGET_ARGS="--push=$(PUSH)"

.PHONY: update-sha
update-sha: update-sha-amd64 update-sha-arm64 ## Updates the kubelet sha512 checksums in the Makefile.

update-sha-%:
	sha512=`curl -sL https://dl.k8s.io/release/$(KUBELET_VER)/bin/linux/${*}/kubelet.sha512`; \
		sed -i "s/KUBELET_SHA512_$(shell echo '$*' | tr '[:lower:]' '[:upper:]') := .*/KUBELET_SHA512_$(shell echo '$*' | tr '[:lower:]' '[:upper:]') := $${sha512}/" Makefile

.PHONY: rekres
rekres:
	@docker pull $(KRES_IMAGE)
	@docker run --rm --net=host --user $(shell id -u):$(shell id -g) -v $(PWD):/src -w /src -e GITHUB_TOKEN $(KRES_IMAGE)
