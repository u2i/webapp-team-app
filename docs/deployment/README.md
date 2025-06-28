# Deployment Documentation

This directory contains all deployment-related documentation for the WebApp project.

## Quick Links

- [Main Deployment Guide](DEPLOYMENT_GUIDE.md) - Comprehensive deployment instructions
- [Developer Deployment Guide](DEVELOPER_DEPLOYMENT_TEST_GUIDE.md) - Guide for developers deploying to test environments
- [Stage Deployment Guide](STAGE_DEPLOYMENT_GUIDE.md) - Stage-specific deployment instructions
- [Deployment Overview](DEPLOYMENT.md) - High-level deployment architecture
- [Deployment Notes](DEPLOYMENT_NOTES.md) - Additional deployment notes and tips

## Deployment Structure

```
deploy/
├── clouddeploy/         # Google Cloud Deploy pipeline configurations
│   ├── main-pipeline.yaml
│   ├── stages-pipeline.yaml
│   └── clean-pipeline.yaml
│
└── skaffold/           # Skaffold build and deployment configurations
    ├── main.yaml       # Main Skaffold configuration
    ├── dev.yaml        # Development environment
    ├── qa.yaml         # QA environment
    ├── prod.yaml       # Production environment
    └── preview.yaml    # Preview deployments
```

## Key Concepts

### Environments
- **dev** - Development environment for continuous deployment
- **qa** - QA environment for testing tagged releases
- **preview** - Ephemeral environments for pull requests
- **prod** - Production environment with manual approval

### Deployment Patterns
- All environments use Google Cloud Deploy for orchestration
- Skaffold handles build and deployment operations
- Gateway API provides unified ingress across environments

## Common Tasks

### Deploy to Development
```bash
gcloud deploy releases create dev-$(git rev-parse --short HEAD) \
  --delivery-pipeline=webapp-pipeline \
  --region=europe-west1 \
  --skaffold-file=deploy/skaffold/dev.yaml
```

### Create Preview Environment
Preview environments are automatically created when pull requests are opened.

### Promote to Production
Production deployments require manual approval through Cloud Deploy console.

## Related Documentation

- [Load Balancer Configuration](../load-balancer-fixes.md)
- [Manual Fixes Guide](../manual-fixes-needed.md)