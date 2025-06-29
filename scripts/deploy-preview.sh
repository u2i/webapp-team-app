#!/bin/bash
# Deploy preview with custom domain
# Usage: ./deploy-preview.sh <preview-name> [domain]
# For PRs: ./deploy-preview.sh pr-123

set -euo pipefail

PREVIEW_NAME="${1:-preview}"
# Support pr-NNN naming convention
if [[ "$PREVIEW_NAME" =~ ^pr-[0-9]+$ ]]; then
    DOMAIN="${PREVIEW_NAME}.webapp.u2i.dev"
else
    DOMAIN="${2:-${PREVIEW_NAME}.webapp.u2i.dev}"
fi
NAMESPACE="webapp-preview-${PREVIEW_NAME}"

echo "Deploying preview: ${PREVIEW_NAME}"
echo "Domain: ${DOMAIN}"
echo "Namespace: ${NAMESPACE}"

# Build and create release with deploy parameters
gcloud deploy releases create "preview-${PREVIEW_NAME}-$(date +%Y%m%d%H%M%S)" \
	--delivery-pipeline=webapp-preview-pipeline \
	--region=europe-west1 \
	--project=u2i-tenant-webapp-nonprod \
	--skaffold-file=skaffold-gateway-preview.yaml \
	--deploy-parameters="DOMAIN=${DOMAIN},PREVIEW_NAME=${PREVIEW_NAME},NAMESPACE=${NAMESPACE},CERT_NAME=webapp-preview-cert-${PREVIEW_NAME},CERT_ENTRY_NAME=webapp-preview-entry-${PREVIEW_NAME},ROUTE_NAME=webapp-preview-route-${PREVIEW_NAME},CERT_DESCRIPTION=Certificate for ${DOMAIN},API_URL=https://api-${DOMAIN}" \
	--to-target=preview-gke-cert

echo "Preview deployment initiated for ${DOMAIN}"
echo "Note: DNS records will be created automatically by External DNS"
