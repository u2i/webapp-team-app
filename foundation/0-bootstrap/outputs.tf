output "bootstrap_project_id" {
  description = "The bootstrap project ID"
  value       = data.google_project.bootstrap.project_id
}

output "shared_state_bucket" {
  description = "The shared state bucket name"
  value       = data.google_storage_bucket.terraform_state.name
}

output "terraform_shared_sa_email" {
  description = "Email of the shared Terraform service account"
  value       = google_service_account.terraform_shared.email
}

output "github_actions_sa_email" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github_actions.email
}

output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "webapp_service_accounts" {
  description = "WebApp service accounts"
  value = {
    prod    = google_service_account.webapp_terraform_prod.email
    nonprod = google_service_account.webapp_terraform_nonprod.email
  }
}