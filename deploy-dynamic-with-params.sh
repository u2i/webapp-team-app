#!/bin/bash
# Deploy a dynamic environment using Cloud Deploy parameters

set -e

# Default values
DEFAULT_PROFILE="dev-resources"
DEFAULT_PIPELINE="webapp-delivery-pipeline"
DEFAULT_REGION="europe-west1"

# Parse arguments
ENVIRONMENT=$1
PROFILE=${2:-$DEFAULT_PROFILE}
PROJECT=${3:-"u2i-tenant-webapp"}

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment> [profile] [project]"
    echo ""
    echo "Examples:"
    echo "  $0 foo                                      # Deploy foo with dev resources to nonprod"
    echo "  $0 demo dev-resources                       # Deploy demo with dev resources to nonprod"
    echo "  $0 preview prod-resources u2i-tenant-webapp-prod  # Deploy preview with prod resources to prod"
    echo ""
    echo "Available profiles: dev-resources, prod-resources"
    echo "Available projects: u2i-tenant-webapp (nonprod), u2i-tenant-webapp-prod"
    exit 1
fi

# Determine domain and settings based on project
PROJECT_ID=$PROJECT
if [ "$PROJECT_ID" == "u2i-tenant-webapp-prod" ]; then
    DOMAIN="u2i.com"
    ALLOW_HTTP="false"
    TARGET="prod-webapp-cluster"
else
    DOMAIN="u2i.dev"
    ALLOW_HTTP="true"
    TARGET="non-prod-webapp-cluster"
fi

# Build parameter values
IP_NAME="webapp-${ENVIRONMENT}-ip"
CERT_NAME="webapp-cert-${ENVIRONMENT}"
INGRESS_NAME="webapp-ingress-${ENVIRONMENT}"
FULL_DOMAIN="${ENVIRONMENT}.webapp.${DOMAIN}"
IP_DESCRIPTION="Static IP for webapp ${ENVIRONMENT} environment"

echo "🚀 Deploying dynamic environment with Cloud Deploy parameters"
echo "==========================================================="
echo "Environment: $ENVIRONMENT"
echo "Profile: $PROFILE"
echo "Project: $PROJECT_ID"
echo "Target: $TARGET"
echo "Domain: $FULL_DOMAIN"
echo ""
echo "Parameters:"
echo "  IP_NAME: $IP_NAME"
echo "  CERT_NAME: $CERT_NAME"
echo "  INGRESS_NAME: $INGRESS_NAME"
echo "  PROJECT_ID: $PROJECT_ID"
echo "  ALLOW_HTTP: $ALLOW_HTTP"
echo ""

# Create the Cloud Deploy release with parameters
RELEASE_NAME="${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

echo "🚢 Creating Cloud Deploy release: $RELEASE_NAME"
gcloud deploy releases create $RELEASE_NAME \
    --delivery-pipeline=$DEFAULT_PIPELINE \
    --region=$DEFAULT_REGION \
    --skaffold-file=skaffold-dynamic.yaml \
    --to-target=$TARGET \
    --labels="environment=$ENVIRONMENT,profile=$PROFILE" \
    --deploy-parameters="IP_NAME=$IP_NAME,CERT_NAME=$CERT_NAME,INGRESS_NAME=$INGRESS_NAME,FULL_DOMAIN=$FULL_DOMAIN,PROJECT_ID=$PROJECT_ID,ALLOW_HTTP=$ALLOW_HTTP,IP_DESCRIPTION=$IP_DESCRIPTION,ENVIRONMENT=$ENVIRONMENT" \
    --project=$PROJECT_ID

echo ""
echo "✅ Deployment initiated!"
echo ""
echo "📊 Monitor deployment:"
echo "  gcloud deploy rollouts list --release=$RELEASE_NAME --region=$DEFAULT_REGION --delivery-pipeline=$DEFAULT_PIPELINE"
echo ""
echo "🌐 Your environment will be available at:"
echo "  https://$FULL_DOMAIN"
echo ""
echo "🗑️  To delete this environment later:"
echo "  kubectl delete ingress,managedcertificate,computeaddress -n webapp-team -l environment=$ENVIRONMENT"