# WebApp Team - Compliant Application Repository

This repository contains the WebApp Team's application deployment infrastructure following ISO 27001, SOC 2 Type II, and GDPR compliance requirements.

## 🏗️ Repository Structure

```
webapp-team-app/
├── .github/workflows/         # CI/CD workflows (GitHub Actions)
├── deploy/                    # Deployment configurations
│   ├── clouddeploy/          # Google Cloud Deploy pipelines
│   └── skaffold/             # Skaffold build configurations
├── docs/                      # Documentation
│   └── deployment/           # Deployment guides
├── k8s/                       # Kubernetes manifests
│   ├── base/                 # Base application manifests
│   ├── overlays/             # Environment-specific overlays
│   └── profiles/             # Resource profiles
├── scripts/                   # Utility scripts
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

## 🚀 Deployment Workflow

### Development Flow
1. **Feature branch** → Create PR
2. **Automated checks** → Compliance validation, security scanning
3. **Code review** → Team approval required
4. **Merge to main** → Auto-deploy to non-production

### Production Flow  
1. **Production release** → Manual promotion from non-prod
2. **Security review** → Automated compliance checks
3. **Approval gate** → Security team approval required
4. **Production deployment** → With full audit trail

## 🔧 Getting Started

### Prerequisites
- Access to `u2i-tenant-webapp` GCP project
- Membership in `webapp-team@u2i.com` Google Group
- GitHub repository access with proper branch protection

### Local Development
```bash
# Build and test locally
docker build -t webapp .
docker run -p 8080:8080 webapp

# Deploy to non-production  
gcloud deploy releases create dev-$(date +%Y%m%d-%H%M%S) \
  --project=u2i-tenant-webapp \
  --region=europe-west1 \
  --delivery-pipeline=webapp-delivery-pipeline \
  --source=.
```

### Environment Promotion
```bash
# Promote to production (requires approval)
gcloud deploy releases promote \
  --project=u2i-tenant-webapp \
  --region=europe-west1 \
  --delivery-pipeline=webapp-delivery-pipeline \
  --release=RELEASE_NAME \
  --to-target=prod-gke
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

## Deployment Status

Last deployment triggered after workload identity fix.
