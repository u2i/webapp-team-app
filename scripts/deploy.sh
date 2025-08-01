#!/usr/bin/env bash
# This script uses the compliance-cli tool for deployments
# It will automatically download and run the latest version

set -e

# Download and run the compliance-cli
# Using specific version to ensure we get v0.3.4 with QA deploy parameters support
export COMPLIANCE_CLI_VERSION=v0.3.4
curl -sL https://raw.githubusercontent.com/u2i/compliance-cli/main/scripts/deploy-wrapper.sh | bash -s -- "$@"