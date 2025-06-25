# Configure kubectl provider
data "google_client_config" "provider" {}

data "google_container_cluster" "webapp_cluster" {
  name     = var.gke_cluster_name
  location = var.primary_region
  project  = data.google_project.tenant_app.project_id

  depends_on = [google_container_cluster.webapp_cluster]
}

provider "kubectl" {
  host                   = "https://${data.google_container_cluster.webapp_cluster.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.webapp_cluster.master_auth[0].cluster_ca_certificate)
  load_config_file       = false
}