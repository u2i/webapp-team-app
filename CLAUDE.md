# Claude Configuration - webapp-team-app

## Repository Overview
This is a model/demo application repository for the WebApp Team, demonstrating compliant cloud-native application deployment with ISO 27001, SOC 2 Type II, and GDPR compliance.

## Deployment Process

### 1. Development Environment
- **Trigger**: Push to `main` branch
- **Automatic**: Yes  
- **URL**: https://dev.webapp.u2i.dev
- **Test**: `curl https://dev.webapp.u2i.dev/health`

### 2. QA Environment
- **Trigger**: Create and push a tag `v*.*.*`
- **Command**: 
  ```bash
  git tag -a v1.9.4 -m "Release v1.9.4: Description"
  git push origin v1.9.4
  ```
- **URL**: https://qa.webapp.u2i.dev
- **Test**: `curl https://qa.webapp.u2i.dev/health`

### 3. Production Environment  
- **Trigger**: Promote from QA using Cloud Deploy
- **Command**:
  ```bash
  # First, get the latest QA release name
  gcloud deploy releases list \
    --delivery-pipeline=webapp-qa-prod-pipeline \
    --region=europe-west1 \
    --project=u2i-tenant-webapp-nonprod \
    --limit=1 \
    --format="value(name.basename())"
  
  # Then promote to prod
  gcloud deploy releases promote \
    --release=qa-<sha> \
    --delivery-pipeline=webapp-qa-prod-pipeline \
    --region=europe-west1 \
    --project=u2i-tenant-webapp-nonprod \
    --to-target=prod-gke \
    --quiet
  
  # Approve the rollout
  gcloud deploy rollouts approve <rollout-id> \
    --release=qa-<sha> \
    --delivery-pipeline=webapp-qa-prod-pipeline \
    --region=europe-west1 \
    --project=u2i-tenant-webapp-nonprod
  ```
- **URL**: https://webapp.u2i.dev
- **Approval**: Manual approval required
- **Test**: `curl https://webapp.u2i.dev/health`

### 4. Preview Environment (PR)
- **Trigger**: Create Pull Request
- **URL Pattern**: `https://preview-pr<number>.webapp.u2i.dev`
- **Cleanup**: Automatic after PR merge/close
- **Test**: PR comment will contain preview URL

## Key Commands

### Check Deployment Status
```bash
# List recent builds
gcloud builds list \
  --project=u2i-tenant-webapp-nonprod \
  --region=europe-west1 \
  --limit=5 \
  --format="table(id.scope(builds),status,createTime.date(tz=LOCAL),substitutions.TRIGGER_NAME:label=TRIGGER)"

# Check specific build logs
gcloud builds log <build-id> \
  --project=u2i-tenant-webapp-nonprod \
  --region=europe-west1

# List releases
gcloud deploy releases list \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod \
  --limit=5

# Check rollout status
gcloud deploy rollouts list \
  --release=<release-name> \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod
```

### Local Development
```bash
# Install dependencies
npm install

# Run locally
npm start

# Run with compliance-cli (uses local source if available)
./compliance-cli --help
```

### Pipeline Management
```bash
# Generate pipeline configurations
make generate-pipelines

# Validate pipeline configurations
make validate-pipelines
```

## Important Files and Locations

### Core Application
- `app.js` - Main Express application
- `Dockerfile` - Container definition
- `package.json` - Node.js dependencies

### Deployment Configuration
- `deploy/clouddeploy/*.yml` - Cloud Deploy pipeline definitions
- `deploy/cloudbuild/*.yml` - Cloud Build configurations
- `deploy/skaffold.yml` - Skaffold deployment configuration
- `.compliance-cli.yml` - Compliance CLI configuration

### Kubernetes Manifests
- `k8s/app/base/` - Base Kubernetes resources
- `k8s/app/resources/` - Environment-specific overlays
- `k8s/gcp/` - GCP-specific resources (certificates)
- `k8s/namespace/` - Namespace definitions

### GitHub Actions
- `.github/workflows/cd-dev.yml` - Dev deployment (on push to main)
- `.github/workflows/cd-qa.yml` - QA deployment (on tag)
- `.github/workflows/cd-prod-promote.yml` - Production promotion
- `.github/workflows/validate-pipelines.yml` - Pipeline validation
- `.github/workflows/cleanup-old-previews.yml` - Preview cleanup

## Environment Variables
- `PROJECT_ID`: `u2i-tenant-webapp-nonprod` (for dev/qa/preview)
- `PROJECT_ID`: `u2i-tenant-webapp-prod` (for production)
- `REGION`: `europe-west1`
- `BOUNDARY`: `nonprod` or `prod`
- `STAGE`: `dev`, `qa`, `prod`, or `preview-*`

## Compliance Features
- ISO 27001 controls implemented
- SOC 2 Type II requirements met
- GDPR compliance with EU data residency
- Audit logging and change management via GitOps
- Security scanning and vulnerability management

## Common Issues and Solutions

### PR Comments Not Posting
- Check GitHub App permissions in Secret Manager
- Verify service account has access to secrets in u2i-bootstrap project

### Build Failures
- Check Cloud Build logs for detailed errors
- Verify Docker registry permissions
- Ensure compliance-cli version is up to date

### Deployment Stuck
- Check rollout status with `gcloud deploy rollouts describe`
- Look for pending approvals
- Verify target cluster is healthy

## Notes for Claude
- Always use `.yml` extension (not `.yaml`)
- The compliance-cli wrapper automatically uses local source if available
- Production deployments always require manual approval
- All shell scripts have been consolidated into compliance-cli v0.7.0+
- Documentation is organized under `docs/` with subdirectories for development, operations, and archive