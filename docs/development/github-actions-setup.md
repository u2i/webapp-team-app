# GitHub Actions Setup Requirements

## Prerequisites

Before the GitHub Actions workflows can run, the following infrastructure needs to be configured through Terramate in the u2i-infrastructure repository:

### 1. Workload Identity Federation

Create a Workload Identity setup for GitHub Actions with:

- **Workload Identity Pool**: `github-actions-pool`
- **Workload Identity Provider**: `github-actions-provider`
- **Service Account**: `github-actions-sa@u2i-tenant-webapp.iam.gserviceaccount.com`

### 2. Required IAM Roles

The service account needs the following roles:

```hcl
# In Terramate configuration
roles = [
  "roles/clouddeploy.releaser",       # Create Cloud Deploy releases
  "roles/cloudbuild.builds.builder",   # Build Docker images
  "roles/container.developer",         # Deploy to GKE
  "roles/certificatemanager.editor",   # Manage SSL certificates
  "roles/storage.objectAdmin",         # Access Cloud Deploy artifacts
]
```

### 3. Workload Identity Binding

Configure the repository binding:

```hcl
# Allow the GitHub repository to impersonate the service account
principalSet = "//iam.googleapis.com/${workload_identity_pool}/attribute.repository/u2i/webapp-team-app"
```

### 4. GitHub Secrets

After Terramate creates the resources, add these secrets to the GitHub repository:

1. Go to: https://github.com/u2i/webapp-team-app/settings/secrets/actions
2. Add these repository secrets:
   - `WIF_PROVIDER`: The full resource name of the Workload Identity Provider
   - `WIF_SERVICE_ACCOUNT`: `github-actions-sa@u2i-tenant-webapp.iam.gserviceaccount.com`

## Testing Without GitHub Actions

Until WIF is configured, you can test preview deployments manually:

```bash
# Deploy a preview
./compliance-cli preview --pr-number 999

# Check status
kubectl get pods -n webapp-preview-pr999

# Access the preview
curl https://pr999.webapp.u2i.dev

# Cleanup
./scripts/cleanup-preview-pr.sh 999
```

## Workflows Included

Once configured, these workflows will run automatically:

- **deploy-dev.yaml**: Deploys main branch to dev environment
- **deploy-preview.yaml**: Deploys PRs to preview environments
- **deploy-qa-prod.yaml**: Deploys tags to QA (and allows promotion to prod)
- **cleanup-old-previews.yaml**: Daily cleanup of old preview environments