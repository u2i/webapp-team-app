output "project_id" {
  description = "The GCP project ID"
  value       = google_project.webapp_nonprod.project_id
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.webapp.gke_cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = module.webapp.gke_cluster_endpoint
  sensitive   = true
}

output "artifact_registry_url" {
  description = "URL of the artifact registry"
  value       = module.webapp.artifact_registry.url
}

output "cloud_deploy_pipeline" {
  description = "Name of the Cloud Deploy pipeline"
  value       = module.webapp.cloud_deploy_pipeline
}

output "dns_records" {
  description = "DNS records created"
  value       = module.webapp.dns_records
}

output "terraform_service_account" {
  description = "Service account used for Terraform"
  value       = "terraform-webapp-nonprod@u2i-bootstrap.iam.gserviceaccount.com"
}

output "github_actions_config" {
  description = "Configuration for GitHub Actions"
  value       = module.webapp.github_actions_config
}

output "compliance_status" {
  description = "Compliance framework status"
  value       = module.webapp.compliance_status
}