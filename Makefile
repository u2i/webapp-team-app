# Makefile for webapp-team-app

# Use dockerized compliance-cli for consistency with CI/CD
COMPLIANCE_CLI_IMAGE = gcr.io/u2i-bootstrap/compliance-cli-builder:latest

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
	@echo "Generating dev pipeline..."
	@$(COMPLIANCE_CLI) generate pipeline --env=dev > deploy/clouddeploy/dev.yml
	@echo "✅ Generated deploy/clouddeploy/dev.yml"
	@echo "Generating preview pipeline..."
	@$(COMPLIANCE_CLI) generate pipeline --env=preview > deploy/clouddeploy/preview.yml
	@echo "✅ Generated deploy/clouddeploy/preview.yml"
	@echo "Generating QA/Prod pipeline..."
	@$(COMPLIANCE_CLI) generate pipeline --env=qa-prod > deploy/clouddeploy/qa-prod.yml
	@echo "✅ Generated deploy/clouddeploy/qa-prod.yml"
	@echo ""
	@echo "Pipeline configurations generated successfully!"

.PHONY: validate-pipelines
validate-pipelines:
	@echo "Validating Cloud Deploy pipeline configurations..."
	@$(COMPLIANCE_CLI) validate pipelines || true
	@echo ""
	@echo "Checking deployed pipelines..."
	@echo "Checking dev pipeline..."
	@gcloud deploy delivery-pipelines describe webapp-dev-pipeline --region=$(REGION) --project=$(PROJECT_ID) --format="value(name)" > /dev/null 2>&1 && echo "✅ Dev pipeline deployed" || echo "❌ Dev pipeline not found"
	@echo "Checking preview pipeline..."
	@gcloud deploy delivery-pipelines describe webapp-preview-pipeline --region=$(REGION) --project=$(PROJECT_ID) --format="value(name)" > /dev/null 2>&1 && echo "✅ Preview pipeline deployed" || echo "❌ Preview pipeline not found"
	@echo "Checking QA/Prod pipeline..."
	@gcloud deploy delivery-pipelines describe webapp-qa-prod-pipeline --region=$(REGION) --project=$(PROJECT_ID) --format="value(name)" > /dev/null 2>&1 && echo "✅ QA/Prod pipeline deployed" || echo "❌ QA/Prod pipeline not found"

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
	@echo "  generate-pipelines  - Generate Cloud Deploy pipeline configurations from templates"
	@echo "  validate-pipelines  - Validate pipeline configs and check deployed pipelines"
	@echo "  pull-cli-image     - Pull the latest compliance-cli Docker image"
	@echo "  clean              - Remove downloaded binaries"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  PROJECT_ID         - GCP project ID (default: u2i-tenant-webapp-nonprod)"
	@echo "  REGION            - GCP region (default: europe-west1)"