# AlloyDB Integration with IAM Authentication

This document describes the AlloyDB setup for the webapp application using IAM authentication and the AlloyDB Auth Proxy.

## Architecture Overview

```
┌─────────────┐     ┌──────────────────┐     ┌──────────────┐
│   Webapp    │────►│  Auth Proxy      │────►│   AlloyDB    │
│  Container  │     │  Sidecar         │     │   Instance   │
│ (localhost) │     │ (IAM Auth)       │     │ (10.152.0.2) │
└─────────────┘     └──────────────────┘     └──────────────┘
```

## Key Components

### 1. AlloyDB Instance
- **Cluster**: `webapp-nonprod-alloydb`
- **Instance**: `webapp-nonprod-alloydb-primary`
- **Region**: `europe-west1`
- **IP Address**: `10.152.0.2` (Private Service Access)
- **Port**: `5433` (AlloyDB native port)
- **Database**: `webapp_dev`, `webapp_qa`, `webapp_staging`
- **IAM User**: `webapp-k8s@u2i-tenant-webapp-nonprod.iam`

### 2. AlloyDB Auth Proxy Sidecar
- **Image**: `gcr.io/alloydb-connectors/alloydb-auth-proxy:latest`
- **Configuration**: Native Kubernetes sidecar (initContainer with restartPolicy: Always)
- **Local Port**: `5432`
- **Authentication**: IAM via Workload Identity
- **Connection**: Handles SSL/TLS encryption to AlloyDB

### 3. Network Configuration

#### Network Policy Rules
```yaml
egress:
  # Metadata server for Workload Identity tokens
  - to:
    - ipBlock:
        cidr: 169.254.169.254/32
    ports:
    - protocol: TCP
      port: 80
  
  # AlloyDB Private Service Access
  - to:
    - ipBlock:
        cidr: 10.152.0.0/24
    ports:
    - protocol: TCP
      port: 5433  # AlloyDB native port
    - protocol: TCP
      port: 5432  # Alternative port
```

### 4. Workload Identity Setup
- **Kubernetes Service Account**: `webapp` in namespace `webapp-dev`
- **GCP Service Account**: `webapp-k8s@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com`
- **Binding**: `serviceAccount:u2i-tenant-webapp-nonprod.svc.id.goog[webapp-dev/webapp]`

## Database Connection Configuration

### Application Configuration
```javascript
// When using AlloyDB Auth Proxy
if (process.env.ALLOYDB_AUTH_PROXY === 'true') {
  const iamUser = `webapp-k8s@${PROJECT_ID}.iam`;
  const database = `webapp_${stage}`;
  // Connect to localhost with empty password (IAM auth)
  const databaseUrl = `postgresql://${iamUser}:@localhost:5432/${database}`;
  
  // Disable SSL as Auth Proxy handles encryption
  dbConfig.ssl = false;
}
```

### Environment Variables
```yaml
env:
- name: ALLOYDB_AUTH_PROXY
  value: "true"
- name: PROJECT_ID
  value: "u2i-tenant-webapp-nonprod"
- name: BOUNDARY
  value: "nonprod"
- name: STAGE
  value: "dev"
```

## Kubernetes Manifests

### Deployment with Auth Proxy Sidecar
```yaml
spec:
  template:
    spec:
      serviceAccountName: webapp
      automountServiceAccountToken: true
      initContainers:
      # Native sidecar pattern (Kubernetes 1.28+)
      - name: alloydb-auth-proxy
        image: gcr.io/alloydb-connectors/alloydb-auth-proxy:latest
        restartPolicy: Always  # Makes it a sidecar
        args:
        - "projects/u2i-tenant-webapp-nonprod/locations/europe-west1/clusters/webapp-nonprod-alloydb/instances/webapp-nonprod-alloydb-primary"
        - "--port=5432"
        - "--auto-iam-authn"
        securityContext:
          runAsNonRoot: true
          runAsUser: 2000
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "100m"
      containers:
      - name: webapp
        # ... main application container
```

### Migration Job
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: webapp-migration
  namespace: webapp-dev
spec:
  template:
    spec:
      serviceAccountName: webapp
      initContainers:
      - name: alloydb-auth-proxy
        # Same configuration as deployment
      containers:
      - name: migrate
        image: webapp:latest
        command: ["node", "migrate.js"]
        env:
        - name: ALLOYDB_AUTH_PROXY
          value: "true"
```

## Required IAM Permissions

### For webapp-k8s Service Account
```
roles/alloydb.client
roles/alloydb.databaseUser
roles/serviceusage.serviceUsageConsumer
```

### For terraform-shared Service Account (Infrastructure)
```
roles/alloydb.admin
roles/servicenetworking.networksAdmin
roles/compute.networkAdmin
```

### For Cloud Deploy (Manual Grant Required)
```bash
gcloud iam service-accounts add-iam-policy-binding \
  cloud-deploy-sa@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com \
  --member="serviceAccount:495368984538-compute@developer.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

## Testing the Integration

Run the integration test script:
```bash
./test-alloydb-integration.sh
```

This verifies:
- Pod health with Auth Proxy sidecars
- Database connectivity
- Application endpoints
- Network policies
- Workload Identity
- AlloyDB instance status

## Troubleshooting

### Common Issues and Solutions

1. **Auth Proxy Timeout to Metadata Server**
   - **Symptom**: `dial tcp 169.254.169.254:80: i/o timeout`
   - **Solution**: Add metadata server to network policy egress rules

2. **Connection Timeout to AlloyDB**
   - **Symptom**: `dial tcp 10.152.0.2:5433: i/o timeout`
   - **Solution**: Add AlloyDB IP range to network policy egress rules

3. **SSL Connection Error**
   - **Symptom**: `The server does not support SSL connections`
   - **Solution**: Disable SSL in database config when using Auth Proxy

4. **IAM Authentication Failure**
   - **Symptom**: `permission denied for database`
   - **Solution**: Ensure `alloydb.iam_authentication` flag is enabled on instance

5. **Wrong Username Format**
   - **Symptom**: Authentication fails with IAM user
   - **Solution**: Use format `webapp-k8s@PROJECT_ID.iam` (not just `@nonprod`)

### Useful Commands

```bash
# Check Auth Proxy logs
kubectl logs <pod-name> -c alloydb-auth-proxy -n webapp-dev

# Test connection via test-proxy pod
kubectl exec test-proxy -c psql -n webapp-dev -- \
  psql -h localhost -p 5432 \
  -U "webapp-k8s@u2i-tenant-webapp-nonprod.iam" \
  -d webapp_dev -c "SELECT current_user;"

# Check AlloyDB instance status
gcloud alloydb instances describe webapp-nonprod-alloydb-primary \
  --cluster=webapp-nonprod-alloydb \
  --region=europe-west1 \
  --project=u2i-tenant-webapp-nonprod

# Verify Workload Identity binding
gcloud iam service-accounts get-iam-policy \
  webapp-k8s@u2i-tenant-webapp-nonprod.iam.gserviceaccount.com
```

## Migration from Neon

The application automatically detects and uses AlloyDB when:
1. `ALLOYDB_AUTH_PROXY=true` environment variable is set
2. Auth Proxy sidecar is running
3. Network policies allow connection

No code changes required beyond the database configuration logic already implemented.

## Security Considerations

- **No passwords**: IAM authentication eliminates password management
- **Encrypted in transit**: Auth Proxy handles TLS to AlloyDB
- **Network isolated**: Private Service Access, no public IPs
- **Least privilege**: Service accounts have minimal required permissions
- **Audit logging**: All connections logged via Cloud Audit Logs

## Cost Optimization

Current nonprod configuration (minimal for demo):
- **Instance**: 1 vCPU, 4GB RAM, 10GB storage
- **No read replicas**
- **No automated backups** (can be enabled for production)
- **Regional availability** (can be zonal for dev/test)

## Future Enhancements

- [ ] Add read replicas for high availability
- [ ] Enable automated backups for production
- [ ] Implement connection pooling optimization
- [ ] Add monitoring and alerting
- [ ] Create separate databases per preview environment
- [ ] Implement database user per service pattern