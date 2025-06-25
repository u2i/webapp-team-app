# Webapp Non-Production Infrastructure

locals {
  project_id      = var.project_id
  environment     = var.environment
  billing_account = var.billing_account
  
  # Groups from organization
  groups = {
    admins     = "gcp-admins@u2i.com"
    approvers  = "gcp-approvers@u2i.com"
    developers = "gcp-developers@u2i.com"
    auditors   = "gcp-auditors@u2i.com"
  }
  
  # Get compliant folder from organization
  compliant_folder = data.terraform_remote_state.organization.outputs.folder_structure.compliant
  
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

# Import existing webapp nonprod project
resource "google_project" "webapp_nonprod" {
  name            = "u2i-tenant-webapp"  # Match existing name
  project_id      = var.project_id
  folder_id       = local.compliant_folder
  billing_account = var.billing_account
  
  # Don't try to update labels on existing project
  lifecycle {
    ignore_changes = [name, labels]
  }
}

# Grant the webapp terraform SA (from bootstrap) permissions on this project
resource "google_project_iam_member" "webapp_terraform_owner" {
  project = google_project.webapp_nonprod.project_id
  role    = "roles/owner"
  member  = "serviceAccount:terraform-webapp-nonprod@u2i-bootstrap.iam.gserviceaccount.com"
}

# Use the webapp-complete module
module "webapp" {
  source = "../../../modules/webapp-complete"
  
  project_id       = google_project.webapp_nonprod.project_id
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