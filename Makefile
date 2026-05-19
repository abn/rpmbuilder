.DEFAULT_GOAL := help

.PHONY: build test help

CONTAINER_CLI  ?= $(shell command -v podman >/dev/null 2>&1 && echo podman || echo docker)
BASE_IMAGE     ?= fedora
EXTRA_PACKAGES ?=
TARGET_IMAGE   ?= quay.io/abn/rpmbuilder:fedora-latest

##@ Build

build: ## Build the rpmbuilder container image
	$(CONTAINER_CLI) build -f Containerfile \
	  --build-arg BASE_IMAGE=$(BASE_IMAGE) \
	  --build-arg EXTRA_PACKAGES=$(EXTRA_PACKAGES) \
	  -t $(TARGET_IMAGE) .

##@ Test

test: ## Run all tests in parallel
	CONTAINER_CLI=$(CONTAINER_CLI) TARGET_IMAGE=$(TARGET_IMAGE) \
	  bats --jobs 2 --print-output-on-failure test/

##@ Utilities

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z0-9_/-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
