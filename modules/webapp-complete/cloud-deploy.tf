# Cloud Deploy Pipeline Configuration for webapp-team
# This creates the delivery pipeline for the webapp's dedicated GKE cluster

# Cloud Deploy Delivery Pipeline
resource "google_clouddeploy_delivery_pipeline" "webapp_pipeline" {
  project     = data.google_project.tenant_app.project_id
  location    = var.primary_region
  name        = "webapp-delivery-pipeline"
  description = "Delivery pipeline for webapp using dedicated cluster"

  serial_pipeline {
    stages {
      # Single stage deployment to the webapp cluster
      # Environment differentiation handled by profiles and namespaces
      target_id = google_clouddeploy_target.webapp_cluster.name
      # Profile selection happens at deploy time via skaffold
      
      deploy_parameters {
        values = {
          environment = var.environment
        }
      }
    }
  }

  labels = {
    team           = "webapp-team"
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    environment    = var.environment
  }

  depends_on = [google_project_service.tenant_apis]
}

# Target for webapp's dedicated cluster
resource "google_clouddeploy_target" "webapp_cluster" {
  project     = data.google_project.tenant_app.project_id
  location    = var.primary_region
  name        = "${var.environment}-webapp-cluster"
  description = "Webapp dedicated GKE cluster - ${var.environment}"

  gke {
    cluster = google_container_cluster.webapp_cluster.id
  }

  execution_configs {
    usages              = ["RENDER", "DEPLOY", "VERIFY"]
    service_account     = google_service_account.cloud_deploy_sa.email
    artifact_storage    = google_storage_bucket.deployment_artifacts.url
  }

  # Only require approval in production environment
  require_approval = var.environment == "prod" ? true : false

  labels = {
    environment    = var.environment
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    cluster_type   = "dedicated"
  }
}

# Grant Cloud Deploy SA permissions on the webapp cluster
resource "google_project_iam_member" "cloud_deploy_cluster_admin" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}

# Outputs
output "cloud_deploy_pipeline" {
  value = google_clouddeploy_delivery_pipeline.webapp_pipeline.name
  description = "Name of the Cloud Deploy pipeline"
}

output "cloud_deploy_target" {
  value = google_clouddeploy_target.webapp_cluster.name
  description = "Cloud Deploy target name"
}

output "webapp_cluster_id" {
  value = google_container_cluster.webapp_cluster.id
  description = "Full resource ID of the webapp GKE cluster"
}