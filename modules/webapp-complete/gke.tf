# GKE Cluster for WebApp Team
# This creates a dedicated GKE cluster in the webapp project

# Enable additional APIs for GKE
resource "google_project_service" "gke_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "servicenetworking.googleapis.com",
    "networkmanagement.googleapis.com"
  ])

  project = data.google_project.tenant_app.project_id
  service = each.key

  disable_on_destroy = false
}

# VPC Network for GKE
resource "google_compute_network" "gke_network" {
  project                 = data.google_project.tenant_app.project_id
  name                    = "webapp-gke-network"
  auto_create_subnetworks = false
  description            = "VPC network for webapp GKE cluster"

  depends_on = [google_project_service.gke_apis]
}

# GKE Subnet
resource "google_compute_subnetwork" "gke_subnet" {
  project       = data.google_project.tenant_app.project_id
  name          = "webapp-gke-subnet"
  network       = google_compute_network.gke_network.name
  ip_cidr_range = var.gke_subnet_cidr
  region        = var.primary_region

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.gke_services_cidr
  }

  private_ip_google_access = true
}

# Cloud Router for NAT
resource "google_compute_router" "gke_router" {
  project = data.google_project.tenant_app.project_id
  name    = "webapp-gke-router"
  region  = var.primary_region
  network = google_compute_network.gke_network.id
}

# Cloud NAT for outbound connectivity
resource "google_compute_router_nat" "gke_nat" {
  project = data.google_project.tenant_app.project_id
  name    = "webapp-gke-nat"
  router  = google_compute_router.gke_router.name
  region  = var.primary_region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall rule for health checks
resource "google_compute_firewall" "gke_health_checks" {
  project     = data.google_project.tenant_app.project_id
  name        = "webapp-gke-allow-health-checks"
  network     = google_compute_network.gke_network.name
  description = "Allow GCE health checks for GKE ingress and services"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "10256", "30000-32767"]  # Common app ports, kubelet health, and NodePort range
  }

  source_ranges = [
    "35.191.0.0/16",   # Google Cloud health checks
    "130.211.0.0/22",  # Google Cloud health checks
    "10.0.0.0/8",      # Internal VPC traffic for pod-to-pod and service communication
  ]

  # For Autopilot, we need to target all nodes in the network
  # since we can't control node tags
  source_tags = []
  target_tags = []
}

# Firewall rule for external HTTP/HTTPS traffic to load balancers
resource "google_compute_firewall" "gke_lb_traffic" {
  project     = data.google_project.tenant_app.project_id
  name        = "webapp-gke-allow-http-https"
  network     = google_compute_network.gke_network.name
  description = "Allow external HTTP/HTTPS traffic to GKE load balancers"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]  # Allow from anywhere

  # Target tags will be automatically applied by GKE to the nodes
  target_tags = ["gke-${var.gke_cluster_name}"]
}

# Service account for Config Connector
resource "google_service_account" "config_connector" {
  project      = data.google_project.tenant_app.project_id
  account_id   = "config-connector"
  display_name = "Config Connector Service Account"
  description  = "Service account for Config Connector to manage GCP resources"
}

# Grant Config Connector service account necessary permissions
resource "google_project_iam_member" "config_connector_permissions" {
  for_each = toset([
    "roles/compute.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/storage.admin",
    "roles/dns.admin",
    "roles/certificatemanager.editor"
  ])

  project = data.google_project.tenant_app.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.config_connector.email}"
}

# Data source for project info (still needed for other resources)
data "google_project" "gke_project" {
  project_id = data.google_project.tenant_app.project_id
}

# GKE Autopilot Cluster
resource "google_container_cluster" "webapp_cluster" {
  project  = data.google_project.tenant_app.project_id
  name     = var.gke_cluster_name
  location = var.primary_region

  enable_autopilot = true
  
  # Enable GKE Enterprise features
  fleet {
    project = data.google_project.tenant_app.project_id
  }

  network    = google_compute_network.gke_network.id
  subnetwork = google_compute_subnetwork.gke_subnet.id

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false  # Allow public API access
    master_ipv4_cidr_block = var.gke_master_cidr
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${data.google_project.tenant_app.project_id}.svc.id.goog"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Config Connector will be installed manually (not supported as addon in Autopilot)
  
  # Autopilot clusters automatically handle autoscaling and bursting
  
  # Security configuration
  security_posture_config {
    mode = "ENTERPRISE"
    vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  }
  
  # Using Google-managed encryption keys (GMEK) for database encryption


  resource_labels = {
    environment         = var.environment
    compliance         = "iso27001-soc2-gdpr"
    data_residency     = "eu"
    managed_by         = "webapp-team"
    gdpr_compliant     = "true"
  }

  deletion_protection = var.environment == "prod" ? true : false
  
  # Enable additional GKE Enterprise features
  enable_l4_ilb_subsetting = true
  # Shielded nodes are automatically enabled in Autopilot

  depends_on = [
    google_project_service.gke_apis,
    google_compute_subnetwork.gke_subnet
  ]
}

# Grant Config Connector service account Workload Identity binding
resource "google_service_account_iam_member" "config_connector_workload_identity" {
  service_account_id = google_service_account.config_connector.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${data.google_project.tenant_app.project_id}.svc.id.goog[cnrm-system/cnrm-controller-manager]"

  depends_on = [google_container_cluster.webapp_cluster]
}

# Update Cloud Deploy targets to use the new cluster
resource "google_clouddeploy_target" "webapp_cluster_target" {
  project     = data.google_project.tenant_app.project_id
  location    = var.primary_region
  name        = "webapp-cluster"
  description = "WebApp team GKE cluster target"

  gke {
    cluster = google_container_cluster.webapp_cluster.id
  }

  execution_configs {
    usages           = ["RENDER", "DEPLOY"]
    service_account  = google_service_account.cloud_deploy_sa.email
    artifact_storage = "gs://${google_storage_bucket.deployment_artifacts.name}"
  }

  labels = {
    environment    = var.environment
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }
}

# Update delivery pipeline to use the new target
resource "google_clouddeploy_delivery_pipeline" "webapp_pipeline_updated" {
  project     = data.google_project.tenant_app.project_id
  location    = var.primary_region
  name        = "webapp-pipeline-v2"
  description = "Delivery pipeline for webapp using dedicated cluster"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.webapp_cluster_target.name
      profiles  = [var.environment]
    }
  }

  labels = {
    environment    = var.environment
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    gdpr_compliant = "true"
  }
}

# Grant Cloud Deploy service account permissions on the new cluster
resource "google_project_iam_member" "cloud_deploy_gke_permissions" {
  for_each = toset([
    "roles/container.developer",
    "roles/container.clusterAdmin"
  ])

  project = data.google_project.tenant_app.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_deploy_sa.email}"
}