#!/bin/bash
# Promote a release from QA to Production
# Usage: ./promote-to-prod.sh <release-name>

set -euo pipefail

RELEASE_NAME="${1:-}"
if [ -z "$RELEASE_NAME" ]; then
    echo "Usage: $0 <release-name>"
    echo "Example: $0 v1.2.3"
    exit 1
fi

echo "🚀 Promoting release ${RELEASE_NAME} to production..."
echo ""
echo "⚠️  WARNING: This will deploy to PRODUCTION!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Promotion cancelled."
    exit 1
fi

# Promote the release
gcloud deploy releases promote \
    --release="${RELEASE_NAME}" \
    --delivery-pipeline=webapp-qa-prod-pipeline \
    --region=europe-west1 \
    --project=u2i-tenant-webapp \
    --to-target=prod

echo ""
echo "✅ Production promotion initiated for ${RELEASE_NAME}"
echo "🔍 Check the Cloud Deploy console for approval and deployment status"