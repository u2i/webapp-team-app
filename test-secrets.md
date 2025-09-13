# Testing External Secrets Fix

This PR tests the fix for External Secrets in preview environments.

## Issue
- SecretStore unable to authenticate with Secret Manager
- Error: "unable to fetch identitybindingtoken"
- CLUSTER_LOCATION and CLUSTER_NAME parameters were not being substituted

## Fix
- Added CLUSTER_LOCATION and CLUSTER_NAME parameters to compliance-cli
- Parameters now properly passed during deployment

## Verification
Check the ExternalSecret and SecretStore status after deployment.