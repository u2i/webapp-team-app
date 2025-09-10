# Infrastructure Components

This directory contains cluster-wide infrastructure components that need to be applied separately from application deployments.

## External Secrets Operator

**Note**: External Secrets are used for production environments. Preview environments use secretGenerator for simplicity.

### Prerequisites
1. External Secrets Operator must be installed in the cluster
2. Workload Identity must be configured for webapp service accounts

### Production Setup

For production environments that need to sync secrets from Google Secret Manager:

```bash
# Apply cluster-wide secret store (one-time setup)
kubectl apply -f cluster-secret-store.yml

# Verify the ClusterSecretStore is ready
kubectl get clustersecretstore gcp-secret-manager -o yaml
```

Look for `status.conditions[?(@.type=="Ready")].status: "True"`

### Preview Environment Approach

Preview environments use Kustomize `secretGenerator` instead of External Secrets for:
- **Simplicity**: No dependency on External Secrets Operator
- **Speed**: Faster deployment without waiting for secret sync
- **Testing**: Hardcoded test values sufficient for POC testing

The secret is generated directly in the preview deployment configuration.