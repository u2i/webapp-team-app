#!/bin/bash
# Deploy ingress with dynamic IP and update DNS

set -e

ENVIRONMENT=${1:-dev}
NAMESPACE="webapp-team"

echo "🚀 Deploying ingress for $ENVIRONMENT environment..."

# Apply the appropriate ingress configuration based on environment
if [ "$ENVIRONMENT" == "prod" ]; then
    HOST="webapp.u2i.dev"
    HOSTS="webapp.u2i.dev,www.webapp.u2i.dev"
else
    HOST="$ENVIRONMENT.webapp.u2i.dev"
    HOSTS="$ENVIRONMENT.webapp.u2i.dev"
fi

# Replace placeholders and apply
kubectl apply -f k8s-manifests/ingress.yaml -n $NAMESPACE \
    --dry-run=client -o yaml | \
    sed "s/\${INGRESS_HOST}/$HOST/g" | \
    sed "s/\${INGRESS_HOSTS}/$HOSTS/g" | \
    kubectl apply -f -

echo "⏳ Waiting for ingress to get an IP address..."

# Wait for IP allocation
for i in {1..60}; do
    IP=$(kubectl get ingress webapp-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$IP" ]; then
        echo "✅ Ingress IP allocated: $IP"
        break
    fi
    echo -n "."
    sleep 5
done

if [ -z "$IP" ]; then
    echo "❌ Failed to get ingress IP after 5 minutes"
    exit 1
fi

echo ""
echo "📝 DNS Update Instructions:"
echo "1. Update DNS records in terraform:"
echo "   - File: webapp-team-infrastructure/dns.tf"
echo "   - Update the A records for $HOST to point to: $IP"
echo ""
echo "2. Apply terraform changes:"
echo "   cd ../webapp-team-infrastructure"
echo "   terraform apply"
echo ""
echo "3. Wait for SSL certificate provisioning (can take up to 15 minutes):"
echo "   kubectl describe managedcertificate webapp-ssl-cert -n $NAMESPACE"
echo ""
echo "4. Once provisioned, access the app at:"
echo "   https://$HOST"
echo ""
echo "🔍 To check certificate status:"
echo "kubectl get managedcertificate webapp-ssl-cert -n $NAMESPACE -o jsonpath='{.status.certificateStatus}'"