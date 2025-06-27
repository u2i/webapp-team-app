#!/bin/bash
# Cleanup preview environments
# Usage: ./cleanup-previews.sh [name-pattern]

set -euo pipefail

PATTERN="${1:-webapp-preview-}"

echo "🧹 Cleaning up preview environments matching pattern: ${PATTERN}"
echo ""

# List namespaces to be deleted
echo "Namespaces to delete:"
kubectl get namespaces | grep "${PATTERN}" || echo "No matching namespaces found"
echo ""

if [ "$(kubectl get namespaces | grep -c "${PATTERN}" || true)" -eq 0 ]; then
    echo "✅ No preview namespaces to clean up"
    exit 0
fi

read -p "Are you sure you want to delete these namespaces? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

echo ""
echo "🗑️  Deleting namespaces..."

# Delete namespaces in parallel
kubectl get namespaces | grep "${PATTERN}" | awk '{print $1}' | \
    xargs -P 10 -I {} sh -c 'echo "Deleting {}..." && kubectl delete namespace {} --ignore-not-found=true'

echo ""
echo "✅ Preview cleanup initiated. Namespaces are being deleted in the background."
echo "Run 'kubectl get namespaces | grep ${PATTERN}' to check status."