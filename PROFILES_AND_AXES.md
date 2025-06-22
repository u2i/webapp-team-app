# How Profiles Fit into Boundary-Stage-Tier Framework

## The Four Axes

1. **Boundary** - Security/compliance boundary (which GCP project)
   - `prod` - Production project with hardened controls
   - `nonprod` - Non-production project with relaxed controls

2. **Stage** - What humans interact with (the instance)
   - `dev`, `qa`, `staging`, `preprod`, `prod`, `preview-*`

3. **Tier** - Infrastructure resource sizing
   - `standard` - Balanced resources (2 replicas, 256Mi/100m)
   - `perf` - High performance (5 replicas, 1Gi/1000m)
   - `ci` - Minimal for testing (1 replica, 128Mi/50m)
   - `preview` - Minimal for PR previews (1 replica, 64Mi/25m)

4. **Mode** - Runtime configuration (application behavior)
   - `production` - Optimized, caching enabled
   - `development` - Debug logging, hot reload
   - `test` - Test data, mocks enabled

## Where Profiles Fit

**Profiles are implementation details**, not axes. They're how we technically achieve the desired configuration for each axis combination.

### Profile Types in Our System

1. **Skaffold Profiles** - Control which Kubernetes manifests to deploy
   - Maps to overlays and resource configurations
   - Example: `tier-standard`, `tier-perf`, `preview-lightweight`

2. **Kustomize Overlays** - Compose the actual Kubernetes resources
   - Combine base + modifications for specific needs
   - Example: `overlays/dynamic-deploy`, `overlays/preview`

3. **Application Profiles** - Runtime configuration (the Mode axis)
   - Set via environment variables or config files
   - Example: `RAILS_ENV=production`, `NODE_ENV=development`

## The Mapping

```
User Intent                    →  Technical Implementation
--------------------------------  -------------------------------
boundary=nonprod               →  GCP Project: u2i-tenant-webapp
stage=qa                       →  Namespace: nonprod-qa-standard
tier=perf                      →  Kustomize: profiles/tier-perf
mode=production               →  Env Var: APP_MODE=production

Full namespace: nonprod-qa-perf
```

## Examples

### 1. Development Environment
```bash
./deploy-boundary-stage-tier.sh nonprod dev standard development
```
- **Boundary**: nonprod (uses nonprod GCP project)
- **Stage**: dev (developers use this)
- **Tier**: standard (normal resources)
- **Mode**: development (debug logging)
- **Implementation**: 
  - Skaffold profile: `non-prod`
  - Kustomize: `overlays/dynamic-deploy` + `profiles/tier-standard`
  - Namespace: `nonprod-dev-standard`

### 2. Performance Testing
```bash
./deploy-boundary-stage-tier.sh nonprod staging perf test
```
- **Boundary**: nonprod (safe to load test)
- **Stage**: staging (staging environment)
- **Tier**: perf (high resources for load testing)
- **Mode**: test (test configuration)
- **Implementation**:
  - Skaffold profile: `non-prod`
  - Kustomize: `overlays/dynamic-deploy` + `profiles/tier-perf`
  - Namespace: `nonprod-staging-perf`

### 3. PR Preview
```bash
./deploy-boundary-stage-tier.sh nonprod preview-123 preview development
```
- **Boundary**: nonprod (ephemeral environment)
- **Stage**: preview-123 (PR #123)
- **Tier**: preview (minimal resources)
- **Mode**: development (for testing)
- **Implementation**:
  - Skaffold profile: `non-prod` (required by Cloud Deploy)
  - Kustomize: `overlays/dynamic-preview-gce` + `profiles/tier-preview`
  - Namespace: `nonprod-preview-123-preview`
  - Special: No static IP/cert for fast startup

### 4. Production
```bash
./deploy-boundary-stage-tier.sh prod prod standard production
```
- **Boundary**: prod (production GCP project)
- **Stage**: prod (live site)
- **Tier**: standard (normal resources)
- **Mode**: production (optimized)
- **Implementation**:
  - Skaffold profile: `prod` (if we had separate pipeline)
  - Kustomize: `overlays/dynamic-deploy` + `profiles/tier-standard`
  - Namespace: `prod-prod-standard`

## Why This Separation Matters

1. **Flexibility**: You can run production mode in dev tier for debugging
2. **Cost Control**: Use preview tier for all ephemeral environments
3. **Safety**: Boundary ensures you can't accidentally deploy to prod project
4. **Clarity**: Each axis has one job, no overlap or confusion

## Current Limitation

Cloud Deploy pipeline currently requires a specific profile name (`non-prod`), so we can't dynamically select Skaffold profiles. Instead, we:
1. Always use the `non-prod` profile
2. Vary the Kustomize overlays within that profile
3. Use deploy parameters to customize per environment

## Future Enhancement

Ideally, Cloud Deploy would support dynamic profile selection:
```yaml
# In delivery pipeline
profiles: ["tier-${TIER}"]  # Would select based on parameter
```

Until then, we compose configurations within the required profile structure.