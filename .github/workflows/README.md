# GitHub Actions Workflows

## Active Workflows

### Continuous Integration
- **validate-pipelines.yml** - Validates Cloud Deploy pipeline configurations on PR
- **ci-compliance.yml** - Runs compliance and security checks on PR (currently disabled - paths don't exist)

### Continuous Deployment
- **cd-dev.yml** - Deploys to dev on push to main
- **cd-qa.yml** - Deploys to QA on tag push (v*) or manual trigger
- **cd-prod-promote.yml** - Promotes QA release to production (manual)

### Maintenance
- **cleanup-old-previews.yml** - Cleans up old preview environments (daily/manual)
- **cd-status.yml** - Updates deployment status dashboard (hourly/manual)

## Deprecated Workflows
These workflows appear to be redundant or unused:
- **cd-deploy.yml** - Generic deployment (replaced by specific env workflows)
- **cd-promote.yml** - Generic promotion (replaced by cd-prod-promote.yml)
- **deploy-qa-prod.yml** - Old QA/Prod deployment (replaced by cd-qa.yml)
- **production-promotion.yml** - Duplicate of cd-prod-promote.yml

## Workflow Triggers

| Workflow | Push to main | PR | Tag | Schedule | Manual |
|----------|-------------|----|----|----------|---------|
| cd-dev.yml | ✅ | | | | |
| cd-qa.yml | | | ✅ | | ✅ |
| cd-prod-promote.yml | | | | | ✅ |
| validate-pipelines.yml | | ✅ | | | |
| ci-compliance.yml | | ✅ | | | |
| cleanup-old-previews.yml | | | | ✅ | ✅ |
| cd-status.yml | | | | ✅ | ✅ |