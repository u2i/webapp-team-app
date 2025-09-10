# Secret Manager POC Setup

This document describes the infrastructure setup required for the Secret Manager POC to work fully in preview environments.

## Overview

The Secret Manager POC demonstrates two approaches:
1. **JavaScript Client Approach**: Direct API calls using `@google-cloud/secret-manager`
2. **Environment Variable Approach**: Kubernetes secret injection

## Current Status

### ✅ Environment Variable Approach - Working
- Uses Kubernetes secrets with manual creation
- Value: `demo-secret-nonprod-environment-12345`
- Environment variable: `WEBAPP_DEMO_SECRET`

### ⚠️ JavaScript Client Approach - Needs IAM Fix
- Code is correct and attempting proper authentication
- Missing workload identity binding for preview namespaces
- Error: `Permission 'iam.serviceAccounts.getAccessToken' denied`

## Required Infrastructure

### Existing Infrastructure ✅
```bash
# Secret in Secret Manager
SECRET_NAME="webapp-demo-secret"
SECRET_VALUE="demo-secret-nonprod-environment-12345"
PROJECT_ID="u2i-tenant-webapp-nonprod"

# Service Account
SERVICE_ACCOUNT="webapp-k8s@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com"

# Existing IAM Permissions
# - roles/secretmanager.secretAccessor on webapp-demo-secret
# - Workload identity bindings for specific namespaces:
#   - webapp-dev/webapp
#   - webapp-qa/webapp  
#   - webapp-preview/webapp
#   - webapp-preview-pr220/webapp
```

### Missing Infrastructure ❌
```bash
# Wildcard workload identity binding for all preview environments
gcloud iam service-accounts add-iam-policy-binding \
  webapp-k8s@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:u2i-tenant-webapp-nonprod.svc.id.goog[webapp-preview-*/webapp]"
```

## Testing Endpoints

Once the infrastructure is complete, test both approaches:

```bash
# Test comparison (both approaches)
curl https://preview-pr<NUMBER>.webapp.u2i.dev/poc/secrets/compare

# Test JavaScript client approach  
curl https://preview-pr<NUMBER>.webapp.u2i.dev/poc/secrets/client/webapp-demo-secret

# Test environment variable approach
curl https://preview-pr<NUMBER>.webapp.u2i.dev/poc/secrets/env/WEBAPP_DEMO_SECRET

# Debug environment variables
curl https://preview-pr<NUMBER>.webapp.u2i.dev/poc/secrets/debug/env
```

## Expected Results

### JavaScript Client Approach Success:
```json
{
  "approach": "javascript-client",
  "secretName": "webapp-demo-secret", 
  "value": "demo-secret-nonprod-environment-12345",
  "fetchTimeMs": 150,
  "metadata": {
    "projectId": "u2i-tenant-webapp-nonprod",
    "resourceName": "projects/u2i-tenant-webapp-nonprod/secrets/webapp-demo-secret/versions/latest"
  }
}
```

### Environment Variable Approach Success:
```json
{
  "approach": "kubernetes-env-var",
  "secretName": "webapp-demo-secret",
  "envVarName": "WEBAPP_DEMO_SECRET", 
  "value": "demo-secret-nonprod-environment-12345",
  "fetchTimeMs": 0,
  "metadata": {
    "injectedAtStartup": true
  }
}
```

## Security Considerations

The wildcard binding `webapp-preview-*/webapp` is appropriate because:

- ✅ **Scoped to preview environments**: Only affects temporary PR environments
- ✅ **Scoped to specific service account**: Only `webapp` SA, not all SAs
- ✅ **Scoped to specific project**: Only `u2i-tenant-webapp-nonprod`
- ✅ **Temporary environments**: Preview environments are short-lived
- ✅ **Non-production**: No access to production secrets or resources

## Implementation Options

### Option 1: Apply IAM Binding Directly (Immediate)
```bash
gcloud iam service-accounts add-iam-policy-binding \
  webapp-k8s@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:u2i-tenant-webapp-nonprod.svc.id.goog[webapp-preview-*/webapp]"
```

### Option 2: Add to Terraform (Recommended for production)
```hcl
resource "google_service_account_iam_member" "webapp_workload_identity_preview_wildcard" {
  service_account_id = "projects/u2i-tenant-webapp-nonprod/serviceAccounts/webapp-k8s@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:u2i-tenant-webapp-nonprod.svc.id.goog[webapp-preview-*/webapp]"
}
```

## Verification

After applying the IAM binding, verify it's working:

```bash
# Check IAM policy
gcloud iam service-accounts get-iam-policy \
  webapp-k8s@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com

# Test JavaScript client in preview environment
kubectl run test-pod --rm -i --tty \
  --image=google/cloud-sdk:slim \
  --serviceaccount=webapp \
  --namespace=webapp-preview-pr<NUMBER> \
  -- gcloud auth list
```