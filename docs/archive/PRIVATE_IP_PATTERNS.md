# Private IP Access Patterns for Preview Environments

## Option 1: ClusterIP Service (Lightest - 0 infrastructure)

The absolute lightest weight - just use the default Kubernetes service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: ClusterIP  # Default - internal only
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
```

**Access methods:**

### A. kubectl port-forward (For developers)
```bash
# Direct to pod
kubectl port-forward -n nonprod-preview-123-preview pod/webapp-xxxx 8080:8080

# Via service (more stable)
kubectl port-forward -n nonprod-preview-123-preview svc/webapp-service 8080:80

# Access at http://localhost:8080
```

### B. kubectl proxy (For API access)
```bash
# Start proxy
kubectl proxy --port=8001

# Access any service via:
# http://localhost:8001/api/v1/namespaces/nonprod-preview-123-preview/services/webapp-service:80/proxy/
```

### C. In-cluster access (For other services)
```bash
# From another pod in the cluster
curl http://webapp-service.nonprod-preview-123-preview.svc.cluster.local
```

## Option 2: Internal Load Balancer (Private VPC IP)

Gets a private IP within your VPC:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
```

**Provisioning time**: ~1 minute (faster than external)
**Access**: Via VPN, bastion host, or other GCP resources
**IP**: Private IP like 10.0.1.5

## Option 3: NodePort with Private Node IPs

If your nodes have private IPs:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30123  # Fixed port 30000-32767
```

**Access**: `http://<any-node-private-ip>:30123`

## Option 4: Headless Service (Direct Pod IPs)

For direct pod access:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-headless
spec:
  clusterIP: None  # Headless
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
```

**DNS returns pod IPs directly**:
```bash
# Returns all pod IPs
nslookup webapp-headless.nonprod-preview-123-preview.svc.cluster.local
```

## Comparison

| Option | Provisioning Time | Cost | Access Method | Use Case |
|--------|-------------------|------|---------------|----------|
| ClusterIP | Instant | Free | port-forward/proxy | Developer testing |
| Internal LB | ~1 min | $18/mo | VPN/Bastion | Team access |
| NodePort | Instant | Free | Node IP:port | CI/CD systems |
| Headless | Instant | Free | Direct pod IPs | Service mesh |

## Recommended Setup for Previews

**1. Use ClusterIP + Automation**:

```bash
#!/bin/bash
# preview-access.sh
NAMESPACE=$1
PORT=${2:-8080}

# Start port-forward in background
kubectl port-forward -n $NAMESPACE svc/webapp-service $PORT:80 &
PF_PID=$!

# Wait for port to be ready
sleep 2

# Open browser
open http://localhost:$PORT

# Keep running until Ctrl+C
wait $PF_PID
```

**2. Shared Bastion/Jump Host**:

```yaml
# Deploy once in cluster
apiVersion: apps/v1
kind: Deployment
metadata:
  name: preview-bastion
  namespace: preview-router
spec:
  replicas: 1
  selector:
    matchLabels:
      app: preview-bastion
  template:
    metadata:
      labels:
        app: preview-bastion
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: preview-routes

---
# Expose bastion with single Internal LB
apiVersion: v1
kind: Service
metadata:
  name: preview-bastion
  namespace: preview-router
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
  selector:
    app: preview-bastion
  ports:
  - port: 80
```

**Access all previews via**: `http://10.x.x.x/preview-123/`

## Cost Analysis

- **External LB**: $18/month + egress bandwidth
- **Internal LB**: $18/month (no egress charges)
- **ClusterIP**: $0 (free)
- **NodePort**: $0 (free)

## Security Benefits

1. **No public exposure** - Previews not accessible from internet
2. **VPN/IAP required** - Additional auth layer
3. **Network policies** - Can restrict inter-namespace traffic
4. **No DDoS risk** - Not publicly discoverable

## Access Patterns by User Type

### Developers
```bash
# Alias for quick access
alias preview='kubectl port-forward -n nonprod-preview-$1-preview svc/webapp-service ${2:-8080}:80'

# Usage
preview 123      # Port 8080
preview 456 9090 # Port 9090
```

### QA/Stakeholders (with VPN)
- Internal LB with DNS: `http://preview-123.internal.company.com`
- Bastion pattern: `http://preview-bastion.internal/preview-123/`

### CI/CD Systems
- Direct service URL: `webapp-service.nonprod-preview-123-preview.svc.cluster.local`
- No external dependency

## Recommended Implementation

For maximum simplicity and zero infrastructure:

```yaml
# Just use standard ClusterIP service
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: webapp-team
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
  # type: ClusterIP is default
```

Then update deploy script to show access instructions:

```bash
echo "Access instructions:"
echo "  kubectl port-forward -n $NAMESPACE svc/webapp-service 8080:80"
echo "  Then browse to: http://localhost:8080"
echo ""
echo "For team access, use VPN and internal bastion at:"
echo "  http://preview-bastion.internal/$(basename $NAMESPACE)/"
```

This gives you:
- **Instant deployment** (no infrastructure wait)
- **Zero cost** for the service
- **Complete security** (no public access)
- **Developer friendly** (simple port-forward)