# Outputs for webapp project module

output "tenant_project" {
  description = "Tenant project information"
  value = {
    project_id = data.google_project.tenant_app.project_id
    number     = data.google_project.tenant_app.number
  }
}

# Output moved to cloud-deploy.tf
# output "cloud_deploy_pipeline" {
#   description = "Cloud Deploy pipeline information"
#   value = {
#     name     = google_clouddeploy_delivery_pipeline.webapp_pipeline.name
#     location = google_clouddeploy_delivery_pipeline.webapp_pipeline.location
#     targets = merge(
#       {
#         nonprod = google_clouddeploy_target.nonprod_target.name
#       },
#       var.environment == "prod" ? {
#         prod = google_clouddeploy_target.prod_target[0].name
#       } : {}
#     )
#   }
# }

output "artifact_registry" {
  description = "Artifact Registry repository information"
  value = {
    repository = google_artifact_registry_repository.webapp_images.name
    location   = google_artifact_registry_repository.webapp_images.location
    url        = "${google_artifact_registry_repository.webapp_images.location}-docker.pkg.dev/${data.google_project.tenant_app.project_id}/${google_artifact_registry_repository.webapp_images.repository_id}"
  }
}

output "github_actions_config" {
  description = "Configuration for GitHub Actions workflows"
  value = {
    workload_identity_provider = "projects/${data.google_project.tenant_app.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
    service_account            = google_service_account.terraform.email
    deployment_service_account = google_service_account.cloud_deploy_sa.email
    project_id                 = data.google_project.tenant_app.project_id
  }
}

output "state_bucket" {
  description = "Terraform state bucket information"
  value = {
    bucket     = google_storage_bucket.webapp_tfstate.name
    encryption = "CMEK with 90-day rotation"
  }
}

output "compliance_status" {
  description = "Current compliance framework status"
  value = {
    frameworks       = ["iso27001", "soc2", "gdpr"]
    data_residency   = var.primary_region
    encryption       = "CMEK with 90-day rotation"
    audit_logging    = "Enabled with 30-day retention"
    access_control   = "Project-local service accounts with least privilege"
    environment      = var.environment
  }
}

output "config_connector_sa_email" {
  description = "Config Connector service account email"
  value       = google_service_account.config_connector.email
}

output "external_dns_sa_email" {
  description = "External DNS service account email"
  value       = google_service_account.external_dns.email
}

output "cloud_deploy_sa_email" {
  description = "Cloud Deploy service account email"
  value       = google_service_account.cloud_deploy_sa.email
}

output "dns_zone_name" {
  description = "DNS zone name"
  value       = google_dns_managed_zone.webapp.name
}