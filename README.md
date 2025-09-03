# WebApp Team - Compliant Application Repository

This repository contains the WebApp Team's application deployment infrastructure following ISO 27001, SOC 2 Type II, and GDPR compliance requirements.

## 🚨 Important: Contributing

**All changes MUST be made via Pull Request.** See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

- Never push directly to `main`
- Every PR gets a preview deployment
- Changes require code review approval

## 🏗️ Repository Structure

```
webapp-team-app/
├── .github/workflows/          # GitOps CI/CD workflows
├── deploy/                     # Deployment configurations
│   ├── clouddeploy/           # Cloud Deploy pipelines
│   │   ├── dev.yaml          # Development pipeline
│   │   ├── qa-prod.yaml      # QA to Production pipeline
│   │   └── preview.yaml      # Preview deployment pipeline
│   └── skaffold.yaml         # Unified Skaffold configuration
├── k8s/                       # Kubernetes manifests
│   ├── app/                   # Application resources
│   ├── gcp/                   # GCP-specific resources
│   └── namespace/             # Namespace definitions
├── scripts/                   # Deployment and utility scripts
├── docs/                      # Documentation
├── app.js                     # Sample application code
├── Dockerfile                 # Container image definition
└── README.md                  # This file
```

## 🏗️ Infrastructure Repository

**Infrastructure as Code** is managed separately at:
**[webapp-team-infrastructure](https://github.com/u2i/webapp-team-infrastructure)**

This includes:

- Terraform configuration for the tenant project
- GitOps workflows with Slack approval
- Kubernetes namespace and RBAC setup
- Infrastructure compliance automation

## 🔒 Compliance Features

### ISO 27001 Controls

- **A.12.1.2** Change management via GitOps workflows
- **A.9.4.1** Access restriction through RBAC
- **A.12.4.1** Comprehensive audit logging
- **A.12.6.1** Vulnerability scanning via Binary Authorization

### SOC 2 Type II Requirements

- **CC8.1** Change control with approval gates
- **CC6.1** Logical access controls
- **CC6.6** Audit logging and monitoring
- **CC7.2** Continuous monitoring

### GDPR Compliance (EU/Belgium)

- **Art. 25** Data protection by design
- **Art. 32** Security of processing
- **Data residency** in EU (europe-west1)

## 🚀 Deployment Pipelines

### 1. Development Pipeline (`webapp-dev-pipeline`)

- **Trigger**: Push to `main` branch
- **Target**: `dev-gke`
- **Deployment**: Automatic
- **Environment**: dev.webapp.u2i.dev

### 2. QA/Production Pipeline (`webapp-qa-prod-pipeline`)

- **QA Stage**:
  - **Trigger**: Git tags (v*.*.\*)
  - **Target**: `qa-gke`
  - **Deployment**: Automatic
  - **Environment**: qa.webapp.u2i.dev
- **Production Stage**:
  - **Trigger**: Manual promotion from QA
  - **Target**: `prod-gke`
  - **Approval**: Required
  - **Environment**: webapp.u2i.com

### 3. Preview Pipeline (`webapp-preview-pipeline`)

- **Trigger**: Pull Request events
- **Deployment**: 3-stage (certificate → infrastructure → application)
- **Environment**: pr-{number}.webapp.u2i.dev
- **Cleanup**: Automatic on PR close

## 🔧 Getting Started

### Prerequisites

- Access to GCP projects:
  - `u2i-tenant-webapp-nonprod` (dev/qa environments)
  - `u2i-tenant-webapp-prod` (production environment)
- Membership in appropriate Google Groups:
  - `gcp-developers@u2i.com` for development access
  - `webapp-team@u2i.com` for team resources
- GitHub repository access with proper branch protection
- Tools: `gcloud`, `kubectl`, `docker`

### Local Development

```bash
# Build and test locally
docker build -t webapp .
docker run -p 8080:8080 webapp

# Run tests
npm test
```

### Deployment Commands

All deployments use the `compliance-cli` tool. For detailed usage:

```bash
./compliance-cli --help
```

#### Deploy to Development

```bash
# Automatic on push to main, or manually:
./compliance-cli dev
```

#### Deploy to QA

```bash
# Create a version tag
git tag v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

#### Promote to Production

```bash
# List QA releases
gcloud deploy releases list \
  --project=u2i-tenant-webapp-nonprod \
  --region=europe-west1 \
  --delivery-pipeline=webapp-qa-prod-pipeline

# Promote specific release
gcloud deploy releases promote \
  --release=qa-abc1234 \
  --delivery-pipeline=webapp-qa-prod-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod \
  --to-target=prod-gke
```

#### Deploy Preview Environment

```bash
# Automatic on PR creation/update
# Manual deployment for testing:
./compliance-cli preview --pr-number 123
```

## 📋 Compliance Checklist

Before each deployment, ensure:

- [ ] All containers have resource limits
- [ ] Security contexts are properly configured
- [ ] Images are from approved registries
- [ ] Secrets are managed via Secret Manager
- [ ] Network policies are in place
- [ ] Audit logging is enabled

## 🆘 Support

- **Team Lead**: webapp-team@u2i.com
- **Security Issues**: security-team@u2i.com
- **Platform Support**: platform-team@u2i.com
- **Compliance Questions**: compliance@u2i.com

## Testing PR Number Fix

Timestamp: 20250902-201337
Testing that preview deployments now correctly use the PR number from the trigger.
