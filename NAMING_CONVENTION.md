# Naming Convention: Boundary-Stage-Tier

## Overview

We use an orthogonal naming scheme that separates different concerns into independent axes:
- **Boundary**: Security/compliance boundary
- **Stage**: What humans interact with
- **Tier**: Resource sizing
- **Mode**: Runtime configuration

## Pattern: `<boundary>-<stage>-<tier>`

### Examples
- `nonprod-dev-standard` - Development environment with standard resources
- `nonprod-staging-perf` - Staging environment with performance tier
- `nonprod-preview-42-preview` - PR #42 preview with minimal resources
- `prod-preprod-standard` - Pre-production validation
- `prod-prod-perf` - Production with performance resources

## Axes Explained

### Boundary (Security Context)
| Value | Description | GCP Project |
|-------|-------------|-------------|
| `nonprod` | Non-production data, relaxed controls | `u2i-tenant-webapp` |
| `prod` | Customer data, hardened controls | `u2i-tenant-webapp-prod` |

### Stage (Instance)
| Value | Description | Allowed in Boundary |
|-------|-------------|---------------------|
| `dev` | Development | nonprod only |
| `qa` | QA testing | nonprod only |
| `staging` | Production-like testing | both |
| `preview-*` | PR previews | nonprod only |
| `preprod` | Final validation | prod only |
| `prod` | Live production | prod only |

### Tier (Resources)
| Value | CPU Request | Memory Request | Replicas |
|-------|-------------|----------------|----------|
| `standard` | 100m | 256Mi | 2 |
| `perf` | 1000m | 1Gi | 5 |
| `ci` | 50m | 128Mi | 1 |
| `preview` | 25m | 64Mi | 1 |

### Mode (Runtime)
| Value | Description | Example Use |
|-------|-------------|-------------|
| `production` | Production config | Optimized, caching enabled |
| `development` | Dev config | Debug mode, verbose logging |
| `test` | Test config | Mocks enabled, test data |

## Labels

All resources are labeled with:
```yaml
labels:
  app: webapp
  team: webapp-team
  boundary: nonprod|prod
  stage: dev|qa|staging|preprod|prod|preview-*
  tier: standard|perf|ci|preview
  mode: production|development|test
```

## Deployment

### Using the deployment script:
```bash
# Deploy dev environment
./deploy-boundary-stage-tier.sh nonprod dev

# Deploy staging with performance tier
./deploy-boundary-stage-tier.sh nonprod staging perf

# Deploy PR preview
./deploy-boundary-stage-tier.sh nonprod preview-123 preview

# Deploy production
./deploy-boundary-stage-tier.sh prod prod standard production
```

### Resource naming:
- Static IPs: `webapp-<stage>-ip`
- Certificates: `webapp-cert-<stage>`
- Ingresses: `webapp-ingress-<stage>`
- Namespaces: `<boundary>-<stage>-<tier>`

## Benefits

1. **Clear separation**: Each axis represents one concern
2. **Flexible combinations**: Mix and match as needed
3. **Easy filtering**: Query by any label
4. **Predictable naming**: Consistent patterns
5. **No ambiguity**: Clear what each environment is for

## Migration Notes

- Legacy `environment` label kept for compatibility
- Existing deployments work unchanged
- New deployments should use boundary-stage-tier pattern