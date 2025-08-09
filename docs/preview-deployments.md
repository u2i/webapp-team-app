# Preview Deployments with Custom Domains

This guide explains how to deploy preview environments with custom domains using Cloud Deploy.

## Overview

Preview deployments allow you to deploy feature branches or test versions to custom domains like:
- `foo.webapp.u2i.dev`
- `feature-xyz.webapp.u2i.dev`
- `pr-123.webapp.u2i.dev`

## Prerequisites

1. Access to the webapp GKE cluster
2. Cloud Deploy permissions in `u2i-tenant-webapp` project
3. DNS zone configured for `webapp.u2i.dev`

## Quick Start

### Deploy Preview Environment

```bash
# Deploy PR preview
./compliance-cli deploy preview --pr-number 123
# Creates: pr123.webapp.u2i.dev

# Note: PR number is required for preview deployments
# In CI/CD, this is automatically extracted from the PR
```

## Manual Deployment

For more control, you can use Cloud Deploy directly:

```bash
# Build and create release
gcloud deploy releases create "preview-foo-$(date +%Y%m%d%H%M%S)" \
  --delivery-pipeline=webapp-preview-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp \
  --skaffold-file=skaffold.yaml \
  --deploy-parameters="DOMAIN=foo.webapp.u2i.dev,PREVIEW_NAME=foo" \
  --to-target=preview-gke
```

## How It Works

1. **Cloud Deploy Parameters**: The `DOMAIN` and `PREVIEW_NAME` parameters are passed via `--deploy-parameters`
2. **Skaffold Profile**: Uses the `preview-gateway` profile which includes Gateway API resources
3. **Kustomize Substitution**: Cloud Deploy substitutes `${DOMAIN}` and `${PREVIEW_NAME}` in the manifests
4. **Gateway API**: HTTPRoute is created with the specified domain
5. **External DNS**: Automatically creates DNS records for the domain
6. **SSL Certificates**: Certificate Manager provisions SSL certificates automatically

## Architecture

```
┌─────────────────────┐
│   Cloud Deploy      │
│  (with parameters)  │
└──────────┬──────────┘
           │
           v
┌─────────────────────┐
│     Skaffold        │
│ (preview-gateway)   │
└──────────┬──────────┘
           │
           v
┌─────────────────────┐
│    Kustomize        │
│  (substitutions)    │
└──────────┬──────────┘
           │
           v
┌─────────────────────┐
│   Gateway API       │
│   (HTTPRoute)       │
└──────────┬──────────┘
           │
           v
┌─────────────────────┐
│  External DNS +     │
│  Cert Manager       │
└─────────────────────┘
```

## Cleanup

Preview deployments should be cleaned up when no longer needed:

```bash
# Delete the namespace
kubectl delete namespace webapp-preview-foo

# DNS records will be cleaned up automatically by External DNS
```

## Limitations

- All preview deployments share the same GKE cluster
- Domains must be subdomains of `webapp.u2i.dev`
- SSL certificates may take a few minutes to provision