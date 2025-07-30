#!/usr/bin/env bash
set -e

# Unified deployment script for all environments
# Usage: ./deploy.sh <environment> [options]

show_usage() {
  cat << EOF
Usage: $0 <environment> [options]

Environments:
  dev         Deploy to development environment
  preview     Deploy preview for PR (requires --pr-number)
  qa          Deploy to QA environment
  prod        Promote from QA to production

Options:
  --pr-number <number>    PR number for preview deployments
  --release <name>        Release name (default: auto-generated)
  --promote               For prod: promote existing QA release
  --help                  Show this help message

Examples:
  $0 dev
  $0 preview --pr-number 123
  $0 qa
  $0 prod --promote --release qa-abc123

Environment Variables Required:
  PROJECT_ID    GCP project ID
  REGION        GCP region
  COMMIT_SHA    Git commit SHA
  SHORT_SHA     Short git commit SHA
EOF
}

# Parse command line arguments
ENVIRONMENT=$1
shift

# Initialize variables
PR_NUMBER=""
RELEASE_NAME=""
PROMOTE_MODE=false

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    --pr-number)
      PR_NUMBER="$2"
      shift 2
      ;;
    --release)
      RELEASE_NAME="$2"
      shift 2
      ;;
    --promote)
      PROMOTE_MODE=true
      shift
      ;;
    --help)
      show_usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
  echo "ERROR: Environment not specified"
  show_usage
  exit 1
fi

# Check required environment variables
check_required_vars() {
  local missing=""
  for var in "$@"; do
    if [[ -z "${!var}" ]]; then
      missing="$missing $var"
    fi
  done
  if [[ -n "$missing" ]]; then
    echo "ERROR: Required environment variables not set:$missing"
    exit 1
  fi
}

# Common required variables
check_required_vars PROJECT_ID REGION

# Set common variables
case "$ENVIRONMENT" in
  dev)
    PIPELINE="webapp-dev-pipeline"
    TARGET="dev-gke"
    SKAFFOLD_FILE="skaffold-dev.yaml"
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
    IMAGE_TAG="dev-${COMMIT_SHA}"
    RELEASE_NAME="${RELEASE_NAME:-dev-${SHORT_SHA}}"
    ;;
    
  preview)
    if [[ -z "$PR_NUMBER" ]]; then
      # Try to read from file if not provided
      if [[ -f /workspace/pr_number.txt ]]; then
        PR_NUMBER=$(cat /workspace/pr_number.txt)
      else
        echo "ERROR: --pr-number required for preview deployments"
        exit 1
      fi
    fi
    
    PIPELINE="webapp-preview-pipeline"
    TARGET="preview-gke"
    SKAFFOLD_FILE="skaffold-preview.yaml"
    PREVIEW_NAME="pr${PR_NUMBER}"
    NAMESPACE="webapp-preview-${PREVIEW_NAME}"
    ENV="preview"
    API_URL="https://api-${PREVIEW_NAME}.webapp.u2i.dev"
    STAGE="preview"
    BOUNDARY="nonprod"
    TIER="preview"
    NAME_PREFIX="preview-"
    DOMAIN="${PREVIEW_NAME}.webapp.u2i.dev"
    ROUTE_NAME="webapp-preview-route-${PREVIEW_NAME}"
    SERVICE_NAME="preview-webapp-service"
    CERT_NAME="webapp-preview-cert-${PREVIEW_NAME}"
    CERT_ENTRY_NAME="webapp-preview-entry-${PREVIEW_NAME}"
    CERT_DESCRIPTION="Certificate for ${DOMAIN}"
    IMAGE_TAG="preview-${COMMIT_SHA}"
    RELEASE_NAME="${RELEASE_NAME:-preview-${PREVIEW_NAME}-${SHORT_SHA}}"
    ;;
    
  qa)
    PIPELINE="webapp-qa-prod-pipeline"
    TARGET="qa-gke"
    SKAFFOLD_FILE="skaffold-qa-prod.yaml"
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
    IMAGE_TAG="qa-${COMMIT_SHA}"
    RELEASE_NAME="${RELEASE_NAME:-qa-${SHORT_SHA}}"
    ;;
    
  prod)
    if [[ "$PROMOTE_MODE" == "true" ]]; then
      if [[ -z "$RELEASE_NAME" ]]; then
        echo "ERROR: --release required for production promotion"
        exit 1
      fi
      echo "Promoting $RELEASE_NAME to production..."
      gcloud deploy releases promote \
        --release="$RELEASE_NAME" \
        --delivery-pipeline=webapp-qa-prod-pipeline \
        --region="${REGION}" \
        --project="${PROJECT_ID}" \
        --to-target=prod-gke \
        --quiet
      
      echo "✅ Production promotion initiated"
      echo "Note: Manual approval required in Cloud Deploy console"
      exit 0
    else
      echo "ERROR: Production deployments must use --promote flag"
      echo "First deploy to QA, then promote to production"
      exit 1
    fi
    ;;
    
  *)
    echo "ERROR: Unknown environment: $ENVIRONMENT"
    show_usage
    exit 1
    ;;
esac

# For non-promotion deployments, check additional required vars
check_required_vars COMMIT_SHA SHORT_SHA

# Build image reference
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/webapp-images/webapp"
IMAGE_WITH_TAG="${IMAGE}:${IMAGE_TAG}"

# Create deployment parameters string
# Quote CERT_DESCRIPTION to handle spaces
DEPLOY_PARAMS="NAMESPACE=${NAMESPACE},ENV=${ENV},API_URL=${API_URL},STAGE=${STAGE},BOUNDARY=${BOUNDARY},TIER=${TIER},NAME_PREFIX=${NAME_PREFIX},DOMAIN=${DOMAIN},ROUTE_NAME=${ROUTE_NAME},SERVICE_NAME=${SERVICE_NAME},CERT_NAME=${CERT_NAME},CERT_ENTRY_NAME=${CERT_ENTRY_NAME},CERT_DESCRIPTION=\"${CERT_DESCRIPTION}\",PROJECT_ID=${PROJECT_ID}"

# Create Cloud Deploy release
echo "Creating Cloud Deploy release for $ENVIRONMENT environment..."
echo "  Pipeline: $PIPELINE"
echo "  Target: $TARGET"
echo "  Release: $RELEASE_NAME"
echo "  Image: $IMAGE_WITH_TAG"

# Check if we need to impersonate and pass parameters
# Dev and Preview: Need impersonation and CLI parameters
# QA and Prod: No impersonation, parameters already in YAML
if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "preview" ]]; then
  IMPERSONATE_FLAG="--impersonate-service-account=cloud-deploy-sa@${PROJECT_ID}.iam.gserviceaccount.com"
  PARAMS_FLAG="--deploy-parameters=$DEPLOY_PARAMS"
else
  # QA/Prod have parameters in clouddeploy-qa-prod.yaml
  IMPERSONATE_FLAG=""
  PARAMS_FLAG=""
fi

gcloud deploy releases create "$RELEASE_NAME" \
  --delivery-pipeline="$PIPELINE" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --images="${IMAGE}=${IMAGE_WITH_TAG}" \
  --to-target="$TARGET" \
  --skaffold-file="$SKAFFOLD_FILE" \
  $PARAMS_FLAG \
  $IMPERSONATE_FLAG

echo "✅ $ENVIRONMENT deployment initiated: https://${DOMAIN}"