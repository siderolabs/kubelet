REGISTRY ?= ghcr.io
USERNAME ?= siderolabs
SHA ?= $(shell git describe --match=none --always --abbrev=8 --dirty)
TAG ?= $(shell git describe --tag --always --dirty)
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
REGISTRY_AND_USERNAME := $(REGISTRY)/$(USERNAME)
NAME := kubelet
ARTIFACTS := _out
OPERATING_SYSTEM := $(shell uname -s | tr '[:upper:]' '[:lower:]')
GOARCH := $(shell uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
KUBELET_VER := v1.34.6

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

KRES_IMAGE ?= ghcr.io/siderolabs/kres:latest
IMAGE_SIGNER_RELEASE ?= v0.2.0
SLIM_IMAGE ?= $(REGISTRY_AND_USERNAME)/$(NAME):$(TAG)
FAT_IMAGE ?= $(REGISTRY_AND_USERNAME)/$(NAME):$(TAG)-fat

all: container

target-%: ## Builds the specified target defined in the Dockerfile. The build result will remain only in the build cache.
	@$(BUILD) \
		--target=$* \
		$(COMMON_ARGS) \
		$(TARGET_ARGS) .

local-%: ## Builds the specified target defined in the Dockerfile using the local output type. The build result will be output to the specified local destination.
	@$(MAKE) target-$* TARGET_ARGS="--output=type=local,dest=$(DEST) $(TARGET_ARGS)"

docker-%: ## Builds the specified target defined in the Dockerfile using the default output type.
	@$(MAKE) target-$*-fat TARGET_ARGS="--tag $(FAT_IMAGE) $(TARGET_ARGS)"
	@$(MAKE) target-$*-slim TARGET_ARGS="--tag $(SLIM_IMAGE) $(TARGET_ARGS)"

.PHONY: container
container:
	@$(MAKE) docker-$@ TARGET_ARGS="--push=$(PUSH)"

.PHONY: rekres
rekres:
	@docker pull $(KRES_IMAGE)
	@docker run --rm --net=host --user $(shell id -u):$(shell id -g) -v $(PWD):/src -w /src -e GITHUB_TOKEN $(KRES_IMAGE)

$(ARTIFACTS):  ## Creates artifacts directory.
	@mkdir -p $(ARTIFACTS)

.PHONY: $(ARTIFACTS)/image-signer
$(ARTIFACTS)/image-signer: $(ARTIFACTS)
	@curl -sSL https://github.com/siderolabs/go-tools/releases/download/$(IMAGE_SIGNER_RELEASE)/image-signer-$(OPERATING_SYSTEM)-$(GOARCH) -o $(ARTIFACTS)/image-signer
	@chmod +x $(ARTIFACTS)/image-signer

.PHONY: sign-images
sign-images: $(ARTIFACTS)/image-signer
	@$(ARTIFACTS)/image-signer sign --timeout=15m  $(FAT_IMAGE)@$$(crane digest $(FAT_IMAGE)) $(SLIM_IMAGE)@$$(crane digest $(SLIM_IMAGE))
