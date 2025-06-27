# WebApp Deployment Guide

## Overview

The WebApp uses Google Cloud Deploy for continuous deployment with the following structure:

### Pipelines

1. **webapp-qa-prod-pipeline**: For production deployments (QA → Production with approval)
2. **webapp-other-pipeline**: For development deployments
3. **webapp-preview-pipeline**: For PR preview deployments (existing 3-stage pipeline)

### Profiles

- **prod**: Production configuration (webapp.u2i.com)
- **preprod**: Pre-production environments (dev, qa)
- **preview**: Preview environments for PRs

## Deployment Workflows

### 1. Development (Continuous Deployment)

- **Trigger**: Push to `main` branch
- **Pipeline**: webapp-other-pipeline
- **Target**: dev
- **Domain**: dev.webapp.u2i.dev
- **Automatic**: Yes

### 2. Preview (PR Deployments)

- **Trigger**: Pull Request opened/updated
- **Pipeline**: webapp-preview-pipeline (3-stage)
- **Domain**: pr-{number}.webapp.u2i.dev
- **Automatic**: Yes
- **Cleanup**: Automatic on PR close

### 3. QA Deployment

- **Trigger**: Git tag (v*)
- **Pipeline**: webapp-qa-prod-pipeline
- **Target**: qa
- **Domain**: qa.webapp.u2i.dev
- **Automatic**: Yes

### 4. Production Deployment

- **Trigger**: Manual promotion from QA
- **Pipeline**: webapp-qa-prod-pipeline
- **Target**: prod
- **Domain**: webapp.u2i.com
- **Approval**: Required

## Manual Operations

### Deploy a Preview Environment

```bash
./scripts/deploy-preview.sh my-feature
# Creates: my-feature.webapp.u2i.dev
```

### Deploy a PR Preview

```bash
./scripts/deploy-preview.sh pr-123
# Creates: pr-123.webapp.u2i.dev
```

### Promote to Production

```bash
./scripts/promote-to-prod.sh v1.2.3
# Promotes release v1.2.3 from QA to Production (requires approval)
```

## GitHub Actions

All deployments are triggered via GitHub Actions:

- `.github/workflows/deploy-dev.yaml` - Deploys main to dev
- `.github/workflows/deploy-preview.yaml` - Deploys PRs to preview
- `.github/workflows/deploy-qa-prod.yaml` - Deploys tags to QA

## Environment Configuration

### Development/QA
- Namespace: webapp-dev / webapp-qa
- Resources: Standard
- Replicas: 2
- Auto-scaling: Enabled

### Production
- Namespace: webapp-prod
- Resources: Enhanced
- Replicas: 3 minimum
- Auto-scaling: Enabled
- Multi-zone deployment

### Preview
- Namespace: webapp-preview-{name}
- Resources: Minimal
- Replicas: 2
- Auto-cleanup: Yes

## Security & Compliance

- All environments use ISO27001/SOC2/GDPR compliant configurations
- Production deployments require approval
- All deployments use Workload Identity for authentication
- Secrets managed via Google Secret Manager

## Monitoring

- Dev: Basic monitoring
- QA: Full monitoring with alerts
- Prod: Full monitoring, alerts, and SLO tracking
- Preview: Minimal monitoring

## Preview Cleanup

### Automatic Cleanup

1. **PR Closed**: When a PR is closed/merged, the preview is automatically cleaned up
2. **Scheduled**: Daily cleanup of previews older than 7 days (runs at 2 AM UTC)

### Manual Cleanup

#### Clean up specific PR preview:
```bash
./scripts/cleanup-preview-pr.sh 123
# Removes namespace, certificate, and certificate map entry
```

#### Clean up all preview namespaces:
```bash
./scripts/cleanup-previews.sh
```

#### Clean up previews matching pattern:
```bash
./scripts/cleanup-previews.sh webapp-preview-pr-
```

## Troubleshooting

### Check Deployment Status

```bash
gcloud deploy releases list --delivery-pipeline=webapp-qa-prod-pipeline --region=europe-west1
```

### View Deployment Logs

```bash
gcloud deploy rollouts describe <rollout-name> --release=<release-name> --delivery-pipeline=<pipeline> --region=europe-west1
```

### List All Preview Environments

```bash
kubectl get namespaces | grep webapp-preview-
```

### Check Certificate Status

```bash
gcloud certificate-manager certificates list --project=u2i-tenant-webapp | grep webapp-preview
```