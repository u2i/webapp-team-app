#!/bin/bash
# Deploy using boundary-stage-tier naming scheme
# Pattern: <boundary>-<stage>-<tier>

set -e

# Default values
DEFAULT_TIER="standard"
DEFAULT_MODE="production"
DEFAULT_PIPELINE="webapp-delivery-pipeline"
DEFAULT_REGION="europe-west1"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
    echo -e "${BLUE}Usage:${NC} $0 <boundary> <stage> [tier] [mode]"
    echo ""
    echo -e "${YELLOW}Arguments:${NC}"
    echo "  boundary  : Security boundary (prod, nonprod)"
    echo "  stage     : Deployment stage (dev, qa, staging, preprod, prod, preview-*)"
    echo "  tier      : Resource tier (standard, perf, ci, preview) - default: standard"
    echo "  mode      : Runtime mode (production, development, test) - default: production"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 nonprod dev                     # Deploy dev environment with standard resources"
    echo "  $0 nonprod staging perf            # Deploy staging with performance tier"
    echo "  $0 nonprod preview-123 preview     # Deploy PR preview with minimal resources"
    echo "  $0 prod preprod standard           # Deploy pre-production environment"
    echo "  $0 prod prod perf production       # Deploy production with perf tier"
    echo ""
    echo -e "${YELLOW}Naming pattern:${NC} <boundary>-<stage>-<tier>"
    echo "  Examples: nonprod-dev-standard, prod-staging-perf, nonprod-preview-42-preview"
    exit 1
}

# Parse arguments
BOUNDARY=$1
STAGE=$2
TIER=${3:-$DEFAULT_TIER}
MODE=${4:-$DEFAULT_MODE}

# Validate required arguments
if [ -z "$BOUNDARY" ] || [ -z "$STAGE" ]; then
    usage
fi

# Validate boundary
if [[ ! "$BOUNDARY" =~ ^(prod|nonprod)$ ]]; then
    echo -e "${RED}Error:${NC} Invalid boundary '$BOUNDARY'. Must be 'prod' or 'nonprod'."
    exit 1
fi

# Validate stage
if [[ ! "$STAGE" =~ ^(dev|qa|staging|preprod|prod|preview-.+)$ ]]; then
    echo -e "${RED}Error:${NC} Invalid stage '$STAGE'. Must be one of: dev, qa, staging, preprod, prod, preview-*"
    exit 1
fi

# Validate tier
if [[ ! "$TIER" =~ ^(standard|perf|ci|preview)$ ]]; then
    echo -e "${RED}Error:${NC} Invalid tier '$TIER'. Must be one of: standard, perf, ci, preview"
    exit 1
fi

# Validate mode
if [[ ! "$MODE" =~ ^(production|development|test)$ ]]; then
    echo -e "${RED}Error:${NC} Invalid mode '$MODE'. Must be one of: production, development, test"
    exit 1
fi

# Enforce boundary-stage consistency
if [ "$BOUNDARY" == "prod" ] && [[ "$STAGE" =~ ^(dev|qa|preview-.+)$ ]]; then
    echo -e "${RED}Error:${NC} Stage '$STAGE' is not allowed in 'prod' boundary"
    echo "Prod boundary only allows: staging, preprod, prod"
    exit 1
fi

if [ "$BOUNDARY" == "nonprod" ] && [[ "$STAGE" =~ ^(preprod|prod)$ ]]; then
    echo -e "${RED}Error:${NC} Stage '$STAGE' is not allowed in 'nonprod' boundary"
    echo "Nonprod boundary only allows: dev, qa, staging, preview-*"
    exit 1
fi

# Determine project and domain based on boundary
if [ "$BOUNDARY" == "prod" ]; then
    PROJECT_ID="u2i-tenant-webapp-prod"
    DOMAIN="u2i.com"
    ALLOW_HTTP="false"
else
    PROJECT_ID="u2i-tenant-webapp"
    DOMAIN="u2i.dev"
    ALLOW_HTTP="true"
fi

# Determine target cluster
TARGET="${BOUNDARY}-webapp-cluster"
if [ "$TARGET" == "nonprod-webapp-cluster" ]; then
    # Legacy naming fix
    TARGET="non-prod-webapp-cluster"
fi

# Build namespace and resource names
NAMESPACE="${BOUNDARY}-${STAGE}-${TIER}"
IP_NAME="webapp-${STAGE}-ip"
CERT_NAME="webapp-cert-${STAGE}"
INGRESS_NAME="webapp-ingress-${STAGE}"
FULL_DOMAIN="${STAGE}.webapp.${DOMAIN}"
IP_DESCRIPTION="Static IP for webapp ${STAGE} (${NAMESPACE})"

# Map tier to Skaffold profile
case $TIER in
    standard)
        SKAFFOLD_PROFILE="tier-standard"
        ;;
    perf)
        SKAFFOLD_PROFILE="tier-perf"
        ;;
    ci)
        SKAFFOLD_PROFILE="tier-ci"
        ;;
    preview)
        SKAFFOLD_PROFILE="tier-preview"
        ;;
esac

# Use non-prod profile for now (required by delivery pipeline)
# The tier-based profile is already included in the skaffold config
SKAFFOLD_PROFILE="non-prod"

echo -e "${BLUE}🚀 Deploying with boundary-stage-tier naming${NC}"
echo "=============================================="
echo -e "${GREEN}Namespace:${NC} $NAMESPACE"
echo -e "${GREEN}Pattern:${NC} boundary=$BOUNDARY, stage=$STAGE, tier=$TIER, mode=$MODE"
echo ""
echo -e "${YELLOW}Infrastructure:${NC}"
echo "  Project: $PROJECT_ID"
echo "  Target: $TARGET"
echo "  Domain: $FULL_DOMAIN"
echo ""
echo -e "${YELLOW}Resources:${NC}"
echo "  IP: $IP_NAME"
echo "  Certificate: $CERT_NAME"
echo "  Ingress: $INGRESS_NAME"
echo "  Profile: $SKAFFOLD_PROFILE"
echo ""
echo -e "${YELLOW}Labels:${NC}"
echo "  boundary: $BOUNDARY"
echo "  stage: $STAGE"
echo "  tier: $TIER"
echo "  mode: $MODE"
echo ""

# Create the Cloud Deploy release with parameters
RELEASE_NAME="${NAMESPACE}-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}🚢 Creating Cloud Deploy release:${NC} $RELEASE_NAME"
gcloud deploy releases create $RELEASE_NAME \
    --delivery-pipeline=$DEFAULT_PIPELINE \
    --region=$DEFAULT_REGION \
    --skaffold-file=skaffold-dynamic.yaml \
    --to-target=$TARGET \
    --labels="boundary=$BOUNDARY,stage=$STAGE,tier=$TIER,mode=$MODE,namespace=$NAMESPACE" \
    --deploy-parameters="IP_NAME=$IP_NAME,CERT_NAME=$CERT_NAME,INGRESS_NAME=$INGRESS_NAME,FULL_DOMAIN=$FULL_DOMAIN,PROJECT_ID=$PROJECT_ID,ALLOW_HTTP=$ALLOW_HTTP,IP_DESCRIPTION=$IP_DESCRIPTION,ENVIRONMENT=$STAGE,NAMESPACE=$NAMESPACE,BOUNDARY=$BOUNDARY,STAGE=$STAGE,TIER=$TIER,MODE=$MODE" \
    --project=$PROJECT_ID

echo ""
echo -e "${GREEN}✅ Deployment initiated!${NC}"
echo ""
echo -e "${YELLOW}📊 Monitor deployment:${NC}"
echo "  gcloud deploy rollouts list --release=$RELEASE_NAME --region=$DEFAULT_REGION --delivery-pipeline=$DEFAULT_PIPELINE"
echo ""
echo -e "${YELLOW}🌐 Your environment will be available at:${NC}"
echo "  https://$FULL_DOMAIN"
echo ""
echo -e "${YELLOW}🏷️  Resources are labeled with:${NC}"
echo "  boundary=$BOUNDARY, stage=$STAGE, tier=$TIER, mode=$MODE"
echo ""
echo -e "${YELLOW}🗑️  To delete this environment later:${NC}"
echo "  kubectl delete ingress,managedcertificate,computeaddress -n $NAMESPACE -l stage=$STAGE"