.DEFAULT_GOAL := help

.PHONY: build test help

TARGET_IMAGE ?= quay.io/abn/rpmbuilder:fedora-latest

##@ Build

build: ## Build the rpmbuilder container image
	TARGET_IMAGE=$(TARGET_IMAGE) ./bin/build.sh

##@ Test

test: ## Run all tests in parallel
	TARGET_IMAGE=$(TARGET_IMAGE) bats --jobs 2 test/

##@ Utilities

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z0-9_/-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
