#!/bin/bash
# Setup Workload Identity Federation for GitHub Actions
# This script should be run once to configure WIF

set -euo pipefail

# Configuration
PROJECT_ID="u2i-tenant-webapp-nonprod"
REPO="u2i/webapp-team-app"  # Update this to your actual repo
SERVICE_ACCOUNT_NAME="github-actions-sa"
WORKLOAD_IDENTITY_POOL="github-actions-pool"
WORKLOAD_IDENTITY_PROVIDER="github-actions-provider"

echo "🔧 Setting up Workload Identity Federation for GitHub Actions"
echo "Project: ${PROJECT_ID}"
echo "Repository: ${REPO}"
echo ""

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable iamcredentials.googleapis.com \
  cloudbuild.googleapis.com \
  clouddeploy.googleapis.com \
  container.googleapis.com \
  certificatemanager.googleapis.com \
  --project="${PROJECT_ID}"

# Create service account
echo "Creating service account..."
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
  --display-name="GitHub Actions Service Account" \
  --project="${PROJECT_ID}" || true

SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant necessary permissions
echo "Granting permissions to service account..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/clouddeploy.releaser" \
  --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudbuild.builds.builder" \
  --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/container.developer" \
  --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/certificatemanager.editor" \
  --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin" \
  --condition=None

# Create Workload Identity Pool
echo "Creating Workload Identity Pool..."
gcloud iam workload-identity-pools create ${WORKLOAD_IDENTITY_POOL} \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project="${PROJECT_ID}" || true

# Create Workload Identity Provider
echo "Creating Workload Identity Provider..."
gcloud iam workload-identity-pools providers create-oidc ${WORKLOAD_IDENTITY_PROVIDER} \
  --location="global" \
  --workload-identity-pool="${WORKLOAD_IDENTITY_POOL}" \
  --display-name="GitHub Actions Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project="${PROJECT_ID}" || true

# Get Workload Identity Provider resource name
WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe ${WORKLOAD_IDENTITY_PROVIDER} \
  --location="global" \
  --workload-identity-pool="${WORKLOAD_IDENTITY_POOL}" \
  --project="${PROJECT_ID}" \
  --format="value(name)")

# Grant service account permissions to the repository
echo "Configuring repository access..."
gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WIF_PROVIDER}/attribute.repository/${REPO}"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Add these secrets to your GitHub repository:"
echo ""
echo "WIF_PROVIDER:"
echo "${WIF_PROVIDER}"
echo ""
echo "WIF_SERVICE_ACCOUNT:"
echo "${SA_EMAIL}"
echo ""
echo "To add these secrets:"
echo "1. Go to https://github.com/${REPO}/settings/secrets/actions"
echo "2. Click 'New repository secret'"
echo "3. Add WIF_PROVIDER with the value above"
echo "4. Add WIF_SERVICE_ACCOUNT with the value above"