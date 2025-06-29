#!/bin/bash
# Test preview deployment (simulates GitHub Action)
# Usage: ./test-preview-deployment.sh <pr-number>

set -euo pipefail

PR_NUMBER="${1:-999}"
PREVIEW_NAME="pr-${PR_NUMBER}"
DOMAIN="${PREVIEW_NAME}.webapp.u2i.dev"
NAMESPACE="webapp-preview-${PREVIEW_NAME}"
RELEASE_NAME="${PREVIEW_NAME}-$(date +%Y%m%d%H%M%S)"

echo "🚀 Testing preview deployment for PR #${PR_NUMBER}"
echo "Preview URL: https://${DOMAIN}"
echo ""

# Deploy using the same command as GitHub Action
gcloud deploy releases create "${RELEASE_NAME}" \
  --delivery-pipeline=webapp-preview-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod \
  --skaffold-file=skaffold-gateway-preview.yaml \
  --to-target=preview-gke-cert \
  --deploy-parameters="DOMAIN=${DOMAIN},PREVIEW_NAME=${PREVIEW_NAME},NAMESPACE=${NAMESPACE},CERT_NAME=webapp-preview-cert-${PREVIEW_NAME},CERT_ENTRY_NAME=webapp-preview-entry-${PREVIEW_NAME},ROUTE_NAME=webapp-preview-route-${PREVIEW_NAME},CERT_DESCRIPTION=Certificate for ${DOMAIN},API_URL=https://api-${DOMAIN}"

echo ""
echo "✅ Preview deployment initiated!"
echo ""
echo "To check status:"
echo "  gcloud deploy rollouts list --release=${RELEASE_NAME} --delivery-pipeline=webapp-preview-pipeline --region=europe-west1"
echo ""
echo "To check pods:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "To cleanup when done:"
echo "  ./scripts/cleanup-preview-pr.sh ${PR_NUMBER}"