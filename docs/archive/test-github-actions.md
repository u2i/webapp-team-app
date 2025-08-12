# Test GitHub Actions

This file is created to test that GitHub Actions are working correctly with the configured Workload Identity Federation.

## Configuration

- WIF Provider: ✅ Configured
- Service Account: ✅ Configured
- IAM Permissions: ✅ Already set up in Terramate

## Expected Result

When this PR is created, the GitHub Actions should:
1. Authenticate using Workload Identity Federation
2. Deploy a preview environment
3. Comment on the PR with the preview URL