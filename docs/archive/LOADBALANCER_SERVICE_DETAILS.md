# LoadBalancer Service Details for GKE

## How LoadBalancer Service Works

When you create a Service with `type: LoadBalancer` in GKE:

1. **Network Load Balancer Creation** (1-2 minutes)
   - GKE provisions a regional TCP/UDP Network Load Balancer
   - Creates forwarding rules for your service ports
   - Allocates an ephemeral external IP (or uses reserved if specified)

2. **Traffic Flow**
   ```
   Internet → External IP → Network LB → Node:NodePort → kube-proxy → Pod
   ```

3. **What Gets Created**
   - 1 Google Cloud Network Load Balancer
   - 1 Forwarding rule per service port
   - 1 Backend service pointing to instance group
   - 1 Health check (TCP by default)
   - Firewall rules for health checks and traffic

## Example Configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  annotations:
    # Optional: Use premium network tier for lower latency
    cloud.google.com/network-tier: "Premium"  # or "Standard"
    
    # Optional: Use specific load balancer type
    networking.gke.io/load-balancer-type: "External"  # default
    
    # Optional: Reserve a static IP
    # networking.gke.io/load-balancer-ip: "34.102.136.180"
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
```

## Provisioning Timeline

1. **0-10 seconds**: Service created, NodePort allocated
2. **10-30 seconds**: Load balancer backend configured
3. **30-60 seconds**: Health checks start passing
4. **60-120 seconds**: External IP assigned and routable

**Total: ~2 minutes** for basic HTTP/TCP service

## Cost Breakdown

**Per Load Balancer per month:**
- Forwarding rule: $0.025/hour = ~$18/month
- Data processing: $0.008/GB (first 10TB)
- No charge for the load balancer itself

**Example**: 10 preview environments = ~$180/month just for forwarding rules

## Comparison with Ingress

| Aspect | LoadBalancer Service | Ingress + NEG |
|--------|---------------------|---------------|
| Provisioning Time | 1-2 minutes | 5-10 minutes |
| External IP | Ephemeral (per service) | Static (shared) |
| SSL/TLS | Not included | Managed certificates |
| Cost | $18/month per service | $18/month total |
| Protocol | TCP/UDP | HTTP/HTTPS only |
| Path routing | No | Yes |
| Host routing | No | Yes |

## Optimizations for Preview Environments

### 1. Ephemeral IPs (Recommended)
```yaml
spec:
  type: LoadBalancer
  # No loadBalancerIP specified = ephemeral
```
- Faster allocation
- No IP quota issues
- Auto-released on deletion

### 2. Session Affinity (Optional)
```yaml
spec:
  type: LoadBalancer
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
```
- Useful for stateful preview apps
- Ensures same client → same pod

### 3. Internal Load Balancer (VPN/Private)
```yaml
metadata:
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
```
- No public IP
- Accessible only within VPC
- Even faster provisioning

## Access Patterns

### 1. Direct IP Access
```bash
# Get the external IP
kubectl get svc webapp-service -n webapp-team

# Access directly (after ~2 min)
curl http://34.102.136.180
```

### 2. DNS with External-DNS
```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: preview-123.webapp.u2i.dev
spec:
  type: LoadBalancer
```
- External-DNS will create A record → LoadBalancer IP
- Adds ~30 seconds for DNS propagation

### 3. Programmatic Access
```bash
# Wait for IP assignment
while [ -z "$IP" ]; do
  IP=$(kubectl get svc webapp-service -n webapp-team -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -z "$IP" ] && sleep 10
done
echo "Service available at: http://$IP"
```

## Pros and Cons for Preview Environments

**Pros:**
- ✅ Fastest way to get a public IP (2 min)
- ✅ Simple - just change service type
- ✅ No ingress controller needed
- ✅ Works with any TCP/UDP protocol
- ✅ Each preview fully isolated

**Cons:**
- ❌ No HTTPS without additional setup
- ❌ Costs $18/month per preview
- ❌ No path-based routing
- ❌ Ephemeral IPs change on recreate
- ❌ No request routing features

## Alternative: Shared Load Balancer

Instead of one LB per preview, use a single LB with port mapping:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: preview-router
spec:
  type: LoadBalancer
  ports:
  - name: pr-123
    port: 30123
    targetPort: 80
    nodePort: 30123
  - name: pr-124  
    port: 30124
    targetPort: 80
    nodePort: 30124
  selector:
    # Use EndpointSlices to route to different namespaces
```

Access: `http://preview.webapp.u2i.dev:30123`

This reduces cost but requires port management.