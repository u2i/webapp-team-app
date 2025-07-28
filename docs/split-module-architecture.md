# Split Module Architecture

## Overview

This document explains the split module architecture implemented to work around Skaffold bug #7207, which causes deployment timeouts when Config Connector resources are deployed with >3 total resources.

## Problem

Skaffold uses different tracking modes based on resource count:
- **Single tracking**: ≤3 resources - works fine
- **Dual tracking**: >3 resources - fails with Config Connector CRDs

The bug causes a 10-minute timeout when trying to check the status of Config Connector resources (Certificate, CertificateMapEntry) in dual tracking mode.

## Solution

Split deployments into three separate Skaffold modules:

1. **Namespace Module**: Creates namespace first (required for all resources)
2. **App Module**: Deploys Kubernetes resources with status checking enabled
3. **KCC Module**: Deploys Config Connector resources with status checking disabled

## Implementation Details

### File Structure

```
skaffold-<env>-split.yaml    # Split configuration for each environment
k8s-clean/
  overlays/
    <env>-gateway/           # App resources (deployment, service, etc.)
  kcc/
    overlays/
      <env>-gateway/         # Config Connector resources (certificates)
```

### Module Configuration

Each environment follows the same pattern:

```yaml
# 1. Namespace module (deployed first)
apiVersion: skaffold/v4beta13
kind: Config
metadata:
  name: webapp-namespace
manifests:
  rawYaml:
  - k8s-clean/namespace/namespace-<type>.yaml
deploy:
  kubectl:
    flags:
      apply: ["--server-side", "--force-conflicts"]
profiles:
- name: <profile-name>

---
# 2. App module (Kubernetes resources)
apiVersion: skaffold/v4beta13
kind: Config
metadata:
  name: webapp-<env>-app
build:
  artifacts:
  - image: <image-path>
manifests:
  kustomize:
    paths:
    - k8s-clean/overlays/<env>-gateway
deploy:
  kubectl:
    flags:
      apply: ["--server-side", "--force-conflicts"]
  statusCheck: true  # ✅ Status checking enabled
profiles:
- name: <profile-name>

---
# 3. KCC module (Config Connector resources)
apiVersion: skaffold/v4beta13
kind: Config
metadata:
  name: webapp-<env>-kcc
manifests:
  kustomize:
    paths:
    - k8s-clean/kcc/overlays/<env>-gateway
deploy:
  kubectl:
    flags:
      apply: ["--server-side", "--force-conflicts"]
  statusCheck: false  # ❌ Status checking disabled
profiles:
- name: <profile-name>
```

## Environment Configurations

| Environment | Skaffold File | Profile | Status |
|------------|---------------|---------|--------|
| Preview | skaffold-preview-split.yaml | preview-all | ✅ Tested |
| Dev | skaffold-dev-split.yaml | dev | ✅ Ready |
| QA | skaffold-qa-prod-split.yaml | qa | ✅ Ready |
| Production | skaffold-qa-prod-split.yaml | prod | ✅ Ready |

## Benefits

1. **Avoids Skaffold Bug**: Config Connector resources isolated with status checking disabled
2. **Enables PodDisruptionBudget**: Can now add PDB to production without triggering the bug
3. **Maintains Status Checking**: App resources still properly monitored
4. **Consistent Pattern**: All environments follow the same architecture

## Testing

Preview environment has been successfully tested with this architecture. The deployment:
1. Creates namespace first
2. Deploys app and KCC resources
3. No timeout issues
4. Certificate provisioning works correctly