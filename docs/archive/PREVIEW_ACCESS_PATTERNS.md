# Preview Environment Access Patterns

## Problem
Preview environments need fast startup but GCP Load Balancers are slow:
- Load Balancer provisioning: 2-5 minutes
- Static IP allocation: 1-2 minutes  
- SSL certificate: 5-10 minutes
- Total: Up to 17 minutes before accessible

## Solution Options

### 1. Port Forward (Fastest - 0 minutes)
**No load balancer, no ingress, just the service**

```bash
# Deploy
./deploy-boundary-stage-tier.sh nonprod preview-123 preview

# Access locally
kubectl port-forward -n webapp-team svc/webapp-service 8080:80

# Browse to http://localhost:8080
```

**Pros:**
- Instant access
- No external infrastructure
- Most secure (no public endpoint)
- Zero cost

**Cons:**
- Only accessible from kubectl client
- Not shareable with others
- Requires cluster access

### 2. Shared Preview Ingress (Fast - 30 seconds)
**One ingress for all previews, path-based routing**

```yaml
# Shared ingress (deploy once)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: preview-router
spec:
  rules:
  - host: preview.webapp.u2i.dev
    http:
      paths:
      - path: /pr-123
        backend:
          service:
            name: webapp-service-pr-123
      - path: /pr-124
        backend:
          service:
            name: webapp-service-pr-124
```

Access: `http://preview.webapp.u2i.dev/pr-123`

**Pros:**
- Fast (reuses existing LB)
- Shareable URLs
- Low cost (one LB for all previews)

**Cons:**
- Requires path prefix handling in app
- Manual ingress updates (or automation)

### 3. Nginx Ingress Controller (Medium - 2 minutes)
**Requires nginx-ingress installation**

```bash
# Install nginx-ingress (one time)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Deploy with nginx ingress
./deploy-boundary-stage-tier.sh nonprod preview-123 preview
```

**Pros:**
- Faster than GCE ingress
- More features (rate limiting, auth)
- Single LB for all nginx ingresses

**Cons:**
- Requires nginx-ingress installation
- Still creates a LB (for nginx itself)

### 4. Cloud Run or App Engine (Alternative)
**Deploy previews outside Kubernetes**

```bash
# Deploy to Cloud Run
gcloud run deploy preview-123 \
  --image=europe-west1-docker.pkg.dev/u2i-tenant-webapp/webapp-images/webapp:latest \
  --platform=managed \
  --region=europe-west1 \
  --allow-unauthenticated
```

**Pros:**
- Very fast deployment
- Automatic HTTPS
- Scale to zero

**Cons:**
- Different platform
- May behave differently

## Recommended Approach

For PR previews, use **port-forwarding** for developers and **shared ingress** for stakeholder reviews:

1. **Developer testing**: Port forward
   - Instant access
   - Full debugging capabilities
   - No wait time

2. **Stakeholder review**: Shared preview ingress
   - Deploy PR as path on preview.webapp.u2i.dev
   - Single load balancer serves all previews
   - 30 second deployment time

3. **Production-like testing**: Full ingress
   - Only for final validation
   - Accepts the wait time for full setup

## Implementation in Our System

Currently implemented:
- `overlays/preview-nodeport/` - NodePort service for port-forwarding
- `overlays/dynamic-preview-gce/` - Ephemeral GCE ingress (still has LB)

To implement shared preview ingress:
1. Deploy a single preview ingress
2. Update it with new paths for each PR
3. Or use a wildcard ingress with hostname routing

Example wildcard approach:
```yaml
spec:
  rules:
  - host: "*.preview.webapp.u2i.dev"
    http:
      paths:
      - path: /
        backend:
          service:
            name: webapp-service  # In PR-specific namespace
```

Then access via: `http://pr-123.preview.webapp.u2i.dev`