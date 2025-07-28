#!/usr/bin/env bash
set -e

echo "=== Starting deploy-dev.sh ==="

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

# Dev deployment parameters
NAMESPACE="webapp-dev"
ENV="dev"
API_URL="https://api-dev.webapp.u2i.dev"
STAGE="dev"
BOUNDARY="nonprod"
TIER="standard"
NAME_PREFIX="dev-"
DOMAIN="dev.webapp.u2i.dev"
ROUTE_NAME="webapp-dev-route"
SERVICE_NAME="dev-webapp-service"
CERT_NAME="webapp-dev-cert"
CERT_ENTRY_NAME="webapp-dev-entry"
CERT_DESCRIPTION="Certificate for dev.webapp.u2i.dev"

# Create Cloud Deploy release for dev
echo "Creating Cloud Deploy release for dev environment..."
gcloud deploy releases create "dev-${SHORT_SHA}" \
  --delivery-pipeline=webapp-dev-pipeline \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --images="${REGION}-docker.pkg.dev/${PROJECT_ID}/webapp-images/webapp=${REGION}-docker.pkg.dev/${PROJECT_ID}/webapp-images/webapp:dev-${COMMIT_SHA}" \
  --to-target=dev-gke \
  --skaffold-file=skaffold.yaml \
  --module=webapp-namespace,webapp-dev-app,webapp-dev-kcc \
  --deploy-parameters="NAMESPACE=${NAMESPACE},ENV=${ENV},API_URL=${API_URL},STAGE=${STAGE},BOUNDARY=${BOUNDARY},TIER=${TIER},NAME_PREFIX=${NAME_PREFIX},DOMAIN=${DOMAIN},ROUTE_NAME=${ROUTE_NAME},SERVICE_NAME=${SERVICE_NAME},CERT_NAME=${CERT_NAME},CERT_ENTRY_NAME=${CERT_ENTRY_NAME},CERT_DESCRIPTION=${CERT_DESCRIPTION}" \
  --impersonate-service-account=cloud-deploy-sa@${PROJECT_ID}.iam.gserviceaccount.com

echo "✅ Dev deployment initiated: https://${DOMAIN}"