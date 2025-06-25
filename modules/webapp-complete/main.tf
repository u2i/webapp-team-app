# WebApp Project Module - Configures project-level resources
# This module sets up DNS, Cloud Deploy, Artifact Registry, and other project resources

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# Get organization and GKE outputs
data "terraform_remote_state" "organization" {
  backend = "gcs"
  config = {
    bucket = "u2i-tfstate"
    prefix = "organization"
  }
}

# Removed shared_gke remote state - no longer using org-level clusters

# Reference the existing tenant project
data "google_project" "tenant_app" {
  project_id = var.project_id
}

# Compute boundary-stage-tier values
locals {
  # Use new variables if provided, otherwise derive from legacy environment
  boundary = var.boundary != "" ? var.boundary : (
    var.environment == "prod" ? "prod" : "nonprod"
  )
  
  # Default stage based on environment if not explicitly set
  stage = var.stage != "" ? var.stage : (
    var.environment == "prod" ? "prod" : "dev"
  )
  
  # Use tier and mode with defaults
  tier = var.tier
  mode = var.mode
  
  # Standard labels for all resources
  common_labels = {
    app      = "webapp"
    team     = "webapp-team"
    boundary = local.boundary
    stage    = local.stage
    tier     = local.tier
    mode     = local.mode
    # Keep existing labels for compatibility
    environment    = var.environment
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    managed_by     = "terraform"
  }
  
  # Namespace pattern: boundary-stage-tier
  namespace = "${local.boundary}-${local.stage}-${local.tier}"
  
  # Resource naming with optional version suffix
  workload_identity_pool_id = var.resource_version != "" ? "webapp-github-pool-${var.resource_version}" : "webapp-github-pool"
}

# Enable required APIs for the tenant project
resource "google_project_service" "tenant_apis" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudbuild.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "dns.googleapis.com",
    "cloudkms.googleapis.com",
    "certificatemanager.googleapis.com",
    "gkehub.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "mesh.googleapis.com"
  ])

  project = data.google_project.tenant_app.project_id
  service = each.key

  disable_on_destroy = false
}

# Terraform service account for this project
resource "google_service_account" "terraform" {
  project      = data.google_project.tenant_app.project_id
  account_id   = "terraform"
  display_name = "Terraform Service Account"
  description  = "Service account for Terraform automation in webapp project"

  depends_on = [google_project_service.tenant_apis]
}

# Grant necessary permissions to terraform service account
resource "google_project_iam_member" "terraform_permissions" {
  for_each = toset([
    "roles/owner",
  ])

  project = data.google_project.tenant_app.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github" {
  project                   = data.google_project.tenant_app.project_id
  workload_identity_pool_id = local.workload_identity_pool_id
  display_name              = "WebApp GitHub Actions Pool${var.resource_version != "" ? " ${var.resource_version}" : ""}"
  description               = "Identity pool for GitHub Actions CI/CD - WebApp Team"

  depends_on = [google_project_service.tenant_apis]
}

# GitHub provider for the pool
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = data.google_project.tenant_app.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Provider"
  description                        = "GitHub OIDC provider for webapp-team-infrastructure repo"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Only allow our specific repositories
  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}' || assertion.repository == '${var.github_org}/webapp-team-app'"
}

# Allow GitHub Actions to impersonate terraform SA from infrastructure repo
resource "google_service_account_iam_member" "github_terraform_impersonation" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

# Allow GitHub Actions to impersonate cloud deploy SA from app repo
resource "google_service_account_iam_member" "github_app_impersonation" {
  service_account_id = google_service_account.cloud_deploy_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/webapp-team-app"
}

# Allow GitHub Actions to act as cloud deploy SA (required for Cloud Deploy)
resource "google_service_account_iam_member" "github_app_actas" {
  service_account_id = google_service_account.cloud_deploy_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/webapp-team-app"
}

# Allow Cloud Deploy SA to act as itself (required by Cloud Deploy API even though it's a no-op)
resource "google_service_account_iam_member" "cloud_deploy_sa_self_actas" {
  service_account_id = google_service_account.cloud_deploy_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}

# Create KMS key ring for webapp team
resource "google_kms_key_ring" "webapp_keyring" {
  project  = data.google_project.tenant_app.project_id
  name     = "webapp-team-keyring"
  location = var.primary_region

  depends_on = [google_project_service.tenant_apis]
}

# Create KMS crypto key for state bucket encryption
resource "google_kms_crypto_key" "webapp_tfstate_key" {
  name     = "webapp-tfstate-key"
  key_ring = google_kms_key_ring.webapp_keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = false
  }

  labels = {
    purpose        = "terraform-state-encryption"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
  }
}

# Grant GCS service account access to use the key
data "google_storage_project_service_account" "gcs_account" {
  project = data.google_project.tenant_app.project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_encrypt_decrypt" {
  crypto_key_id = google_kms_crypto_key.webapp_tfstate_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Create a dedicated state bucket for webapp team
resource "google_storage_bucket" "webapp_tfstate" {
  project  = data.google_project.tenant_app.project_id
  name     = "${data.google_project.tenant_app.project_id}-tfstate"
  location = var.primary_region

  # Security best practices
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 30
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # CMEK encryption
  encryption {
    default_kms_key_name = google_kms_crypto_key.webapp_tfstate_key.id
  }

  labels = {
    environment    = var.environment
    purpose        = "terraform-state"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
    tenant         = "webapp-team"
  }

  depends_on = [
    google_kms_crypto_key_iam_member.gcs_encrypt_decrypt
  ]
}

# Grant state bucket access to terraform service account
resource "google_storage_bucket_iam_member" "webapp_tfstate_access" {
  bucket = google_storage_bucket.webapp_tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "webapp_images" {
  project       = data.google_project.tenant_app.project_id
  location      = var.primary_region
  repository_id = "webapp-images"
  description   = "Container images for webapp tenant"
  format        = "DOCKER"

  labels = {
    environment    = var.environment
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }

  depends_on = [google_project_service.tenant_apis]
}

# Cloud Deploy service account
resource "google_service_account" "cloud_deploy_sa" {
  project      = data.google_project.tenant_app.project_id
  account_id   = "cloud-deploy-sa"
  display_name = "Cloud Deploy Service Account"
  description  = "Service account for Cloud Deploy pipeline"
}

# Storage bucket for deployment artifacts
resource "google_storage_bucket" "deployment_artifacts" {
  project  = data.google_project.tenant_app.project_id
  name     = "${data.google_project.tenant_app.project_id}-deploy-artifacts"
  location = var.primary_region

  # Compliance settings
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  # Using Google-managed encryption keys (GMEK) for deployment artifacts

  labels = {
    environment    = var.environment
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }
}


# Grant Cloud Deploy service account access to deployment artifacts bucket
resource "google_storage_bucket_iam_member" "cloud_deploy_artifacts_access" {
  bucket = google_storage_bucket.deployment_artifacts.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}



# IAM permissions for Cloud Deploy service account on tenant project
resource "google_project_iam_member" "cloud_deploy_tenant_permissions" {
  for_each = toset([
    "roles/clouddeploy.jobRunner",
    "roles/clouddeploy.releaser",
    "roles/container.clusterViewer",
    "roles/artifactregistry.reader",
    "roles/artifactregistry.writer",
    "roles/storage.objectAdmin",
    "roles/logging.viewer",
    "roles/cloudbuild.builds.builder"
  ])

  project = data.google_project.tenant_app.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}

# Grant Cloud Build service account access to artifact registry
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  project    = data.google_project.tenant_app.project_id
  location   = var.primary_region
  repository = google_artifact_registry_repository.webapp_images.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Grant Cloud Build service account access to read from GCS (needed for Cloud Deploy render)
resource "google_project_iam_member" "cloudbuild_storage_viewer" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Grant Cloud Build service account access to create logs
resource "google_project_iam_member" "cloudbuild_logs_writer" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Grant Cloud Deploy service account access to push images to Artifact Registry
resource "google_artifact_registry_repository_iam_member" "cloud_deploy_writer" {
  project    = data.google_project.tenant_app.project_id
  location   = var.primary_region
  repository = google_artifact_registry_repository.webapp_images.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}

# Removed org-level cluster IAM permissions - now using project-specific clusters

# Removed prod cluster admin permissions - now handled in project-specific clusters