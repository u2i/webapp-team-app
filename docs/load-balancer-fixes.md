# Load Balancer Configuration Fixes

This document describes the fixes applied to make the L4 TCP proxy load balancer work correctly with the webapp.

## Issues Found and Fixed

### 1. Health Check Port
**Issue**: The Config Connector health check was configured on port 80, but the pods listen on port 8080.

**Fix**: Updated `k8s-clean/overlays/nonprod/config-connector-resources.yaml`:
```yaml
tcpHealthCheck:
  port: 8080  # Changed from 80
```

### 2. NEG Attachment to Backend Service
**Issue**: Network Endpoint Groups (NEGs) created by GKE were not automatically attached to the Config Connector backend service.

**Fix**: Implemented autoneg controller with Workload Identity:
- Added autoneg controller deployment in Terraform (`autoneg-deploy.tf`)
- Updated service annotation to use `controller.autoneg.dev/neg`
- No service account keys required - uses Workload Identity

### 3. Config Connector Project Resolution
**Issue**: Config Connector was incorrectly using the namespace name as the project ID for some resources.

**Workaround**: All Config Connector resources must include explicit project annotation:
```yaml
annotations:
  cnrm.cloud.google.com/project-id: u2i-tenant-webapp
```

## Architecture

The load balancer setup now works as follows:

1. **GKE creates NEGs**: The `cloud.google.com/neg` annotation on the Service tells GKE to create zonal NEGs
2. **Autoneg attaches NEGs**: The `controller.autoneg.dev/neg` annotation tells autoneg which backend service to attach the NEGs to
3. **Config Connector manages LB**: All other load balancer components (SSL cert, health check, backend service, etc.) are managed by Config Connector

## Manual Steps No Longer Required

With autoneg controller deployed, you no longer need to:
- Manually attach NEGs to backend services
- Run any post-deployment scripts
- Manage NEG lifecycle

## Verification

To verify the setup is working:

```bash
# Check autoneg controller is running
kubectl get pods -n autoneg-system

# Check NEGs are attached to backend
gcloud compute backend-services describe webapp-dev-backend \
  --global --project=u2i-tenant-webapp

# Test the endpoint
curl https://dev.webapp.u2i.dev/
```