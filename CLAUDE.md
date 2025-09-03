# Claude Configuration - webapp-team-app

## Repository Overview

This is a model/demo application repository for the WebApp Team, demonstrating compliant cloud-native application deployment with ISO 27001, SOC 2 Type II, and GDPR compliance.

## 🚨 IMPORTANT: Development Process

**ALL CHANGES MUST BE MADE VIA PULL REQUEST**

- Never commit directly to the `main` branch
- Create a feature branch for changes
- Open a PR for review and testing
- PR will trigger preview deployment for testing
- Merge to main only after approval

### PR Workflow

```bash
# Create feature branch
git checkout -b feature/my-change

# Make changes and commit
git add .
git commit -m "feat: Description of change"

# Push branch and create PR
git push origin feature/my-change
gh pr create --title "feat: Description" --body "Details of changes"

# After approval and merge, the PR branch will trigger:
# 1. Preview deployment (during PR)
# 2. Dev deployment (after merge to main)
```

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

- **URL**: https://webapp.u2i.com
- **Approval**: Manual approval required
- **Test**: `curl https://webapp.u2i.com/health`

### 4. Preview Environment (PR)

- **Trigger**: Create Pull Request
- **URL Pattern**: `https://preview-pr<number>.webapp.u2i.dev`
- **Cleanup**: Automatic after PR merge/close
- **Test**: PR comment will contain preview URL

## Deployment Management Commands

### Checking Environment Status

```bash
# Check all environments health
curl -s https://dev.webapp.u2i.dev/health | jq '.'
curl -s https://qa.webapp.u2i.dev/health | jq '.'
curl -s https://webapp.u2i.com/health | jq '.'  # Production (note: .com domain)
curl -s https://preview-pr<NUMBER>.webapp.u2i.dev/health | jq '.'  # Preview

# Check PR status and deployments
gh pr list --state open
gh pr checks <PR_NUMBER>
```

### Managing Deployments

#### Deploy to Dev (Automatic)

```bash
# Dev deploys automatically when merging to main
# To manually check status:
gcloud builds list \
  --project=u2i-tenant-webapp-nonprod \
  --region=europe-west1 \
  --filter="tags:dev" \
  --limit=5
```

#### Deploy to QA

```bash
# Create and push a version tag
git tag -a v1.9.4 -m "Release v1.9.4: Feature description"
git push origin v1.9.4

# Monitor QA deployment
gcloud builds list \
  --project=u2i-tenant-webapp-nonprod \
  --region=europe-west1 \
  --filter="tags:qa" \
  --limit=5
```

#### Deploy to Production

```bash
# Get the latest QA release
RELEASE=$(gcloud deploy releases list \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod \
  --filter="targetSnapshots.targets:qa-gke" \
  --limit=1 \
  --format="value(name.basename())")

echo "Promoting release: $RELEASE"

# Promote to production
gcloud deploy releases promote \
  --release=$RELEASE \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod \
  --to-target=prod-gke \
  --quiet

# Get the rollout ID
ROLLOUT=$(gcloud deploy rollouts list \
  --release=$RELEASE \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod \
  --filter="state=PENDING_APPROVAL" \
  --limit=1 \
  --format="value(name.basename())")

# Approve production deployment
gcloud deploy rollouts approve $ROLLOUT \
  --release=$RELEASE \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod
```

#### Managing Preview Environments

```bash
# Preview environments are created automatically for PRs
# To check preview deployment status:
gh pr checks <PR_NUMBER>

# To trigger a rebuild of preview:
git commit --allow-empty -m "chore: Trigger preview rebuild"
git push origin <branch-name>

# Preview URLs follow pattern:
# https://preview-pr<NUMBER>.webapp.u2i.dev
```

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
- `deploy/cloudbuild/*.yaml` - Cloud Build configurations
- `deploy/skaffold.yaml` - Skaffold deployment configuration
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

## Important Domain Configuration

- **Dev/QA/Preview**: Use `.u2i.dev` domain (managed in u2i-dns project)
- **Production**: Uses `.u2i.com` domain (managed in u2i-tenant-webapp-prod project)
- DNS zones are in different projects - this is intentional for security isolation

## Preview Environment Certificate Provisioning

**IMPORTANT**: When a new preview environment is created (PR opened), the SSL certificate provisioning can take 15-30 minutes. During this time:

- The deployment will complete successfully
- Pods will be running and healthy
- The URL will not be accessible until the certificate moves from `PROVISIONING` to `ACTIVE` state

To check certificate status:

```bash
# Check certificate state for a specific PR
PR_NUM=216
gcloud certificate-manager certificates describe webapp-preview-cert-pr${PR_NUM} \
  --location=global \
  --project=u2i-tenant-webapp-nonprod \
  --format="get(state,managed.state)"
```

The certificate goes through these states:

1. `PROVISIONING` → Initial state
2. `FAILED (CONFIG)` → Normal during DNS propagation (temporary)
3. `PROVISIONING` → Retrying after DNS propagates
4. `ACTIVE` → Ready to use

This is normal behavior for Google-managed certificates and not an error.

## Compliance Features

- ISO 27001 controls implemented
- SOC 2 Type II requirements met
- GDPR compliance with EU data residency
- Audit logging and change management via GitOps
- Security scanning and vulnerability management

## Troubleshooting Deployments

### Common Issues and Solutions

#### Preview Deployment Not Working

```bash
# Check if build triggered
gh pr checks <PR_NUMBER>

# Check Cloud Build trigger configuration
gcloud builds triggers describe webapp-preview-deployment \
  --project=u2i-tenant-webapp-nonprod \
  --region=europe-west1

# Trigger manual rebuild
git commit --allow-empty -m "chore: Trigger rebuild"
git push origin <branch-name>
```

#### Build Failures

```bash
# Get build ID from PR checks or builds list
BUILD_ID=<build-id>

# View detailed build logs
gcloud builds log $BUILD_ID \
  --project=u2i-tenant-webapp-nonprod \
  --region=europe-west1

# Common issues:
# - Docker registry permissions
# - Missing secrets/config
# - Compliance CLI version outdated
```

#### Deployment Stuck in Pending

```bash
# Check rollout status
gcloud deploy rollouts describe <rollout-id> \
  --release=<release-name> \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod

# Look for pending approvals
gcloud deploy rollouts list \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod \
  --filter="state=PENDING_APPROVAL"

# Retry failed rollout
gcloud deploy rollouts retry <rollout-id> \
  --release=<release-name> \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod
```

#### Environment Not Responding

```bash
# Check pod status
kubectl get pods -n webapp-<env>

# Check recent events
kubectl get events -n webapp-<env> --sort-by='.lastTimestamp'

# View pod logs
kubectl logs -n webapp-<env> deployment/webapp

# Check ingress/certificate status
kubectl get ingress -n webapp-<env>
kubectl get certificate -n webapp-<env>
```

#### PR Comments Not Posting

```bash
# Verify GitHub App configuration
# Check secrets in Secret Manager (requires access to u2i-bootstrap)
gcloud secrets versions access latest \
  --secret="github-app-private-key" \
  --project=u2i-bootstrap

# Check service account permissions
gcloud projects get-iam-policy u2i-bootstrap \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:webapp-ci@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com"
```

## Notes for Claude

### Important Conventions

- Use `.yaml` extension for Cloud Build files (not `.yml`)
- Use `.yml` extension for Cloud Deploy files
- The compliance-cli wrapper automatically uses local source if available
- Production deployments always require manual approval
- All shell scripts have been consolidated into compliance-cli v0.7.0+
- Documentation is organized under `docs/` with subdirectories for development, operations, and archive

### Authentication Requirements

- Use `gcp-failsafe@u2i.com` account for GCP operations:
  ```bash
  gcloud config set account gcp-failsafe@u2i.com
  ```
- GitHub CLI should be authenticated for PR operations

### Deployment Checklist

When helping with deployments, always:

1. Check current environment status first
2. Verify PR has passed all checks before merging
3. Monitor build/deployment logs for errors
4. Test health endpoints after deployment
5. Document any issues or changes made

### Quick Status Check Commands

```bash
# Check all environments at once
for env in dev qa prod; do
  if [ "$env" = "prod" ]; then
    url="https://webapp.u2i.com/health"  # Production uses .com domain
  else
    url="https://${env}.webapp.u2i.dev/health"
  fi
  echo -n "$env: "
  curl -s -o /dev/null -w "%{http_code}" $url
  echo
done

# Check preview for specific PR
PR_NUM=188
curl -s -o /dev/null -w "PR $PR_NUM preview: %{http_code}\n" https://preview-pr${PR_NUM}.webapp.u2i.dev/health
```
