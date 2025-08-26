# Makefile for webapp-team-app

# Use dockerized compliance-cli for consistency with CI/CD
COMPLIANCE_CLI_IMAGE = us-docker.pkg.dev/u2i-bootstrap/gcr.io/compliance-cli-builder:latest

# Check if running in CI or locally
ifdef BUILD_ID
  # In Cloud Build, use the image directly (compliance-cli is in PATH)
  COMPLIANCE_CLI = compliance-cli
else
  # Locally, use Docker to run the compliance-cli image
  COMPLIANCE_CLI = docker run --rm \
    -v $(PWD):/workspace \
    -w /workspace \
    -v $(HOME)/.config/gcloud:/root/.config/gcloud \
    -e PROJECT_ID=$(PROJECT_ID) \
    -e REGION=$(REGION) \
    $(COMPLIANCE_CLI_IMAGE) compliance-cli
endif

# Default values for local development
PROJECT_ID ?= u2i-tenant-webapp-nonprod
REGION ?= europe-west1

.PHONY: generate-pipelines
generate-pipelines:
	@echo "Generating Cloud Deploy pipeline configurations..."
	@$(COMPLIANCE_CLI) generate pipeline --env dev > deploy/clouddeploy/dev.yml
	@$(COMPLIANCE_CLI) generate pipeline --env preview > deploy/clouddeploy/preview.yml
	@$(COMPLIANCE_CLI) generate pipeline --env qa-prod > deploy/clouddeploy/qa-prod.yml
	@echo "✅ Pipeline configurations generated"

.PHONY: validate-pipelines
validate-pipelines:
	@echo "Validating Cloud Deploy pipeline configurations..."
	@$(COMPLIANCE_CLI) validate pipelines --pipeline-dir deploy/clouddeploy

.PHONY: pull-cli-image
pull-cli-image:
	@echo "Pulling compliance-cli Docker image..."
	@docker pull $(COMPLIANCE_CLI_IMAGE)
	@echo "✅ Image pulled successfully"

.PHONY: clean
clean:
	@rm -rf bin

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  generate-pipelines  - Generate Cloud Deploy pipeline YAML files from templates"
	@echo "  validate-pipelines  - Validate that pipeline YAML files match generated content"
	@echo "  pull-cli-image     - Pull the latest compliance-cli Docker image"
	@echo "  clean              - Remove downloaded binaries"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  PROJECT_ID         - GCP project ID (default: u2i-tenant-webapp-nonprod)"
	@echo "  REGION            - GCP region (default: europe-west1)"