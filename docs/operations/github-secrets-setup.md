# GitHub Secrets Configuration

Based on the Terramate configuration in u2i-infrastructure, the following GitHub secrets need to be configured:

## Required Secrets

1. **WIF_PROVIDER**
   ```
   projects/310843575960/locations/global/workloadIdentityPools/webapp-github-wif/providers/github
   ```

2. **WIF_SERVICE_ACCOUNT**
   ```
   cloud-deploy-sa@u2i-tenant-webapp.iam.gserviceaccount.com
   ```

## How to Add Secrets

1. Go to: https://github.com/u2i/webapp-team-app/settings/secrets/actions
2. Click "New repository secret"
3. Add each secret with the values above

## Notes

- The Workload Identity Federation is already configured in Terramate
- The `cloud-deploy-sa` service account already has all necessary permissions
- The WIF provider already allows the `u2i/webapp-team-app` repository

## Verification

After adding the secrets, the GitHub Actions workflows should be able to:
- Authenticate with Google Cloud
- Deploy to Cloud Deploy pipelines
- Manage certificates and other resources