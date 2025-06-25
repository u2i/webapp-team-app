output "project_id" {
  description = "The GCP project ID"
  value       = local.project_id
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "artifact_registry_url" {
  description = "URL of the artifact registry"
  value       = module.artifact_registry.repository_url
}

output "cloud_deploy_pipeline" {
  description = "Name of the Cloud Deploy pipeline"
  value       = module.cloud_deploy.pipeline_name
}

output "dns_zone" {
  description = "DNS zone for the webapp"
  value       = module.dns.zone_name
}

output "dns_nameservers" {
  description = "Nameservers for the DNS zone"
  value       = module.dns.name_servers
}

output "terraform_service_account" {
  description = "Service account used for Terraform"
  value       = google_service_account.terraform.email
}

output "github_workload_identity_provider" {
  description = "Workload identity provider for GitHub Actions"
  value       = module.github_identity.workload_identity_provider
}