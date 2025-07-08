#!/usr/bin/env bash
set -e

echo "=== Starting deploy-qa.sh ==="

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

# QA deployment parameters
NAMESPACE="webapp-qa"
ENV="qa"
API_URL="https://api-qa.webapp.u2i.dev"
STAGE="qa"
BOUNDARY="nonprod"
TIER="standard"
NAME_PREFIX="qa-"
DOMAIN="qa.webapp.u2i.dev"
ROUTE_NAME="webapp-qa-route"
SERVICE_NAME="qa-webapp-service"
CERT_NAME="webapp-qa-cert"
CERT_ENTRY_NAME="webapp-qa-entry"
CERT_DESCRIPTION="Certificate for qa.webapp.u2i.dev"

# Create Cloud Deploy release for QA
echo "Creating Cloud Deploy release for QA environment..."
# The Cloud Build trigger already runs as webapp-ci which has the necessary permissions
gcloud deploy releases create "qa-${SHORT_SHA}" \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --images="${REGION}-docker.pkg.dev/${PROJECT_ID}/webapp-images/webapp=${REGION}-docker.pkg.dev/${PROJECT_ID}/webapp-images/webapp:qa-${COMMIT_SHA}" \
  --to-target=qa-gke \
  --skaffold-file=skaffold-qa-deploy.yaml \
  --deploy-parameters="NAMESPACE=${NAMESPACE},ENV=${ENV},API_URL=${API_URL},STAGE=${STAGE},BOUNDARY=${BOUNDARY},TIER=${TIER},NAME_PREFIX=${NAME_PREFIX},DOMAIN=${DOMAIN},ROUTE_NAME=${ROUTE_NAME},SERVICE_NAME=${SERVICE_NAME},CERT_NAME=${CERT_NAME},CERT_ENTRY_NAME=${CERT_ENTRY_NAME},CERT_DESCRIPTION=${CERT_DESCRIPTION}"

echo "✅ QA deployment initiated: https://${DOMAIN}"
echo "ℹ️  After QA validation, the release can be promoted to production with approval"