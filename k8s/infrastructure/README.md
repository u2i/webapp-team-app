# Infrastructure Components

This directory contains cluster-wide infrastructure components that need to be applied separately from application deployments.

## External Secrets Operator

### Prerequisites
1. External Secrets Operator must be installed in the cluster
2. Workload Identity must be configured for webapp service accounts

### Manual Setup Required

Apply the ClusterSecretStore manually (one-time setup):

```bash
kubectl apply -f cluster-secret-store.yml
```

This creates a cluster-wide secret store that can be used by all namespaces.

### Verification

Check that the ClusterSecretStore is ready:

```bash
kubectl get clustersecretstore gcp-secret-manager -o yaml
```

Look for `status.conditions[?(@.type=="Ready")].status: "True"`