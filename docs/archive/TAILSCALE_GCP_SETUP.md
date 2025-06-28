# Tailscale Setup for Google Cloud Access

## Option 1: Subnet Router VM (Recommended)

### 1. Create a Tailscale Subnet Router VM

```bash
# Create VM to act as subnet router
gcloud compute instances create tailscale-router \
  --machine-type=e2-micro \
  --subnet=default \
  --can-ip-forward \
  --tags=tailscale-router \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --zone=europe-west1-b \
  --project=u2i-tenant-webapp

# Enable IP forwarding
gcloud compute instances add-metadata tailscale-router \
  --metadata=enable-ip-forwarding=true \
  --zone=europe-west1-b
```

### 2. Install Tailscale on the Router VM

```bash
# SSH into the VM
gcloud compute ssh tailscale-router --zone=europe-west1-b

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf

# Start Tailscale as subnet router for GCP networks
# Replace with your actual VPC CIDR ranges
sudo tailscale up --advertise-routes=10.0.0.0/8,172.16.0.0/12 --accept-routes
```

### 3. Configure Firewall Rules

```bash
# Allow Tailscale traffic
gcloud compute firewall-rules create allow-tailscale \
  --allow=udp:41641 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=tailscale-router \
  --project=u2i-tenant-webapp

# Allow forwarded traffic from Tailscale subnet
gcloud compute firewall-rules create allow-tailscale-forwarded \
  --allow=all \
  --source-tags=tailscale-router \
  --project=u2i-tenant-webapp
```

## Option 2: Tailscale on Each GKE Node

### Install Tailscale DaemonSet on GKE

```yaml
# tailscale-router.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tailscale
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tailscale
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "get", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tailscale
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: tailscale
subjects:
- kind: ServiceAccount
  name: tailscale
  namespace: kube-system
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: tailscale
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: tailscale
  template:
    metadata:
      labels:
        app: tailscale
    spec:
      serviceAccountName: tailscale
      hostNetwork: true
      containers:
      - name: tailscale
        image: tailscale/tailscale:latest
        env:
        - name: TS_KUBE_SECRET
          value: "tailscale-auth"
        - name: TS_USERSPACE
          value: "false"
        - name: TS_ROUTES
          value: "10.0.0.0/8"  # Your cluster/pod CIDR
        - name: TS_ACCEPT_ROUTES
          value: "true"
        securityContext:
          privileged: true
        volumeMounts:
        - name: dev-net-tun
          mountPath: /dev/net/tun
        - name: var-lib
          mountPath: /var/lib
        - name: xtables-lock
          mountPath: /run/xtables.lock
      volumes:
      - name: dev-net-tun
        hostPath:
          path: /dev/net/tun
      - name: var-lib
        hostPath:
          path: /var/lib
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
```

## Option 3: Tailscale Operator (Official K8s Integration)

### 1. Install Tailscale Operator

```bash
# Add Tailscale Helm repo
helm repo add tailscale https://helm.tailscale.com
helm repo update

# Install operator
helm install tailscale-operator tailscale/tailscale-operator \
  --namespace=tailscale-system \
  --create-namespace \
  --set oauth.clientId="<your-oauth-client-id>" \
  --set oauth.clientSecret="<your-oauth-client-secret>"
```

### 2. Expose Services via Tailscale

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-tailscale
  annotations:
    tailscale.com/expose: "true"
    tailscale.com/hostname: "webapp-preview"
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
```

## Access Patterns After Setup

### 1. Direct Node Access (with subnet router)
```bash
# Access any GKE node directly
curl http://10.2.0.29:32104

# Access services by ClusterIP
curl http://10.36.170.76
```

### 2. Service Access (with operator)
```bash
# Access by Tailscale hostname
curl http://webapp-preview
```

### 3. kubectl Access
```bash
# Configure kubectl to use Tailscale IP
kubectl config set-cluster gke_cluster --server=https://10.2.0.1:443
```

## Quick Setup Script

```bash
#!/bin/bash
# setup-tailscale-gcp.sh

PROJECT_ID="u2i-tenant-webapp"
ZONE="europe-west1-b"
REGION="europe-west1"

# Create subnet router VM
echo "Creating Tailscale router VM..."
gcloud compute instances create tailscale-router \
  --machine-type=e2-micro \
  --subnet=default \
  --can-ip-forward \
  --tags=tailscale-router \
  --metadata=startup-script='#!/bin/bash
curl -fsSL https://tailscale.com/install.sh | sh
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf' \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --zone=$ZONE \
  --project=$PROJECT_ID

# Create firewall rules
echo "Creating firewall rules..."
gcloud compute firewall-rules create allow-tailscale \
  --allow=udp:41641 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=tailscale-router \
  --project=$PROJECT_ID

gcloud compute firewall-rules create allow-from-tailscale \
  --allow=all \
  --source-tags=tailscale-router \
  --project=$PROJECT_ID

echo "Setup complete! Now SSH into the VM and run:"
echo "  sudo tailscale up --advertise-routes=10.0.0.0/8 --accept-routes"
echo ""
echo "Then approve the routes in the Tailscale admin console."
```

## Benefits for Preview Environments

1. **No VPN needed** - Tailscale is your VPN
2. **Access NodePort services** directly: `http://node-ip:nodeport`
3. **Access pods** by their IPs
4. **Zero trust** - Only authorized Tailscale users
5. **Works anywhere** - Home, coffee shop, etc.

## ACL Example for Teams

```json
{
  "groups": {
    "group:devs": ["user1@example.com", "user2@example.com"],
    "group:qa": ["qa1@example.com"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["group:devs"],
      "dst": ["tag:k8s-nodes:*", "tag:preview-envs:*"]
    },
    {
      "action": "accept", 
      "src": ["group:qa"],
      "dst": ["tag:preview-envs:80,443"]
    }
  ],
  "tagOwners": {
    "tag:k8s-nodes": ["group:devs"],
    "tag:preview-envs": ["group:devs"]
  }
}