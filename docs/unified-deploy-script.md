# Unified Deploy Script

This document describes the unified deployment script that handles all environments.

## Usage

```bash
./scripts/deploy.sh <environment> [options]
```

## Environments

- `dev` - Development environment (auto-deploys on merge to main)
- `preview` - Preview environment for pull requests
- `qa` - QA environment (deploys on version tags)
- `prod` - Production environment (requires promotion from QA)

## Options

- `--pr-number <number>` - PR number for preview deployments
- `--release <name>` - Override the auto-generated release name
- `--promote` - For production: promote an existing QA release
- `--help` - Show usage information

## Examples

### Development Deployment
```bash
# Automatically triggered on merge to main
./scripts/deploy.sh dev
```

### Preview Deployment
```bash
# Automatically triggered on PR creation/update
./scripts/deploy.sh preview --pr-number 123

# Or if PR number is in /workspace/pr_number.txt
./scripts/deploy.sh preview
```

### QA Deployment
```bash
# Automatically triggered on version tags (v*)
./scripts/deploy.sh qa
```

### Production Promotion
```bash
# Manually promote a QA release to production
./scripts/deploy.sh prod --promote --release qa-abc123
```

## Environment Variables

The script requires these environment variables:
- `PROJECT_ID` - GCP project ID
- `REGION` - GCP region (e.g., europe-west1)
- `COMMIT_SHA` - Full git commit SHA
- `SHORT_SHA` - Short git commit SHA (first 7 characters)
- `TAG_NAME` - Git tag name (only for QA deployments)

## Implementation Details

### Parameter Handling

All deployment parameters are passed via the `--deploy-parameters` flag to maintain consistency and explicit configuration. This includes:

- Namespace configuration
- Environment settings
- API URLs
- Domain names
- Certificate configuration
- Service naming

### Image Tagging

- **Dev**: `dev-${COMMIT_SHA}`
- **Preview**: `preview-${COMMIT_SHA}`
- **QA**: `qa-${COMMIT_SHA}`
- **Prod**: Uses the QA image via promotion

### Release Naming

- **Dev**: `dev-${SHORT_SHA}`
- **Preview**: `preview-pr${PR_NUMBER}-${SHORT_SHA}`
- **QA**: `qa-${SHORT_SHA}`
- **Prod**: Promotes existing QA release

## Benefits

1. **Single Source of Truth**: One script to maintain instead of four
2. **Consistent Logic**: All environments follow the same deployment pattern
3. **Explicit Parameters**: All configuration is visible and auditable
4. **Reduced Duplication**: Common logic is shared across environments
5. **Easier Testing**: Can test all deployment paths with one script

## Migration from Individual Scripts

The unified script replaces:
- `scripts/deploy-dev.sh`
- `scripts/deploy-preview.sh`
- `scripts/deploy-qa.sh`
- `scripts/promote-to-prod.sh` (partially - for the deploy command)

Cloud Build configurations have been updated to use the unified script with appropriate environment arguments.