#!/bin/bash
# Import existing resources

echo "Importing DNS zone..."
terraform import module.webapp.google_dns_managed_zone.webapp projects/u2i-tenant-webapp/managedZones/webapp-zone-nonprod || true

echo "Importing service accounts..."
terraform import module.webapp.google_service_account.external_dns projects/u2i-tenant-webapp/serviceAccounts/external-dns@u2i-tenant-webapp.iam.gserviceaccount.com || true
terraform import module.webapp.google_service_account.config_connector projects/u2i-tenant-webapp/serviceAccounts/config-connector@u2i-tenant-webapp.iam.gserviceaccount.com || true
terraform import module.webapp.google_service_account.cloud_deploy_sa projects/u2i-tenant-webapp/serviceAccounts/cloud-deploy-sa@u2i-tenant-webapp.iam.gserviceaccount.com || true

echo "Importing network..."
terraform import module.webapp.google_compute_network.gke_network projects/u2i-tenant-webapp/global/networks/webapp-gke-network || true

echo "Importing workload identity pool..."
terraform import module.webapp.google_iam_workload_identity_pool.github projects/u2i-tenant-webapp/locations/global/workloadIdentityPools/github-pool || true

echo "Importing KMS keyring..."
terraform import module.webapp.google_kms_key_ring.webapp_keyring projects/u2i-tenant-webapp/locations/europe-west1/keyRings/webapp-team-keyring || true

echo "Importing storage bucket..."
terraform import module.webapp.google_storage_bucket.deployment_artifacts u2i-tenant-webapp-deploy-artifacts || true

echo "Import complete!"