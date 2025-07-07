#!/usr/bin/env bash
set -e

echo "=== Starting deploy-preview.sh ==="

# Ensure we have a valid PR identifier
if [ ! -f /workspace/pr_number.txt ]; then
  echo "ERROR: pr_number.txt not found!"
  echo "$SHORT_SHA" > /workspace/pr_number.txt
fi

PR_IDENTIFIER=$(cat /workspace/pr_number.txt)
if [ -z "$PR_IDENTIFIER" ]; then
  echo "ERROR: PR identifier is empty!"
  PR_IDENTIFIER="$SHORT_SHA"
  echo "$SHORT_SHA" > /workspace/pr_number.txt
fi

echo "Using PR identifier: $PR_IDENTIFIER"

# Build all the parameters
PREVIEW_NAME="pr${PR_IDENTIFIER}"
DOMAIN="${PREVIEW_NAME}.webapp.u2i.dev"
NAMESPACE="webapp-preview-${PREVIEW_NAME}"
CERT_NAME="webapp-preview-cert-${PREVIEW_NAME}"
CERT_ENTRY_NAME="webapp-preview-entry-${PREVIEW_NAME}"
ROUTE_NAME="webapp-preview-route-${PREVIEW_NAME}"

# Create the Cloud Deploy release
gcloud deploy releases create "preview-${PREVIEW_NAME}-${SHORT_SHA}" \
  --delivery-pipeline=webapp-preview-pipeline \
  --region=${_REGION} \
  --project=${_PROJECT_ID} \
  --images="${_REGION}-docker.pkg.dev/${_PROJECT_ID}/webapp-images/webapp=${_REGION}-docker.pkg.dev/${_PROJECT_ID}/webapp-images/webapp:preview-${COMMIT_SHA}" \
  --to-target=preview-gke \
  --skaffold-file=skaffold-preview-deploy.yaml \
  --deploy-parameters="NAMESPACE=${NAMESPACE},ENV=preview,API_URL=https://api-${DOMAIN},STAGE=preview,BOUNDARY=nonprod,TIER=preview,NAME_PREFIX=preview-,DOMAIN=${DOMAIN},ROUTE_NAME=${ROUTE_NAME},SERVICE_NAME=webapp-service,CERT_NAME=${CERT_NAME},CERT_ENTRY_NAME=${CERT_ENTRY_NAME},CERT_DESCRIPTION=Certificate for ${DOMAIN}" \
  --impersonate-service-account=cloud-deploy-sa@${_PROJECT_ID}.iam.gserviceaccount.com

echo "✅ Preview deployment initiated: https://${DOMAIN}"