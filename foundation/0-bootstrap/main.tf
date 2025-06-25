# Use existing bootstrap project
data "google_project" "bootstrap" {
  project_id = var.project_id
}

# Enable required APIs
resource "google_project_service" "bootstrap_apis" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "orgpolicy.googleapis.com",  # Required for organization policies
  ])

  project = data.google_project.bootstrap.project_id
  service = each.value

  disable_on_destroy = false
}

# Import existing state bucket
data "google_storage_bucket" "terraform_state" {
  name = var.shared_state_bucket
}

# Shared Terraform Service Account
resource "google_service_account" "terraform_shared" {
  account_id   = "terraform-shared"
  display_name = "Shared Terraform Service Account"
  description  = "Service account for Terraform operations across all stacks"
  project      = data.google_project.bootstrap.project_id
}

# Grant organization-level permissions
resource "google_organization_iam_member" "terraform_shared_perms" {
  for_each = toset([
    "roles/resourcemanager.organizationAdmin",
    "roles/billing.admin",
    "roles/iam.organizationRoleAdmin",
    "roles/orgpolicy.policyAdmin",
  ])

  org_id = var.org_id
  role   = each.value
  member = "serviceAccount:${google_service_account.terraform_shared.email}"
}

# Grant state bucket access
resource "google_storage_bucket_iam_member" "terraform_state_access" {
  bucket = data.google_storage_bucket.terraform_state.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.terraform_shared.email}"
}

# GitHub Actions Service Account
resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD"
  project      = data.google_project.bootstrap.project_id
}

# Allow GitHub Actions to impersonate terraform shared account
resource "google_service_account_iam_member" "github_impersonate_terraform" {
  service_account_id = google_service_account.terraform_shared.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.github_actions.email}"
}

# Workload Identity Pool for GitHub
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Pool"
  description               = "Workload Identity Pool for GitHub Actions"
  project                   = data.google_project.bootstrap.project_id
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"
  project                            = data.google_project.bootstrap.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_org}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub to impersonate the GitHub Actions service account
resource "google_service_account_iam_member" "github_actions_impersonation" {
  service_account_id = google_service_account.github_actions.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/u2i-infrastructure"
}

# Allow webapp-team-app repository to use workload identity
resource "google_service_account_iam_member" "webapp_app_impersonation" {
  service_account_id = google_service_account.github_actions.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/webapp-team-app"
}

# WebApp Project Service Accounts
# These are created in the bootstrap so webapp stacks can impersonate them
resource "google_service_account" "webapp_terraform_prod" {
  account_id   = "terraform-webapp-prod"
  display_name = "Terraform SA for webapp-prod"
  description  = "Service account for Terraform operations in webapp prod"
  project      = data.google_project.bootstrap.project_id
}

resource "google_service_account" "webapp_terraform_nonprod" {
  account_id   = "terraform-webapp-nonprod"
  display_name = "Terraform SA for webapp-nonprod"
  description  = "Service account for Terraform operations in webapp nonprod"
  project      = data.google_project.bootstrap.project_id
}

# Allow shared terraform SA to impersonate webapp SAs
resource "google_service_account_iam_member" "shared_impersonate_webapp_prod" {
  service_account_id = google_service_account.webapp_terraform_prod.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.terraform_shared.email}"
}

resource "google_service_account_iam_member" "shared_impersonate_webapp_nonprod" {
  service_account_id = google_service_account.webapp_terraform_nonprod.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.terraform_shared.email}"
}

# Grant webapp SAs permissions to create and manage projects
resource "google_organization_iam_member" "webapp_terraform_prod_perms" {
  for_each = toset([
    "roles/resourcemanager.projectCreator",
    "roles/billing.user",
    "roles/resourcemanager.projectIamAdmin",
  ])

  org_id = var.org_id
  role   = each.value
  member = "serviceAccount:${google_service_account.webapp_terraform_prod.email}"
}

resource "google_organization_iam_member" "webapp_terraform_nonprod_perms" {
  for_each = toset([
    "roles/resourcemanager.projectCreator",
    "roles/billing.user",
    "roles/resourcemanager.projectIamAdmin",
  ])

  org_id = var.org_id
  role   = each.value
  member = "serviceAccount:${google_service_account.webapp_terraform_nonprod.email}"
}