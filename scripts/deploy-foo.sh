#!/bin/bash
# Deploy foo environment using the existing pipeline

set -e

ENVIRONMENT="foo"
PROJECT_ID="u2i-tenant-webapp"
DOMAIN="u2i.dev"
ALLOW_HTTP="true"
TARGET="nonprod-webapp-cluster"
PIPELINE="webapp-delivery-pipeline"
REGION="europe-west1"

# Build parameter values
IP_NAME="webapp-${ENVIRONMENT}-ip"
CERT_NAME="webapp-cert-${ENVIRONMENT}"
FULL_DOMAIN="${ENVIRONMENT}.webapp.${DOMAIN}"
IP_DESCRIPTION="Static IP for webapp ${ENVIRONMENT} environment"

echo "🚀 Deploying ${ENVIRONMENT} environment"
echo "======================================="
echo "Project: $PROJECT_ID"
echo "Target: $TARGET"
echo "Domain: $FULL_DOMAIN"
echo ""

# Create the release
RELEASE_NAME="${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

echo "🚢 Creating Cloud Deploy release: $RELEASE_NAME"
gcloud deploy releases create $RELEASE_NAME \
    --delivery-pipeline=$PIPELINE \
    --region=$REGION \
    --skaffold-file=skaffold-dynamic.yaml \
    --to-target=$TARGET \
    --labels="environment=$ENVIRONMENT" \
    --deploy-parameters="IP_NAME=$IP_NAME,CERT_NAME=$CERT_NAME,FULL_DOMAIN=$FULL_DOMAIN,PROJECT_ID=$PROJECT_ID,ALLOW_HTTP=$ALLOW_HTTP,IP_DESCRIPTION=$IP_DESCRIPTION" \
    --project=$PROJECT_ID

echo ""
echo "✅ Deployment initiated!"