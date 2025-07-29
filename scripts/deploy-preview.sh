#!/usr/bin/env bash
set -e

echo "=== Starting deploy-preview.sh ==="

# Check required Cloud Build variables
MISSING_VARS=""
if [ -z "$COMMIT_SHA" ]; then
  MISSING_VARS="${MISSING_VARS}COMMIT_SHA "
fi
if [ -z "$SHORT_SHA" ]; then
  MISSING_VARS="${MISSING_VARS}SHORT_SHA "
fi

if [ -n "$MISSING_VARS" ]; then
  echo "ERROR: Required Cloud Build variables not set: $MISSING_VARS"
  exit 1
fi

# Check required environment variables
MISSING_ENV=""
if [ -z "$PROJECT_ID" ]; then
  MISSING_ENV="${MISSING_ENV}PROJECT_ID "
fi
if [ -z "$REGION" ]; then
  MISSING_ENV="${MISSING_ENV}REGION "
fi

if [ -n "$MISSING_ENV" ]; then
  echo "ERROR: Required environment variables not set: $MISSING_ENV"
  exit 1
fi

# Get PR identifier
if [ ! -f /workspace/pr_number.txt ]; then
  echo "ERROR: pr_number.txt not found!"
  exit 1
fi

PR_IDENTIFIER=$(cat /workspace/pr_number.txt)
if [ -z "$PR_IDENTIFIER" ]; then
  echo "ERROR: PR identifier is empty!"
  exit 1
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
echo "Creating Cloud Deploy release..."
gcloud deploy releases create "preview-${PREVIEW_NAME}-${SHORT_SHA}" \
  --delivery-pipeline=webapp-preview-pipeline \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --images="${REGION}-docker.pkg.dev/${PROJECT_ID}/webapp-images/webapp=${REGION}-docker.pkg.dev/${PROJECT_ID}/webapp-images/webapp:preview-${COMMIT_SHA}" \
  --to-target=preview-gke \
  --skaffold-file=skaffold-preview.yaml \
  --deploy-parameters="NAMESPACE=${NAMESPACE},ENV=preview,API_URL=https://api-${DOMAIN},STAGE=preview,BOUNDARY=nonprod,TIER=preview,NAME_PREFIX=preview-,DOMAIN=${DOMAIN},ROUTE_NAME=${ROUTE_NAME},SERVICE_NAME=preview-webapp-service,CERT_NAME=${CERT_NAME},CERT_ENTRY_NAME=${CERT_ENTRY_NAME},CERT_DESCRIPTION=Certificate for ${DOMAIN},PROJECT_ID=${PROJECT_ID}" \
  --impersonate-service-account=cloud-deploy-sa@${PROJECT_ID}.iam.gserviceaccount.com

echo "✅ Preview deployment initiated: https://${DOMAIN}"