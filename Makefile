# Makefile for webapp-team-app

# Variables
COMPLIANCE_CLI_VERSION ?= v0.5.0
COMPLIANCE_CLI_URL = https://github.com/u2i/compliance-cli/releases/download/$(COMPLIANCE_CLI_VERSION)/compliance-cli-$(shell uname -s | tr '[:upper:]' '[:lower:]')-$(shell uname -m | sed 's/x86_64/amd64/').tar.gz
COMPLIANCE_CLI = ./bin/compliance-cli

# Ensure bin directory exists
$(COMPLIANCE_CLI):
	@mkdir -p bin
	@echo "Downloading compliance-cli $(COMPLIANCE_CLI_VERSION)..."
	@curl -sL $(COMPLIANCE_CLI_URL) | tar -xz -C bin
	@chmod +x $(COMPLIANCE_CLI)

.PHONY: generate-pipelines
generate-pipelines: $(COMPLIANCE_CLI)
	@echo "Generating Cloud Deploy pipeline configurations..."
	@$(COMPLIANCE_CLI) generate pipeline --env dev > deploy/clouddeploy/dev.yaml
	@$(COMPLIANCE_CLI) generate pipeline --env preview > deploy/clouddeploy/preview.yaml
	@$(COMPLIANCE_CLI) generate pipeline --env qa-prod > deploy/clouddeploy/qa-prod.yaml
	@echo "✅ Pipeline configurations generated"

.PHONY: validate-pipelines
validate-pipelines: $(COMPLIANCE_CLI)
	@echo "Validating Cloud Deploy pipeline configurations..."
	@$(COMPLIANCE_CLI) validate pipelines --pipeline-dir deploy/clouddeploy

.PHONY: clean
clean:
	@rm -rf bin

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  generate-pipelines  - Generate Cloud Deploy pipeline YAML files from templates"
	@echo "  validate-pipelines  - Validate that pipeline YAML files match generated content"
	@echo "  clean              - Remove downloaded binaries"
	@echo "  help               - Show this help message"