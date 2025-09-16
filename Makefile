# Makefile for webapp-team-app
# Uses the compliance-cli Docker image specified in .compliance-cli.yml

# Get the compliance-cli version from config
COMPLIANCE_CLI_VERSION := $(shell grep compliance_cli_version .compliance-cli.yml | cut -d: -f2 | tr -d ' ')
COMPLIANCE_CLI_IMAGE := gcr.io/u2i-bootstrap/compliance-cli:$(COMPLIANCE_CLI_VERSION)

# Docker run command with current directory mounted
DOCKER_RUN := docker run --rm -v $(PWD):/workspace -w /workspace $(COMPLIANCE_CLI_IMAGE) compliance-cli

# Default target shows help
.PHONY: help
help:
	@$(DOCKER_RUN) --help

# Generate all deployment configurations and components
.PHONY: generate
generate:
	@echo "🔧 Generating complete deployment structure with $(COMPLIANCE_CLI_VERSION)..."
	@$(DOCKER_RUN) generate deploy-structure
	@echo "✅ All deployment files and components generated!"

# Legacy pipeline-only generation (use 'make generate' instead)
.PHONY: pipelines
pipelines:
	@$(DOCKER_RUN) generate pipeline --all --write-dir=deploy/clouddeploy
	@$(DOCKER_RUN) validate pipelines  
	@$(DOCKER_RUN) apply pipelines

.PHONY: status
status:
	@$(DOCKER_RUN) status pipelines
	@$(DOCKER_RUN) status environments

.PHONY: dev
dev:
	@$(DOCKER_RUN) dev

.PHONY: qa
qa:
	@$(DOCKER_RUN) qa

.PHONY: prod
prod:
	@$(DOCKER_RUN) prod --release=$(RELEASE)

# All other targets just pass through to compliance-cli
%:
	@$(DOCKER_RUN) $@