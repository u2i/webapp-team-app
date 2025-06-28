# Webapp Team App Deployment Guide

This guide covers deploying the webapp to the non-prod/dev environment using GKE Ingress (L7 HTTP(S) Load Balancer).

## Prerequisites

1. Access to the GCP projects:
   - `u2i-tenant-webapp` (webapp project with GKE cluster)

2. Tools installed:
   - `gcloud` CLI
   - `kubectl`
   - `terraform` (for infrastructure updates)

## Step 1: Apply Terraform Changes

First, apply the Terraform changes to ensure all infrastructure is in place:

```bash
cd webapp-team-infrastructure/projects/non-prod
terragrunt apply
```

This ensures:
- GKE cluster is configured
- Required IAM permissions
- Workload Identity bindings
- External DNS setup

## Step 2: Deploy Config Connector Resources

Deploy the L7 Ingress resources using Config Connector:

```bash
kubectl apply -f webapp-team-app/k8s-clean/overlays/nonprod/config-connector-resources.yaml -n webapp-team
```

This creates:
- Static IP address
- Managed SSL certificate for dev.webapp.u2i.dev
- GKE Ingress for L7 load balancing

## Step 3: Deploy Cloud Deploy Pipeline

Deploy the Cloud Deploy pipeline and targets:

```bash
gcloud deploy apply --file webapp-team-app/clouddeploy-clean.yaml \
  --region europe-west1 \
  --project u2i-tenant-webapp
```

## Step 4: Deploy the Application

Build and deploy the application using Cloud Deploy:

```bash
# From the webapp-team-app directory
gcloud deploy releases create release-$(date +%Y%m%d-%H%M%S) \
  --delivery-pipeline webapp-delivery-pipeline \
  --region europe-west1 \
  --project u2i-tenant-webapp \
  --skaffold-file skaffold-clean.yaml \
  --images europe-west1-docker.pkg.dev/u2i-tenant-webapp/webapp-images/webapp=europe-west1-docker.pkg.dev/u2i-tenant-webapp/webapp-images/webapp:latest
```

## Step 5: Verify DNS and Certificate

External DNS will automatically create the DNS record. Check the certificate status:

```bash
kubectl get managedcertificate -n webapp-team
```

The certificate will show as "Provisioning" initially and change to "Active" within 15-60 minutes.

## Step 6: Verify Deployment

Test the application:

```bash
# Test HTTP
curl http://dev.webapp.u2i.dev

# Once certificate is active, test HTTPS
curl https://dev.webapp.u2i.dev
```

## Monitoring

- Check application logs:
  ```bash
  kubectl logs -l app=webapp -n webapp-team
  ```

- Check ingress status:
  ```bash
  kubectl describe ingress webapp-ingress -n webapp-team
  ```

- Check External DNS logs:
  ```bash
  kubectl logs -n external-dns deployment/external-dns
  ```

## Troubleshooting

### Certificate stuck in provisioning
- Verify DNS is resolving: `nslookup dev.webapp.u2i.dev 8.8.8.8`
- Check External DNS is working: `kubectl logs -n external-dns deployment/external-dns`
- Ensure DNS delegation is correct for webapp.u2i.dev zone

### 502 errors
- Check if pods are running: `kubectl get pods -n webapp-team`
- Verify service endpoints: `kubectl get endpoints webapp-service -n webapp-team`
- Check backend service health in GCP Console

## Repository Structure

- `/k8s-base/` - Base Kubernetes manifests
- `/k8s-clean/overlays/` - Environment-specific configurations
- `/clouddeploy-clean.yaml` - Cloud Deploy pipeline configuration
- `/skaffold-clean.yaml` - Skaffold build configuration