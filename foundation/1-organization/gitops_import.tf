# Import existing resources to avoid conflicts

# Use existing service accounts
data "google_service_account" "terraform_organization" {
  account_id = "terraform-organization"
  project    = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
}

data "google_service_account" "terraform_security" {
  account_id = "terraform-security"
  project    = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
}

# Use existing Workload Identity Pool
data "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions"
  project                   = data.terraform_remote_state.bootstrap.outputs.bootstrap_project_id
}

# Update locals to use data sources
locals {
  terraform_org_sa_email = data.google_service_account.terraform_organization.email
  terraform_sec_sa_email = data.google_service_account.terraform_security.email
  wip_pool_name          = data.google_iam_workload_identity_pool.github_actions.name
}