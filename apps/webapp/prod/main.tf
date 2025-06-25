# Webapp Production Infrastructure

locals {
  project_id      = var.project_id
  environment     = var.environment
  billing_account = var.billing_account
  
  # Groups from organization
  groups = data.terraform_remote_state.organization.outputs.groups
  
  # Labels
  labels = merge(
    var.default_labels,
    {
      app         = var.app_name
      environment = var.environment
      boundary    = var.boundary
      team        = var.team
    }
  )
}

# Service Account for this boundary
resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "Terraform Service Account"
  description  = "Service account for Terraform operations in ${var.boundary} boundary"
  project      = local.project_id
}

# Grant project owner to terraform SA
resource "google_project_iam_member" "terraform_owner" {
  project = local.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

# Allow shared terraform SA to impersonate app SA
resource "google_service_account_iam_member" "shared_impersonate_app" {
  service_account_id = google_service_account.terraform.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:terraform-shared@u2i-bootstrap.iam.gserviceaccount.com"
}

# Use the webapp-complete module
module "webapp" {
  source = "../../../modules/webapp-complete"
  
  project_id       = local.project_id
  environment      = var.environment
  billing_account  = var.billing_account
  github_org       = var.github_org
  github_repo      = var.github_repo
  root_domain      = var.root_domain
  webapp_subdomain = var.webapp_subdomain
  
  # Optional customization
  gke_min_nodes = var.gke_min_nodes
  gke_max_nodes = var.gke_max_nodes
  
  # Additional labels
  additional_labels = local.labels
  
  # Use existing project
  create_project = false
  
  # Don't create new groups
  skip_group_creation = true
  groups              = local.groups
}