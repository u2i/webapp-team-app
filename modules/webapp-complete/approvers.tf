# Cloud Deploy Approver Configuration
# This implements the simplified groups structure for deployment approvals

# Grant Cloud Deploy approver role to the GCP approvers group
# This group handles production deployment approvals (separate from infrastructure admins)
resource "google_project_iam_member" "cloud_deploy_approvers" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/clouddeploy.approver"
  member  = "group:${local.groups.approvers}"

  # Condition to limit approval to only this pipeline
  condition {
    title       = "webapp-pipeline-approvers"
    description = "Can only approve deployments for webapp-pipeline"
    expression  = "resource.name.startsWith('projects/${data.google_project.tenant_app.project_id}/locations/${var.primary_region}/deliveryPipelines/webapp-pipeline')"
  }
}

# Grant developers ability to create releases and deploy to non-prod
# This allows developers to deploy to dev/qa but not approve production
resource "google_project_iam_member" "cloud_deploy_developers" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/clouddeploy.developer"
  member  = "group:${local.groups.developers}"
}

# Also grant developers the ability to view all deployments
resource "google_project_iam_member" "cloud_deploy_viewers" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/clouddeploy.viewer"
  member  = "group:${local.groups.developers}"
}

# Grant developers access to create Cloud Build builds (needed for releases)
resource "google_project_iam_member" "developers_cloudbuild" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "group:${local.groups.developers}"
}

# Grant developers access to upload source archives
resource "google_storage_bucket_iam_member" "developers_deploy_artifacts" {
  bucket = google_storage_bucket.deployment_artifacts.name
  role   = "roles/storage.objectCreator"
  member = "group:${local.groups.developers}"
}

# Grant developers access to deploy to GKE cluster (non-prod namespaces)
# Note: Namespace restrictions are handled by Kubernetes RBAC
resource "google_project_iam_member" "developers_gke_developer" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/container.developer"
  member  = "group:${local.groups.developers}"
}

# Grant developers access to view Artifact Registry images
resource "google_artifact_registry_repository_iam_member" "developers_reader" {
  project    = data.google_project.tenant_app.project_id
  location   = var.primary_region
  repository = google_artifact_registry_repository.webapp_images.name
  role       = "roles/artifactregistry.reader"
  member     = "group:${local.groups.developers}"
}

# Grant admins ability to perform infrastructure operations
# Admins have broader permissions for infrastructure management
resource "google_project_iam_member" "admin_infrastructure" {
  for_each = toset([
    "roles/resourcemanager.projectIamAdmin",  # Manage IAM
    "roles/compute.admin",                     # Manage compute resources
    "roles/storage.admin",                     # Manage storage
    "roles/cloudkms.admin",                    # Manage encryption keys
    "roles/monitoring.admin"                   # Manage monitoring
  ])
  
  project = data.google_project.tenant_app.project_id
  role    = each.key
  member  = "group:${local.groups.admins}"
}

# Output for documentation
output "cloud_deploy_permissions" {
  value = {
    groups = {
      admins     = local.groups.admins      # Infrastructure management
      approvers  = local.groups.approvers   # Deployment approvals
      developers = local.groups.developers   # Development work
      auditors   = local.groups.auditors    # Audit access (if enabled)
    }
    permissions = {
      admin_permissions = [
        "Infrastructure management and configuration",
        "IAM and security settings",
        "Emergency access via PAM",
        "Can also approve deployments if in approvers group"
      ]
      approver_permissions = [
        "Can approve production deployments",
        "Can view deployment history and logs",
        "Limited to webapp-pipeline only",
        "Cannot modify infrastructure"
      ]
      developer_permissions = [
        "Can create releases and deployments",
        "Can deploy to dev (automatic)",
        "Can deploy to qa (automatic)",
        "Cannot approve production deployments",
        "Can view all deployment status"
      ]
    }
    instructions = "Add users to groups via Google Workspace admin. Clear separation between infrastructure (admins), deployments (approvers), and development (developers)."
  }
  description = "Project permissions configuration following simplified groups structure"
}