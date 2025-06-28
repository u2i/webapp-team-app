# Developer Deployment Test Guide

This guide helps verify that developers have the correct permissions to deploy to non-production environments.

## Prerequisites

- You must be a member of `gcp-developers@u2i.com` Google Group
- You need `gcloud` CLI installed and authenticated
- You need access to the webapp-team-app GitHub repository

## Test 1: Verify Group Membership

```bash
# Check if you're in the developers group
gcloud projects get-iam-policy u2i-tenant-webapp \
  --flatten="bindings[].members" \
  --filter="bindings.members:group:gcp-developers@u2i.com" \
  --format="table(bindings.role)"
```

Expected roles:
- `roles/clouddeploy.developer`
- `roles/clouddeploy.viewer`
- `roles/cloudbuild.builds.editor`
- `roles/container.developer`

## Test 2: Create a Release

```bash
# Create a test release
gcloud deploy releases create test-dev-$(date +%Y%m%d%H%M%S) \
  --project=u2i-tenant-webapp \
  --region=europe-west1 \
  --delivery-pipeline=webapp-pipeline \
  --skaffold-file=skaffold-unified.yaml \
  --images=webapp=europe-west1-docker.pkg.dev/u2i-tenant-webapp/webapp-images/webapp:v5
```

✅ **Expected**: Release created successfully
❌ **If failed**: Check Cloud Deploy permissions

## Test 3: Deploy to Dev (Automatic)

The dev deployment should start automatically after creating a release.

```bash
# Check rollout status
gcloud deploy rollouts list \
  --project=u2i-tenant-webapp \
  --region=europe-west1 \
  --delivery-pipeline=webapp-pipeline \
  --release=test-dev-[YOUR-TIMESTAMP]
```

✅ **Expected**: Rollout to dev stage starts automatically
❌ **If failed**: Check Cloud Deploy pipeline configuration

## Test 4: Deploy to QA

```bash
# Promote to QA
gcloud deploy releases promote \
  --project=u2i-tenant-webapp \
  --region=europe-west1 \
  --delivery-pipeline=webapp-pipeline \
  --release=test-dev-[YOUR-TIMESTAMP] \
  --to-target=qa
```

✅ **Expected**: Promotion succeeds and QA deployment starts
❌ **If failed**: Check developer permissions for QA target

## Test 5: Try Production Promotion (Should Fail)

```bash
# Try to promote to production
gcloud deploy releases promote \
  --project=u2i-tenant-webapp \
  --region=europe-west1 \
  --delivery-pipeline=webapp-pipeline \
  --release=test-dev-[YOUR-TIMESTAMP] \
  --to-target=prod
```

✅ **Expected**: Promotion creates a pending rollout requiring approval
❌ **If succeeded without approval**: Production requires approval!

## Test 6: Try to Approve Production (Should Fail)

```bash
# Try to approve production rollout
gcloud deploy rollouts approve [ROLLOUT-NAME] \
  --project=u2i-tenant-webapp \
  --region=europe-west1 \
  --delivery-pipeline=webapp-pipeline
```

✅ **Expected**: Permission denied error
❌ **If succeeded**: Developers should NOT be able to approve production

## Test 7: View Deployment Status

```bash
# List all rollouts
gcloud deploy rollouts list \
  --project=u2i-tenant-webapp \
  --region=europe-west1 \
  --delivery-pipeline=webapp-pipeline
```

✅ **Expected**: Can view all rollouts across all stages
❌ **If failed**: Check clouddeploy.viewer permissions

## Test 8: Upload Build Artifacts

```bash
# Test artifact upload permissions
echo "test" > test.txt
gsutil cp test.txt gs://u2i-tenant-webapp-deploy-artifacts/test/
rm test.txt
```

✅ **Expected**: Upload succeeds
❌ **If failed**: Check storage.objectCreator permissions

## Test 9: View Container Images

```bash
# List images in Artifact Registry
gcloud artifacts docker images list \
  europe-west1-docker.pkg.dev/u2i-tenant-webapp/webapp-images \
  --project=u2i-tenant-webapp
```

✅ **Expected**: Can list and view images
❌ **If failed**: Check artifactregistry.reader permissions

## Test 10: Check GKE Access

```bash
# Get cluster credentials
gcloud container clusters get-credentials webapp-cluster \
  --region=europe-west1 \
  --project=u2i-tenant-webapp

# List pods in dev namespace
kubectl get pods -n nonprod-dev-webapp
```

✅ **Expected**: Can view resources in dev/qa namespaces
❌ **If failed**: Check container.developer permissions

## Summary of Developer Permissions

| Action | Dev | QA | Prod |
|--------|-----|----|------|
| Create Release | ✅ | ✅ | ✅ |
| Deploy | ✅ Auto | ✅ Auto | ⏸️ Requires Approval |
| Approve | N/A | N/A | ❌ |
| View Status | ✅ | ✅ | ✅ |
| View Logs | ✅ | ✅ | ✅ |

## Troubleshooting

### Permission Denied Errors

1. Verify group membership:
   ```bash
   gcloud auth list
   ```

2. Check your effective permissions:
   ```bash
   gcloud projects get-iam-policy u2i-tenant-webapp \
     --flatten="bindings[].members" \
     --filter="bindings.members:$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
   ```

### Deployment Failures

1. Check Cloud Deploy logs:
   ```bash
   gcloud deploy rollouts describe [ROLLOUT-NAME] \
     --project=u2i-tenant-webapp \
     --region=europe-west1 \
     --delivery-pipeline=webapp-pipeline
   ```

2. Check Cloud Build logs:
   ```bash
   gcloud builds list --project=u2i-tenant-webapp --limit=5
   ```

## Contact

- For permission issues: Contact your Google Workspace admin
- For deployment issues: Check #webapp-team Slack channel
- For urgent production approvals: Contact @gcp-approvers