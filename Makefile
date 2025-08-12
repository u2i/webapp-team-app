# Makefile for webapp-team-app

# Use the compliance-cli wrapper in root
COMPLIANCE_CLI = ./compliance-cli

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