# Deployment, Validation and Troubleshooting Guide

This guide documents the deployment process, validation steps, and troubleshooting procedures for the webapp-team-app across all environments.

## Overview

The deployment pipeline uses:
- **Google Cloud Deploy** for release management
- **Cloud Build** for build execution
- **Kubernetes** for container orchestration
- **Kustomize** for configuration management
- **Config Connector (KCC)** for Google Cloud resources

## Deployment Flow Summary

1. **PR** → Preview environment (automatic)
2. **Merge to main** → Dev environment (automatic)
3. **Git tag** → QA environment (automatic)
4. **Promote** → Production (manual approval)

## Deployment Testing Flow

Follow this order to ensure changes are properly tested before reaching production:

### 1. Create Pull Request

```bash
# Create feature branch
git checkout -b feature-branch-name

# Make changes and commit
git add -A && git commit -m "Description of changes"
git push -u origin feature-branch-name

# Create PR
gh pr create --title "Title" --body "Description"
```

### 2. Validate Preview Deployment (Automatic on PR)

Preview deployments are created automatically for each PR:

```bash
# Wait for preview deployment to complete
# Check PR status on GitHub or use:
gh pr view <PR_NUMBER> --json statusCheckRollup

# Once deployed, verify preview environment
curl -s https://pr<NUMBER>.webapp.u2i.dev/health | jq .

# Check preview pods and resources
kubectl get pods -n webapp-preview-pr<NUMBER> -l app=webapp
kubectl get deployment,svc,pdb -n webapp-preview-pr<NUMBER>
```

### 3. Merge to Main → Dev Deployment

```bash
# After preview validation, merge PR
gh pr merge <PR_NUMBER> --merge --delete-branch

# Dev deployment triggers automatically on merge
# Monitor dev deployment
gcloud deploy releases list --delivery-pipeline=webapp-dev-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --limit=2

# Check rollout status
gcloud deploy rollouts describe dev-<SHA>-to-dev-gke-0001 --release=dev-<SHA> --delivery-pipeline=webapp-dev-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --format="value(state)"

# Validate dev environment
curl -s https://dev.webapp.u2i.dev/health | jq .
```

### 4. Tag for QA Deployment

```bash
# After dev validation, create tag for QA
git pull origin main
git tag -a v1.X.Y -m "Description of changes"
git push origin v1.X.Y

# Monitor QA deployment
gcloud deploy releases list --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --limit=2

# Check rollout status
gcloud deploy rollouts describe qa-<SHA>-to-qa-gke-0001 --release=qa-<SHA> --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --format="value(state)"

# Validate QA environment
curl -s https://qa.webapp.u2i.dev/health | jq .
```

### 5. Promote to Production

```bash
# After QA validation, promote to production
gcloud deploy releases promote --release=qa-<SHA> --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --to-target=prod-gke

# Approve production rollout if required
gcloud deploy rollouts approve qa-<SHA>-to-prod-gke-0001 --release=qa-<SHA> --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod

# Monitor production deployment
gcloud deploy rollouts describe qa-<SHA>-to-prod-gke-0001 --release=qa-<SHA> --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1 --project=u2i-tenant-webapp-nonprod --format="value(state)"

# Validate production environment
curl -s https://webapp.u2i.com/health | jq .
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

## Troubleshooting Deployments

### Finding Failed Deployments

```bash
# List recent releases and their status
gcloud deploy releases list --delivery-pipeline=<PIPELINE> --region=europe-west1 --project=<PROJECT> --limit=10

# Check specific rollout status
gcloud deploy rollouts describe <ROLLOUT> --release=<RELEASE> --delivery-pipeline=<PIPELINE> --region=europe-west1 --project=<PROJECT>

# Find failed builds
gcloud builds list --project=<PROJECT> --region=europe-west1 --filter="status=FAILURE" --limit=5

# Get build logs
gcloud builds log <BUILD_ID> --project=<PROJECT> --region=europe-west1
```

### Retrying Failed Deployments

```bash
# Retry a failed rollout job
gcloud deploy rollouts retry-job <ROLLOUT> --release=<RELEASE> --delivery-pipeline=<PIPELINE> --region=europe-west1 --project=<PROJECT> --job-id=deploy --phase-id=stable
```

### Common Debugging Commands

```bash
# Check pod events for errors
kubectl describe pod -n <NAMESPACE> <POD_NAME>

# Check deployment status
kubectl rollout status deployment/<DEPLOYMENT_NAME> -n <NAMESPACE>

# View recent events in namespace
kubectl get events -n <NAMESPACE> --sort-by='.lastTimestamp'

# Check resource YAML for issues
kubectl get <RESOURCE_TYPE> <RESOURCE_NAME> -n <NAMESPACE> -o yaml
```

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

## Testing Best Practices

1. **Always start with a PR** - Never push directly to main
2. **Validate each environment** before proceeding to the next:
   - Preview must pass before merging
   - Dev must pass before tagging for QA
   - QA must pass before promoting to production
3. **Wait for deployments to complete** - Check rollout status, not just trigger
4. **Verify application functionality** - Don't just check pod status
5. **Use semantic versioning** for tags (v1.X.Y)
6. **Test in the morning** - Avoid Friday afternoon deployments
7. **Have a rollback plan** - Know the last working version

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