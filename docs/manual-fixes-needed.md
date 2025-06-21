# Manual Fixes Applied During Deployment

This document lists the manual fixes that were applied to get the load balancer working. These need to be incorporated into the automated deployment.

## Issues Found

### 1. Config Connector SSL Certificate Creation Failed
**Issue**: Config Connector was setting `projectRef: webapp-team` instead of using the project annotation.

**Manual Fix**: Created SSL certificate manually:
```bash
gcloud compute ssl-certificates create webapp-dev-cert \
  --domains=dev.webapp.u2i.dev --global --project=u2i-tenant-webapp
```

**Permanent Fix Needed**: 
- Investigate why Config Connector is using namespace name as project
- May need to file a bug report with Config Connector team

### 2. NEG Zone Coverage
**Issue**: The backend service only had NEGs from zones b and c, but the pods were in zone d.

**Manual Fix**: Added zone d NEG to backend:
```bash
gcloud compute backend-services add-backend webapp-dev-backend \
  --global --network-endpoint-group=k8s1-60fc89ae-webapp-team-webapp-service-80-dcb50a2e \
  --network-endpoint-group-zone=europe-west1-d \
  --balancing-mode=CONNECTION \
  --max-connections-per-endpoint=100 \
  --project=u2i-tenant-webapp
```

**Permanent Fix Needed**:
- Ensure autoneg controller is running and properly configured
- The autoneg controller should automatically attach NEGs from all zones

### 3. Health Check Reference
**Issue**: Backend service was using old health check on port 80 instead of 8080.

**Manual Fix**: Created new health check and updated backend:
```bash
gcloud compute health-checks create tcp webapp-dev-health-8080 \
  --port=8080 --global --project=u2i-tenant-webapp

gcloud compute backend-services update webapp-dev-backend \
  --health-checks=webapp-dev-health-8080 --global --project=u2i-tenant-webapp
```

**Permanent Fix Needed**:
- Already fixed in Config Connector resources (port: 8080)
- Need to ensure old health check is deleted

### 4. DNS Record
**Issue**: Terraform was reverting the DNS record to the old IP (35.241.5.173).

**Manual Fix**: Updated DNS record:
```bash
gcloud dns record-sets update dev.webapp.u2i.dev. \
  --zone=webapp-zone-non-prod --type=A --rrdatas=34.98.112.208 \
  --project=u2i-tenant-webapp
```

**Permanent Fix Needed**:
- Already fixed in Terraform to use data source for actual IP
- Will be applied in next Terraform run

## Next Steps

1. **Deploy autoneg controller** - This should handle NEG attachments automatically
2. **Update Terraform** - Apply the DNS fix
3. **Clean up manual resources** - Delete manually created resources that should be managed by Config Connector
4. **Monitor Config Connector** - Ensure it can create resources in the correct project