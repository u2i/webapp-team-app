# NodePort with TLS/HTTPS Options

## Option 1: TLS Termination at Pod Level

**Configure your app to handle TLS directly:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: NodePort
  ports:
  - name: https
    port: 443
    targetPort: 8443  # App serves HTTPS
    nodePort: 30443
  selector:
    app: webapp

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      - name: webapp
        image: webapp:latest
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
          readOnly: true
        env:
        - name: TLS_CERT
          value: /etc/tls/tls.crt
        - name: TLS_KEY
          value: /etc/tls/tls.key
      volumes:
      - name: tls
        secret:
          secretName: webapp-tls
```

**Access**: `https://node-ip:30443` (with certificate warning)

## Option 2: TLS Sidecar Container

**Add nginx/envoy sidecar for TLS:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      # Main app (HTTP only)
      - name: webapp
        image: webapp:latest
        ports:
        - containerPort: 8080
      
      # TLS termination sidecar
      - name: tls-proxy
        image: nginx:alpine
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: tls
          mountPath: /etc/nginx/ssl
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: tls
        secret:
          secretName: webapp-tls
      - name: config
        configMap:
          name: nginx-tls-config

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-tls-config
data:
  default.conf: |
    server {
        listen 8443 ssl;
        ssl_certificate /etc/nginx/ssl/tls.crt;
        ssl_certificate_key /etc/nginx/ssl/tls.key;
        
        location / {
            proxy_pass http://localhost:8080;
            proxy_set_header X-Forwarded-Proto https;
        }
    }
```

## Option 3: Self-Signed Certificates (For Dev/Preview)

**Quick setup with self-signed certs:**

```bash
# Generate self-signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=preview.webapp.internal"

# Create secret
kubectl create secret tls webapp-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n nonprod-preview-123-preview
```

## Option 4: Let's Encrypt with NodePort (Complex)

**Possible but challenging because:**
- Let's Encrypt needs port 80/443 for validation
- NodePort uses high ports (30000-32767)
- Requires DNS-01 challenge instead

```yaml
# Using cert-manager with DNS-01
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: webapp-cert
spec:
  secretName: webapp-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  dnsNames:
  - preview-123.webapp.internal
  # DNS-01 challenge works with any port
```

## Option 5: TLS Passthrough Load Balancer

**Use a minimal TCP load balancer in front:**

```yaml
# Shared TLS terminator with NodePort backend
apiVersion: v1
kind: Service
metadata:
  name: tls-gateway
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
  ports:
  - name: https
    port: 443
    targetPort: 8443
  selector:
    app: tls-gateway

---
# HAProxy/Nginx that forwards to NodePort services
apiVersion: v1
kind: ConfigMap
metadata:
  name: haproxy-config
data:
  haproxy.cfg: |
    global
        ssl-default-bind-ciphers ECDHE+AESGCM:ECDHE+AES256:!aNULL:!MD5:!DSS
    
    frontend https
        bind *:8443 ssl crt /etc/ssl/preview.pem
        
        # Route by SNI
        use_backend preview-123 if { ssl_fc_sni preview-123.webapp.internal }
        use_backend preview-456 if { ssl_fc_sni preview-456.webapp.internal }
    
    backend preview-123
        server app webapp-service.nonprod-preview-123-preview.svc.cluster.local:80
    
    backend preview-456
        server app webapp-service.nonprod-preview-456-preview.svc.cluster.local:80
```

## Comparison of NodePort TLS Options

| Method | Complexity | Cert Management | Use Case |
|--------|------------|-----------------|----------|
| App-level TLS | Simple | Manual | Single service |
| Sidecar proxy | Medium | Flexible | Any app |
| Self-signed | Easy | No validation | Dev/test only |
| Let's Encrypt | Hard | Automatic | Needs DNS-01 |
| TLS LB | Medium | Centralized | Multiple services |

## Limitations of NodePort + TLS

1. **Port numbers**: Can't use standard 443, must use 30000-32767
2. **Certificate validation**: Harder with non-standard ports
3. **SNI routing**: Limited without a frontend proxy
4. **Let's Encrypt**: HTTP-01 challenge doesn't work with high ports

## Recommended Approach for Previews

**For VPN users (internal)**: Self-signed certificates are fine

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: NodePort
  ports:
  - name: https
    port: 443
    targetPort: 8443
    nodePort: 30443
    protocol: TCP
  selector:
    app: webapp

---
# Configure app or sidecar to serve HTTPS on 8443
# Users access via: https://node-ip:30443
```

**For external access**: Use Internal LoadBalancer instead

```yaml
metadata:
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
spec:
  type: LoadBalancer  # Gets standard ports 80/443
```

## Quick TLS Setup Script

```bash
#!/bin/bash
# setup-nodeport-tls.sh

NAMESPACE=$1
DOMAIN="${2:-preview.webapp.internal}"

# Generate self-signed cert
openssl req -x509 -nodes -days 90 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=$DOMAIN" \
  -addext "subjectAltName = DNS:$DOMAIN,DNS:*.$DOMAIN"

# Create secret
kubectl create secret tls webapp-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Patch deployment to mount cert
kubectl patch deployment webapp -n $NAMESPACE --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {"name": "tls", "secret": {"secretName": "webapp-tls"}}
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts/-",
    "value": {"name": "tls", "mountPath": "/etc/tls", "readOnly": true}
  }
]'

echo "TLS enabled. Access via:"
echo "  https://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'):30443"
echo "  (Accept the self-signed certificate warning)"
```

## Bottom Line

**NodePort CAN handle TLS**, but:
- You're limited to ports 30000-32767
- Certificate validation is trickier
- For preview environments, self-signed certs are usually sufficient
- For production-like TLS, use LoadBalancer or Ingress instead