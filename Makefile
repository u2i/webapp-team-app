# Makefile for webapp-team-app
# This is a convenience wrapper around bin/compliance-cli

# Default target shows help
.PHONY: help
help:
	@bin/compliance-cli --help

# Common operations
.PHONY: pipelines
pipelines:
	@bin/compliance-cli generate pipeline --all --write-dir=deploy/clouddeploy
	@bin/compliance-cli validate pipelines  
	@bin/compliance-cli apply pipelines

.PHONY: status
status:
	@bin/compliance-cli status pipelines
	@bin/compliance-cli status environments

.PHONY: dev
dev:
	@bin/compliance-cli dev

.PHONY: qa
qa:
	@bin/compliance-cli qa

.PHONY: prod
prod:
	@bin/compliance-cli prod --release=$(RELEASE)

# All other targets just pass through to compliance-cli
%:
	@bin/compliance-cli $@