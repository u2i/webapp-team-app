#!/bin/bash
# Script to update compliance-cli version across all Cloud Build files

set -e

# Read the version from the version file
VERSION=$(cat .compliance-cli-version)

echo "Updating compliance-cli to version: $VERSION"

# Update all Cloud Build YAML files
for file in deploy/cloudbuild/*.yaml; do
    if grep -q "compliance-cli-builder" "$file"; then
        echo "Updating $file..."
        # Use sed to replace the image tag
        sed -i.bak "s|us-docker.pkg.dev/u2i-bootstrap/gcr.io/compliance-cli-builder:[^']*|us-docker.pkg.dev/u2i-bootstrap/gcr.io/compliance-cli-builder:${VERSION}|g" "$file"
        # Remove backup files
        rm "${file}.bak"
    fi
done

echo "✅ Updated all Cloud Build files to use compliance-cli version $VERSION"
echo ""
echo "Next steps:"
echo "1. Review the changes: git diff deploy/cloudbuild/"
echo "2. Commit the changes: git add -A && git commit -m 'chore: Update compliance-cli to $VERSION'"
echo "3. Push to trigger deployments: git push"