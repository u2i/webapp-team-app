#!/bin/bash
# Script to install Config Connector operator
# This avoids Python version issues with gsutil

set -e

# Get cluster credentials
gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} \
  --region ${GKE_REGION} \
  --project ${GKE_PROJECT}

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Download using gcloud storage (doesn't have Python version restrictions)
echo "Downloading Config Connector operator..."
gcloud storage cp gs://configconnector-operator/latest/release-bundle.tar.gz release-bundle.tar.gz

# Extract the bundle
echo "Extracting release bundle..."
tar zxvf release-bundle.tar.gz

# Apply the operator
echo "Installing Config Connector operator..."
kubectl apply -f operator-system/configconnector-operator.yaml

# Wait for operator to be ready
echo "Waiting for Config Connector operator to be ready..."
kubectl wait --for=condition=Ready pod -n configconnector-operator-system --all --timeout=300s

# Clean up
cd -
rm -rf $TEMP_DIR

echo "Config Connector operator installed successfully!"