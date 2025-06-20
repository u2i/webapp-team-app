# Webapp Team App Deployment Guide

This guide covers deploying the webapp to the non-prod/dev environment with L4 TCP proxy load balancer and TLS termination.

## Prerequisites

1. Access to the GCP projects:
   - `u2i-tenant-webapp` (webapp project)
   - `u2i-gke-nonprod` (GKE cluster project)

2. Tools installed:
   - `gcloud` CLI
   - `kubectl`
   - `terraform` (for infrastructure updates)

## Step 1: Apply Terraform Changes

First, apply the Terraform changes to create the Autoneg controller service account:

```bash
cd webapp-team-infrastructure/projects/non-prod
terragrunt apply
```

This creates:
- Autoneg controller service account
- Required IAM permissions
- Workload Identity bindings

## Step 2: Deploy Autoneg Controller

Deploy the Autoneg controller to automatically manage NEG attachments:

```bash
kubectl apply -f webapp-team-app/k8s-clean/autoneg/autoneg-controller.yaml
```

Verify the controller is running:
```bash
kubectl get pods -n autoneg-system
```

## Step 3: Deploy Config Connector Resources

Deploy the L4 load balancer resources using Config Connector:

```bash
kubectl apply -f webapp-team-app/k8s-clean/overlays/nonprod/config-connector-resources.yaml
```

This creates:
- Static IP address
- SSL certificate for dev.webapp.u2i.dev
- L4 TCP proxy load balancer components

## Step 4: Deploy Cloud Deploy Pipeline

Deploy the Cloud Deploy pipeline and targets:

```bash
gcloud deploy apply --file webapp-team-app/clouddeploy-clean.yaml \
  --region europe-west1 \
  --project u2i-tenant-webapp
```

## Step 5: Deploy the Application

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

## Step 6: Verify NEG Attachment

The Autoneg controller will automatically attach the NEGs to the backend service. Monitor the logs:

```bash
kubectl logs -n autoneg-system deployment/autoneg-controller-manager -f
```

## Step 7: Update DNS

Get the static IP address:
```bash
gcloud compute addresses describe webapp-dev-ip \
  --global \
  --project u2i-tenant-webapp \
  --format="value(address)"
```

Update the DNS record for `dev.webapp.u2i.dev` to point to this IP address.

## Step 8: Verify Deployment

1. Check the service is running:
   ```bash
   kubectl get pods -n webapp-team
   kubectl get svc -n webapp-team
   ```

2. Check NEGs are created:
   ```bash
   gcloud compute network-endpoint-groups list \
     --project u2i-gke-nonprod \
     --filter "name:k8s*webapp*"
   ```

3. Check backend service health:
   ```bash
   gcloud compute backend-services get-health webapp-dev-backend \
     --global \
     --project u2i-tenant-webapp
   ```

4. Once DNS propagates, test the application:
   ```bash
   curl https://dev.webapp.u2i.dev/health
   ```

## Troubleshooting

### NEGs not attaching
- Check Autoneg controller logs
- Verify service has correct annotations
- Ensure backend service exists in Config Connector

### Certificate not provisioning
- Check ManagedCertificate status: `kubectl describe managedcertificate webapp-dev-cert -n webapp-team`
- Ensure DNS is pointing to the correct IP
- Certificate provisioning can take up to 20 minutes

### Load balancer not working
- Check firewall rules allow traffic from Google LB ranges
- Verify health check is passing
- Check backend service configuration

## Clean Structure

The cleaned up structure separates concerns:
- `/k8s-clean/base/` - Base Kubernetes resources
- `/k8s-clean/overlays/nonprod/` - Non-prod specific configs and Config Connector resources
- `/k8s-clean/autoneg/` - Autoneg controller deployment
- `clouddeploy-clean.yaml` - Simplified Cloud Deploy configuration
- `skaffold-clean.yaml` - Points to the clean structure