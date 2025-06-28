# Direct Access via VPN (No Port Forwarding)

## Option 1: VPN to GKE Cluster Network

### A. GKE with Private Nodes + Cloud VPN/Interconnect
```bash
# Your VPN gives you access to the cluster's network
# You can directly access:

# Service ClusterIP 
curl http://10.96.10.45  # The service's cluster IP

# Service DNS (if VPN includes DNS forwarding)
curl http://webapp-service.nonprod-preview-123-preview.svc.cluster.local

# Pod IPs directly
curl http://10.244.2.15:8080  # Direct to pod
```

### B. Configure VPN to Route Cluster CIDR
```bash
# Example: If your cluster uses these CIDRs:
# - Pod CIDR: 10.244.0.0/16
# - Service CIDR: 10.96.0.0/16

# Add routes in your VPN config to forward this traffic to GKE
```

## Option 2: Internal Load Balancer (Easiest)

Create one internal LB per preview or shared:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
    # Optional: Use specific subnet
    networking.gke.io/internal-load-balancer-subnet: "preview-subnet"
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
```

**Result**: Gets IP like `10.128.0.50` accessible via VPN

## Option 3: NodePort + Internal Node IPs

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
    nodePort: 30123
```

**Access via any node's private IP**:
```bash
# Get node IPs
kubectl get nodes -o wide

# Access through VPN
curl http://10.128.0.2:30123  # Any node IP works
```

## Option 4: Ingress with Internal IP

Use nginx-ingress with internal LB:

```bash
# Install nginx-ingress with internal LB
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --set controller.service.annotations."networking\.gke\.io/load-balancer-type"="Internal"
```

Then use normal ingress resources:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: preview-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: preview-123.internal
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-service
            port:
              number: 80
```

## Option 5: ExternalName Service (DNS Alias)

Create DNS-friendly names:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: preview-123
  namespace: default  # Or a "directory" namespace
spec:
  type: ExternalName
  externalName: webapp-service.nonprod-preview-123-preview.svc.cluster.local
```

**Now accessible as**: `preview-123.default.svc.cluster.local`

## Option 6: CoreDNS Rewrite

Add custom DNS entries to CoreDNS:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        # ... existing config ...
        
        # Custom preview domains
        file /etc/coredns/custom.db preview.internal {
            reload
        }
    }
  custom.db: |
    preview.internal.     IN SOA sns.dns.icann.org. noc.dns.icann.org. 2015082541 7200 3600 1209600 3600
    
    ; Preview environments
    preview-123.preview.internal.  IN A 10.96.10.45  ; Service ClusterIP
    preview-456.preview.internal.  IN A 10.96.10.67
```

## Recommended Setup: Hybrid Approach

**1. Shared Internal Load Balancer** (One-time setup):

```bash
# Create a shared preview namespace
kubectl create namespace preview-router

# Deploy nginx router with internal LB
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: preview-router
  namespace: preview-router
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
  selector:
    app: preview-router
  ports:
  - port: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: preview-router
data:
  default.conf: |
    server {
      listen 80;
      
      # Route by subdomain
      server_name ~^(?<preview>.+)\.preview\.internal$;
      
      location / {
        resolver kube-dns.kube-system.svc.cluster.local;
        proxy_pass http://webapp-service.nonprod-\$preview-preview.svc.cluster.local;
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: preview-router
  namespace: preview-router
spec:
  replicas: 2
  selector:
    matchLabels:
      app: preview-router
  template:
    metadata:
      labels:
        app: preview-router
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
          name: nginx-config
EOF
```

**2. DNS Setup** (In your corporate DNS or /etc/hosts):
```
10.128.0.50  *.preview.internal  # The internal LB IP
```

**3. Access Pattern**:
```bash
# Via VPN, access any preview directly:
curl http://preview-123.preview.internal
curl http://preview-456.preview.internal
```

## Comparison Table

| Method | Setup Complexity | Cost | URL Format | Pros |
|--------|-----------------|------|------------|------|
| Direct ClusterIP | Hard | Free | `10.96.x.x` | No infrastructure |
| Internal LB | Easy | $18/mo | `10.128.x.x` | Simple, reliable |
| NodePort | Easy | Free | `node-ip:30xxx` | Works immediately |
| Shared Internal LB | Medium | $18/mo total | `preview-123.internal` | Best UX |
| Ingress Internal | Medium | $18/mo | `preview-123.internal` | Feature-rich |

## Quick Implementation

For fastest setup with good UX:

```bash
# 1. Update service to Internal LoadBalancer
kubectl patch svc webapp-service -n nonprod-preview-123-preview -p '
spec:
  type: LoadBalancer
  annotations:
    networking.gke.io/load-balancer-type: "Internal"'

# 2. Get the internal IP (wait ~1 minute)
kubectl get svc webapp-service -n nonprod-preview-123-preview

# 3. Access via VPN
curl http://10.128.0.50  # The internal IP
```

Or for zero cost, use NodePort and access via `node-ip:nodeport`.