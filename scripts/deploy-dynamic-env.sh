#!/bin/bash
# Deploy a dynamic environment without creating kustomization files

set -e

# Default values
DEFAULT_PROFILE="dev"
DEFAULT_ALLOW_HTTP="true"
DEFAULT_PIPELINE="webapp-delivery-pipeline"
DEFAULT_REGION="europe-west1"

# Parse arguments
ENVIRONMENT=$1
PROFILE=${2:-$DEFAULT_PROFILE}
TARGET=${3:-"nonprod-gke"}

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment> [profile] [target]"
    echo ""
    echo "Examples:"
    echo "  $0 foo                    # Deploy foo with dev profile to nonprod"
    echo "  $0 demo dev               # Deploy demo with dev profile to nonprod"
    echo "  $0 preview prod prod-gke  # Deploy preview with prod profile to prod"
    echo ""
    echo "Available profiles: dev, prod"
    echo "Available targets: nonprod-gke, prod-gke"
    exit 1
fi

# Determine project and domain based on target
if [ "$TARGET" == "prod-gke" ]; then
    PROJECT_ID="u2i-tenant-webapp-prod"
    DOMAIN="u2i.com"
    ALLOW_HTTP="false"
else
    PROJECT_ID="u2i-tenant-webapp"
    DOMAIN="u2i.dev"
    ALLOW_HTTP="true"
fi

echo "🚀 Deploying dynamic environment"
echo "================================"
echo "Environment: $ENVIRONMENT"
echo "Profile: $PROFILE"
echo "Target: $TARGET"
echo "Project: $PROJECT_ID"
echo "Domain: $ENVIRONMENT.webapp.$DOMAIN"
echo ""

# Export environment variables for kustomize
export ENVIRONMENT
export PROFILE
export PROJECT_ID
export DOMAIN
export ALLOW_HTTP

# First, render the manifests locally to verify
echo "📋 Rendering manifests..."
skaffold render \
    --profile=dynamic \
    --label="environment=$ENVIRONMENT" \
    --label="profile=$PROFILE" \
    > /tmp/webapp-$ENVIRONMENT-manifest.yaml

echo "✅ Manifests rendered to /tmp/webapp-$ENVIRONMENT-manifest.yaml"
echo ""

# Create the Cloud Deploy release
RELEASE_NAME="${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

echo "🚢 Creating Cloud Deploy release: $RELEASE_NAME"
gcloud deploy releases create $RELEASE_NAME \
    --delivery-pipeline=$DEFAULT_PIPELINE \
    --region=$DEFAULT_REGION \
    --skaffold-file=skaffold.yaml \
    --skaffold-version=skaffold/v4beta6 \
    --to-target=$TARGET \
    --labels="environment=$ENVIRONMENT,profile=$PROFILE" \
    --annotations="environment=$ENVIRONMENT,profile=$PROFILE,domain=$ENVIRONMENT.webapp.$DOMAIN"

echo ""
echo "✅ Deployment initiated!"
echo ""
echo "📊 Monitor deployment:"
echo "  gcloud deploy rollouts list --release=$RELEASE_NAME --region=$DEFAULT_REGION --delivery-pipeline=$DEFAULT_PIPELINE"
echo ""
echo "🌐 Your environment will be available at:"
echo "  https://$ENVIRONMENT.webapp.$DOMAIN"
echo ""
echo "🗑️  To delete this environment later:"
echo "  kubectl delete ingress,managedcertificate,computeaddress -n webapp-team -l environment=$ENVIRONMENT"