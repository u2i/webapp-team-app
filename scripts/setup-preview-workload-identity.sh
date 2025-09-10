#!/bin/bash

# Setup wildcard workload identity binding for preview environments
# This enables the JavaScript client Secret Manager approach to work in all preview namespaces

set -euo pipefail

# Configuration
PROJECT_ID="u2i-tenant-webapp-nonprod"
SERVICE_ACCOUNT="webapp-k8s@${PROJECT_ID}.iam.gserviceaccount.com"
PR_NUMBER="${1:-226}"  # Default to PR 226, allow override via argument
SPECIFIC_MEMBER="serviceAccount:${PROJECT_ID}.svc.id.goog[webapp-preview-pr${PR_NUMBER}/webapp]"

echo "🔐 Setting up workload identity binding for PR ${PR_NUMBER} preview environment..."
echo "Project: ${PROJECT_ID}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo "Specific Member: ${SPECIFIC_MEMBER}"
echo

# Check if binding already exists
echo "📋 Checking existing IAM policy..."
EXISTING_POLICY=$(gcloud iam service-accounts get-iam-policy "${SERVICE_ACCOUNT}" --project="${PROJECT_ID}" --format=json)

if echo "${EXISTING_POLICY}" | jq -r '.bindings[]? | select(.role=="roles/iam.workloadIdentityUser") | .members[]?' | grep -q "webapp-preview-pr${PR_NUMBER}"; then
    echo "✅ PR ${PR_NUMBER} workload identity binding already exists"
    echo "Current bindings for roles/iam.workloadIdentityUser:"
    echo "${EXISTING_POLICY}" | jq -r '.bindings[]? | select(.role=="roles/iam.workloadIdentityUser") | .members[]?' | grep "webapp-preview" || true
else
    echo "➕ Adding PR ${PR_NUMBER} workload identity binding..."
    
    gcloud iam service-accounts add-iam-policy-binding \
        "${SERVICE_ACCOUNT}" \
        --project="${PROJECT_ID}" \
        --role=roles/iam.workloadIdentityUser \
        --member="${SPECIFIC_MEMBER}" \
        --quiet
    
    echo "✅ PR ${PR_NUMBER} workload identity binding added successfully!"
fi

echo
echo "🧪 Testing the binding..."
echo "You can now test the Secret Manager POC JavaScript client approach in preview environments:"
echo
echo "  # Test in any preview environment"
echo "  curl https://preview-pr<NUMBER>.webapp.u2i.dev/poc/secrets/compare"
echo
echo "  # Test JavaScript client approach specifically"  
echo "  curl https://preview-pr<NUMBER>.webapp.u2i.dev/poc/secrets/client/webapp-demo-secret"
echo
echo "🎉 Setup complete! Both Secret Manager approaches should now work in preview environments."