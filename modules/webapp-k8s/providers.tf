# Configure kubectl provider
data "google_client_config" "provider" {}

data "google_container_cluster" "webapp_cluster" {
  name     = var.cluster_name
  location = var.cluster_location
  project  = var.project_id
}

provider "kubectl" {
  host                   = "https://${data.google_container_cluster.webapp_cluster.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.webapp_cluster.master_auth[0].cluster_ca_certificate)
  load_config_file       = false
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.webapp_cluster.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.webapp_cluster.master_auth[0].cluster_ca_certificate)
}