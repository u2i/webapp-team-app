# Shared Load Balancer with Per-Stage Configs

## Pattern 1: Port-Based Routing (Simplest)

One LoadBalancer service with different ports per stage:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: preview-router
  namespace: preview-router
spec:
  type: LoadBalancer
  ports:
  - name: preview-123
    port: 8123
    targetPort: 80
  - name: preview-124
    port: 8124
    targetPort: 80
  selector:
    app: preview-router

---
# Router deployment that proxies to different namespaces
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
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: preview-routes
```

**Access**: `http://preview.webapp.u2i.dev:8123`

## Pattern 2: Path-Based Routing (Better for Web Apps)

Single LoadBalancer + Nginx/HAProxy routing by path:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: preview-routes
  namespace: preview-router
data:
  default.conf: |
    # Route based on path prefix
    server {
      listen 80;
      
      # Preview 123
      location /preview-123/ {
        proxy_pass http://webapp-service.nonprod-preview-123-preview.svc.cluster.local/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Original-URI $request_uri;
      }
      
      # Preview 124  
      location /preview-124/ {
        proxy_pass http://webapp-service.nonprod-preview-124-preview.svc.cluster.local/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
      }
      
      # Default/health
      location / {
        return 200 'Preview Router\n';
      }
    }
```

**Access**: `http://preview.webapp.u2i.dev/preview-123/`

## Pattern 3: Subdomain Routing (Most Flexible)

Use wildcard DNS + Host header routing:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: preview-routes
  namespace: preview-router
data:
  default.conf: |
    # Route based on subdomain
    server {
      listen 80;
      server_name ~^(?<stage>.+)\.preview\.webapp\.u2i\.dev$;
      
      # Extract stage from subdomain and route
      location / {
        # Construct the internal service URL
        # preview-123.preview.webapp.u2i.dev → nonprod-preview-123-preview
        set $backend "webapp-service.nonprod-$stage-preview.svc.cluster.local";
        proxy_pass http://$backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Host $host;
      }
    }
```

**Access**: `http://preview-123.preview.webapp.u2i.dev`

## Pattern 4: Service Mesh (Istio/Linkerd)

Use VirtualService for advanced routing:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: preview-routing
spec:
  hosts:
  - preview.webapp.u2i.dev
  http:
  - match:
    - headers:
        stage:
          exact: preview-123
    route:
    - destination:
        host: webapp-service.nonprod-preview-123-preview.svc.cluster.local
  - match:
    - uri:
        prefix: /preview-124
    route:
    - destination:
        host: webapp-service.nonprod-preview-124-preview.svc.cluster.local
```

## Implementation Example: Dynamic Router

Here's a complete implementation that auto-discovers preview stages:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: router-script
  namespace: preview-router
data:
  update-routes.sh: |
    #!/bin/bash
    # Dynamically generate nginx config from existing namespaces
    
    cat > /etc/nginx/conf.d/default.conf <<EOF
    server {
      listen 80;
      server_name _;
      
    EOF
    
    # Find all preview namespaces
    for ns in $(kubectl get ns -l stage --no-headers | grep preview | awk '{print $1}'); do
      stage=$(kubectl get ns $ns -o jsonpath='{.metadata.labels.stage}')
      echo "  location /$stage/ {" >> /etc/nginx/conf.d/default.conf
      echo "    proxy_pass http://webapp-service.$ns.svc.cluster.local/;" >> /etc/nginx/conf.d/default.conf
      echo "    proxy_set_header Host \$host;" >> /etc/nginx/conf.d/default.conf
      echo "  }" >> /etc/nginx/conf.d/default.conf
      echo "" >> /etc/nginx/conf.d/default.conf
    done
    
    echo "}" >> /etc/nginx/conf.d/default.conf
    nginx -s reload

---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: route-updater
  namespace: preview-router
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: router-admin
          containers:
          - name: updater
            image: bitnami/kubectl:latest
            command: ["/scripts/update-routes.sh"]
            volumeMounts:
            - name: script
              mountPath: /scripts
          volumes:
          - name: script
            configMap:
              name: router-script
              defaultMode: 0755
```

## Comparison of Approaches

| Pattern | Pros | Cons | Best For |
|---------|------|------|----------|
| Port-based | Simple, no path rewriting | Port management, firewall rules | APIs, non-web services |
| Path-based | Single port, easy firewall | Path rewriting complexity | Web apps that handle base paths |
| Subdomain | Clean URLs, no ports/paths | DNS wildcard setup | Production-like previews |
| Service Mesh | Advanced routing, canary | Complex setup | Large installations |

## Quick Start: Path-Based Router

```bash
# 1. Create router namespace
kubectl create namespace preview-router

# 2. Deploy the router
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: preview-router
  namespace: preview-router
  annotations:
    external-dns.alpha.kubernetes.io/hostname: preview.webapp.u2i.dev
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: preview-router
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
        ports:
        - containerPort: 80
        volumeMounts:
        - name: routes
          mountPath: /etc/nginx/conf.d
          readOnly: true
      volumes:
      - name: routes
        configMap:
          name: preview-routes
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: preview-routes
  namespace: preview-router
data:
  default.conf: |
    server {
      listen 80;
      
      # Add routes here as needed
      location /preview-123/ {
        proxy_pass http://webapp-service.nonprod-preview-123-preview.svc.cluster.local/;
      }
      
      location / {
        return 200 'Preview Router - Available stages: /preview-123/\n';
      }
    }
EOF

# 3. Get the LoadBalancer IP
kubectl get svc preview-router -n preview-router
```

## Updating Routes

To add a new preview stage:

```bash
# Edit the ConfigMap
kubectl edit configmap preview-routes -n preview-router

# Or use kubectl patch
kubectl patch configmap preview-routes -n preview-router --type merge -p '
data:
  default.conf: |
    server {
      listen 80;
      
      location /preview-123/ {
        proxy_pass http://webapp-service.nonprod-preview-123-preview.svc.cluster.local/;
      }
      
      location /preview-456/ {
        proxy_pass http://webapp-service.nonprod-preview-456-preview.svc.cluster.local/;
      }
      
      location / {
        return 200 "Preview Router\n";
      }
    }'

# Restart nginx to pick up changes
kubectl rollout restart deployment preview-router -n preview-router
```

## Cost Savings

- **Individual LBs**: 10 previews × $18/month = $180/month
- **Shared LB**: 1 LB × $18/month = $18/month
- **Savings**: $162/month (90% reduction)