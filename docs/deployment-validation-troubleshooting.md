# Deployment, Validation and Troubleshooting Guide

This guide documents the deployment process, validation steps, and common troubleshooting procedures for the webapp-team-app across all environments (dev, preview, QA, and production).

## Overview

The deployment pipeline uses:
- **Google Cloud Deploy** for release management
- **Cloud Build** for build execution
- **Kubernetes** for container orchestration
- **Kustomize** for configuration management
- **Config Connector (KCC)** for Google Cloud resources

## Deployment Process

### 1. Development (Automatic on merge to main)

When code is merged to main, dev deployment triggers automatically:

```bash
# Check for new dev release
gcloud deploy releases list --delivery-pipeline=webapp-dev-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --limit=2 --format="table(name.basename(),createTime.date())"

# Check rollout status
gcloud deploy rollouts describe dev-<SHA>-to-dev-gke-0001 --release=dev-<SHA> --delivery-pipeline=webapp-dev-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --format="value(state)"
```

### 2. Preview (Automatic on PR)

Preview deployments are created automatically for each PR:

```bash
# Check preview deployment status
kubectl get pods -n webapp-preview-pr<NUMBER> -l app=webapp

# Verify preview URL
curl -s https://pr<NUMBER>.webapp.u2i.dev/health | jq .
```

### 3. QA (Triggered by git tag)

Create a tag to deploy to QA:

```bash
# Create and push tag
git tag -a v1.X.Y -m "Description of changes" && git push origin v1.X.Y

# Check QA release
gcloud deploy releases list --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --limit=2 --format="table(name.basename(),createTime.date())"

# Check rollout status
gcloud deploy rollouts describe qa-<SHA>-to-qa-gke-0001 --release=qa-<SHA> --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --format="value(state)"
```

### 4. Production (Promotion from QA)

Promote QA release to production:

```bash
# Promote to production
gcloud deploy releases promote --release=qa-<SHA> --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --to-target=prod-gke

# Approve production rollout (if not auto-approved)
gcloud deploy rollouts approve qa-<SHA>-to-prod-gke-0001 --release=qa-<SHA> --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod
```

## Validation Steps

### 1. Basic Health Checks

```bash
# Dev
curl -s https://dev.webapp.u2i.dev/health | jq .

# QA
curl -s https://qa.webapp.u2i.dev/health | jq .

# Production
curl -s https://webapp.u2i.com/health | jq .
```

### 2. Kubernetes Resource Validation

```bash
# Switch to appropriate context
kubectl config use-context gke_u2i-tenant-webapp-nonprod_europe-west1_webapp-cluster  # For dev/qa
kubectl config use-context gke_u2i-tenant-webapp-prod_europe-west1_webapp-cluster     # For prod

# Check deployment
kubectl get deployment -n <NAMESPACE> <DEPLOYMENT_NAME> -o wide

# Check pods
kubectl get pods -n <NAMESPACE> -l app=webapp

# Check PDB (Pod Disruption Budget)
kubectl get pdb -n <NAMESPACE> webapp-pdb -o yaml | grep minAvailable:

# Check services
kubectl get svc -n <NAMESPACE>

# Check certificates (Config Connector resources)
kubectl get certificatemanagercertificate,certificatemanagercertificatemapentry -n webapp-resources
```

### 3. Parameter Validation

Verify parameters are correctly substituted:

```bash
# Check if parameters were applied correctly
kubectl get deployment -n <NAMESPACE> -o yaml | grep -E "image:|replicas:|minAvailable:"
```

## Common Issues and Troubleshooting

### 1. Deployment Selector Immutability Error

**Error**: `The Deployment "webapp" is invalid: spec.selector: Invalid value: v1.LabelSelector{...}: field is immutable`

**Cause**: Existing deployment has different selector labels than the new configuration.

**Solution**:
```bash
# Delete the existing deployment to allow recreation
kubectl delete deployment -n <NAMESPACE> <DEPLOYMENT_NAME>

# Retry the rollout
gcloud deploy rollouts retry-job <ROLLOUT_NAME> --release=<RELEASE> --delivery-pipeline=<PIPELINE> --region=europe-west1 --project=<PROJECT> --job-id=deploy --phase-id=stable
```

### 2. Parameter Substitution Failure

**Error**: `Invalid value: intstr.IntOrString{Type:1, IntVal:0, StrVal:"${PARAMETER}"}: a valid percent string must be...`

**Cause**: Parameters not being substituted, literal `${PARAMETER}` being used.

**Solution**:
1. Ensure parameters are defined in the appropriate config:
   - For dev/preview: In `scripts/deploy.sh` 
   - For QA/Prod: In `clouddeploy-qa-prod.yaml`
2. Re-apply Cloud Deploy configuration:
   ```bash
   gcloud deploy apply --file=clouddeploy-qa-prod.yaml --region=europe-west1 --project=u2i-tenant-webapp-nonprod
   ```

### 3. Config Connector Immutable Field Error

**Error**: `admission webhook "deny-immutable-field-updates.cnrm.cloud.google.com" denied the request: cannot make changes to immutable field(s): [projectRef]`

**Cause**: Trying to update Config Connector resources with different project references.

**Solution**:
```bash
# Delete existing certificates
kubectl delete certificatemanagercertificate <CERT_NAME> -n webapp-resources
kubectl delete certificatemanagercertificatemapentry <ENTRY_NAME> -n webapp-resources

# Retry deployment to recreate them
gcloud deploy rollouts retry-job <ROLLOUT_NAME> --release=<RELEASE> --delivery-pipeline=<PIPELINE> --region=europe-west1 --project=<PROJECT> --job-id=deploy --phase-id=stable
```

### 4. Cloud Build Failures

**Check build logs**:
```bash
# Find recent failed builds
gcloud builds list --project=<PROJECT> --region=europe-west1 --filter="status=FAILURE" --limit=5 --format="table(id.scope(builds),status,createTime.date())"

# Get detailed logs
gcloud builds log <BUILD_ID> --project=<PROJECT> --region=europe-west1 | tail -50
```

### 5. Post-Comment Failures (Non-blocking)

**Error**: `PERMISSION_DENIED: Permission 'secretmanager.versions.access' denied for resource`

**Note**: This is a known non-blocking issue with GitHub comment posting. The deployment succeeds despite this error.

## Environment-Specific Details

### Dev Environment
- **Project**: u2i-tenant-webapp-nonprod
- **Namespace**: webapp-dev
- **Pipeline**: webapp-dev-pipeline
- **PDB minAvailable**: 1

### QA Environment
- **Project**: u2i-tenant-webapp-nonprod
- **Namespace**: webapp-qa
- **Pipeline**: webapp-qa-prod-pipeline
- **PDB minAvailable**: 1

### Production Environment
- **Project**: u2i-tenant-webapp-prod
- **Namespace**: webapp-prod
- **Pipeline**: webapp-qa-prod-pipeline
- **PDB minAvailable**: 2

## Rollback Procedures

If a deployment causes issues:

1. **Identify the last working release**:
   ```bash
   gcloud deploy releases list --delivery-pipeline=<PIPELINE> --region=europe-west1 --project=<PROJECT> --limit=10
   ```

2. **Promote the previous release**:
   ```bash
   gcloud deploy releases promote --release=<PREVIOUS_RELEASE> --delivery-pipeline=<PIPELINE> --region=europe-west1 --project=<PROJECT> --to-target=<TARGET>
   ```

## Monitoring Deployment Progress

Use these commands to monitor ongoing deployments:

```bash
# Watch rollout progress
watch -n 5 'gcloud deploy rollouts describe <ROLLOUT> --release=<RELEASE> --delivery-pipeline=<PIPELINE> --region=europe-west1 --project=<PROJECT> --format="value(state)"'

# Watch pod status
watch -n 2 'kubectl get pods -n <NAMESPACE> -l app=webapp'

# Follow Cloud Build logs
gcloud builds log <BUILD_ID> --project=<PROJECT> --region=europe-west1 --stream
```

## Best Practices

1. **Always verify preview deployments** before merging to main
2. **Test dev deployment** before creating QA tag
3. **Validate QA thoroughly** before promoting to production
4. **Monitor rollout completion** before declaring success
5. **Check application health endpoints** after deployment
6. **Keep tags sequential** (v1.X.Y format) for clarity
7. **Document significant changes** in tag messages

## Quick Reference Commands

```bash
# Switch contexts quickly
alias kdev='kubectl config use-context gke_u2i-tenant-webapp-nonprod_europe-west1_webapp-cluster'
alias kprod='kubectl config use-context gke_u2i-tenant-webapp-prod_europe-west1_webapp-cluster'

# Common checks
alias check-dev='curl -s https://dev.webapp.u2i.dev/health | jq .'
alias check-qa='curl -s https://qa.webapp.u2i.dev/health | jq .'
alias check-prod='curl -s https://webapp.u2i.com/health | jq .'
```