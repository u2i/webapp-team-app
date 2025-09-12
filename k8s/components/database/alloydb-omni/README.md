# AlloyDB Omni Component

This component provides a single-instance AlloyDB Omni database for preview and development environments.

## Resources Included

- **DBCluster**: AlloyDB Omni cluster with optimized settings for dev/preview
- **UserDefinedAuthentication**: pg_hba.conf configuration for local connections
- **Secret**: Database password (should be replaced with ExternalSecret in production)

## Configuration

The DBCluster is configured with:
- Single instance (no standbys)
- 4Gi memory / 250m CPU
- 5Gi persistent storage
- PostgreSQL 16.8.0
- Monitoring and logging disabled for cost savings

## Usage

Add to your kustomization:

```yaml
components:
- path/to/components/database/alloydb-omni
```

## Required Environment Variables

Your application should connect using:
- `DATABASE_HOST`: al-alloydb-preview-rw-ilb
- `DATABASE_USER`: postgres
- `DATABASE_PASSWORD`: (from secret)
- `DATABASE_NAME`: postgres
- `DATABASE_PORT`: 5432
- `DATABASE_SSL_MODE`: disable (for local connections)

## Network Policy

Ensure your network policy allows egress to the AlloyDB Omni pods:

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ${NAMESPACE}
    podSelector:
      matchLabels:
        app.kubernetes.io/name: al-alloydb-preview
  ports:
  - protocol: TCP
    port: 5432
```

## Cleanup

The DBCluster must be deleted using the two-phase deletion process:
1. Set `spec.isDeleted: true`
2. Wait for operator to clean up
3. Delete the namespace

This is handled automatically by the compliance-cli destroy command.