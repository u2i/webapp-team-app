# Data sources for load balancer resources created by Config Connector

# Read the static IP address created by Config Connector
data "google_compute_global_address" "webapp_dev_ip" {
  count   = var.environment == "nonprod" ? 1 : 0
  project = data.google_project.tenant_app.project_id
  name    = "webapp-dev-ip"
}

# Output the IP for use in DNS
output "webapp_dev_ip" {
  value = var.environment == "nonprod" ? data.google_compute_global_address.webapp_dev_ip[0].address : null
  description = "Static IP address for dev environment load balancer"
}