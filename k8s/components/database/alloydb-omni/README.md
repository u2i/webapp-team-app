# AlloyDB Omni Component

This component provides a single-instance AlloyDB Omni database for preview and development environments.

> **Note**: This component is preserved for reference but not currently used in preview environments. 
> Preview environments now use the shared boundary-wide AlloyDB instance with PR-specific databases.
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

## How to Enable AlloyDB Omni for an Environment

To use AlloyDB Omni instead of shared AlloyDB:

1. **Add the component to your kustomization.yml**:
   ```yaml
   components:
   - ../../../components/database/alloydb-omni
   ```

2. **Add the database password secret**:
   ```yaml
   resources:
   - db-password-secret.yml
   ```

3. **Configure environment variables**:
   ```yaml
   - name: DATABASE_HOST
     value: al-alloydb-preview-rw-ilb
   - name: DATABASE_USER
     value: postgres
   - name: DATABASE_PASSWORD
     valueFrom:
       secretKeyRef:
         name: db-pw-alloydb-preview
         key: alloydb-preview
   - name: DATABASE_SSL_MODE
     value: disable
   ```

4. **Remove AlloyDB Auth Proxy init container**:
   ```yaml
   - op: remove
     path: /spec/template/spec/initContainers/0
   ```

5. **Add network policy for AlloyDB Omni pods**:
   ```yaml
   - op: add
     path: /spec/egress/-
     value:
       to:
       - podSelector:
           matchLabels:
             alloydbomni.internal.dbadmin.goog/dbcluster: alloydb-preview
       ports:
       - protocol: TCP
         port: 5432
   ```

## Prerequisites

- AlloyDB Omni Operator must be installed in the cluster
- PodSecurity policy must be set to "baseline" (not "restricted")
- Sufficient resources: minimum 4Gi memory per instance
