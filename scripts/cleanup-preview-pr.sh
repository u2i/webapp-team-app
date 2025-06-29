#!/bin/bash
# Cleanup a specific PR preview environment
# Usage: ./cleanup-preview-pr.sh <pr-number>

set -euo pipefail

PR_NUMBER="${1:-}"
if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <pr-number>"
    echo "Example: $0 123"
    exit 1
fi

PREVIEW_NAME="pr-${PR_NUMBER}"
NAMESPACE="webapp-preview-${PREVIEW_NAME}"
PROJECT="u2i-tenant-webapp-nonprod"

echo "🧹 Cleaning up preview environment for PR #${PR_NUMBER}"
echo ""

# Check if namespace exists
if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
    echo "Found namespace: ${NAMESPACE}"
else
    echo "Namespace ${NAMESPACE} not found"
fi

# Check for certificate resources
CERT_NAME="webapp-preview-cert-${PREVIEW_NAME}"
ENTRY_NAME="webapp-preview-entry-${PREVIEW_NAME}"

echo ""
echo "Resources to delete:"
echo "- Namespace: ${NAMESPACE}"
echo "- Certificate: ${CERT_NAME}"
echo "- Certificate Map Entry: ${ENTRY_NAME}"
echo ""

read -p "Are you sure you want to delete these resources? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

echo ""

# Delete namespace
echo "Deleting namespace..."
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true || true

# Delete certificate map entry
echo "Deleting certificate map entry..."
gcloud certificate-manager maps entries delete "${ENTRY_NAME}" \
    --map="webapp-cert-map" \
    --project="${PROJECT}" \
    --quiet || true

# Delete certificate
echo "Deleting certificate..."
gcloud certificate-manager certificates delete "${CERT_NAME}" \
    --project="${PROJECT}" \
    --quiet || true

echo ""
echo "✅ Preview cleanup completed for PR #${PR_NUMBER}"