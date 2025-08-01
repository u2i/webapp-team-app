#!/usr/bin/env bash
# This script uses the compliance-cli tool for deployments
# It will automatically download and run the latest version

set -e

# Download and run the compliance-cli
# Using specific version to ensure we get v0.3.2 with APP_NAME parameter support
export COMPLIANCE_CLI_VERSION=v0.3.2
curl -sL https://raw.githubusercontent.com/u2i/compliance-cli/main/scripts/deploy-wrapper.sh | bash -s -- "$@"