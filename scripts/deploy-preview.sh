#!/bin/bash
# Deploy preview with custom domain
# Usage: ./deploy-preview.sh <preview-name> [domain]

set -euo pipefail

PREVIEW_NAME="${1:-preview}"
DOMAIN="${2:-${PREVIEW_NAME}.webapp.u2i.dev}"
NAMESPACE="webapp-preview-${PREVIEW_NAME}"

echo "Deploying preview: ${PREVIEW_NAME}"
echo "Domain: ${DOMAIN}"

# Build and create release with deploy parameters
gcloud deploy releases create "preview-${PREVIEW_NAME}-$(date +%Y%m%d%H%M%S)" \
  --delivery-pipeline=webapp-preview-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp \
  --skaffold-file=skaffold-gateway-preview.yaml \
  --deploy-parameters="DOMAIN=${DOMAIN},PREVIEW_NAME=${PREVIEW_NAME},CERT_NAME=webapp-preview-cert-${PREVIEW_NAME},CERT_NAME_WITH_PREFIX=preview-webapp-preview-cert-${PREVIEW_NAME},CERT_ENTRY_NAME=webapp-preview-entry-${PREVIEW_NAME},ROUTE_NAME=webapp-preview-route-${PREVIEW_NAME},CERT_DESCRIPTION=Certificate for ${DOMAIN},API_URL=https://api-${DOMAIN}" \
  --to-target=preview-gke

echo "Preview deployment initiated for ${DOMAIN}"
echo "Note: DNS records will be created automatically by External DNS"