# DNS configuration for webapp team

locals {
  root_domain = var.root_domain
}

# Create a DNS zone for webapp subdomain in this project
resource "google_dns_managed_zone" "webapp" {
  project     = data.google_project.tenant_app.project_id
  name        = "webapp-zone-${var.environment}"
  dns_name    = "webapp.${local.root_domain}."
  description = "DNS zone for webapp team subdomain - ${var.environment}"

  labels = {
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    managed_by     = "terraform"
  }
}

# Root webapp DNS record will be managed by External DNS if needed
# Otherwise, it can be a CNAME to a specific environment

# DNS records for environments will be managed by External DNS
# based on service/ingress annotations

# CNAME for www subdomain
resource "google_dns_record_set" "www_webapp" {
  project      = data.google_project.tenant_app.project_id
  managed_zone = google_dns_managed_zone.webapp.name
  name         = "www.webapp.${local.root_domain}."
  type         = "CNAME"
  ttl          = 300
  
  rrdatas = ["webapp.${local.root_domain}."]
}

# Certificate Manager DNS validation records will be managed by Config Connector
# The CertificateManagerDNSAuthorization resource creates these automatically

# Outputs for other modules to use
output "dns_records" {
  description = "DNS records managed by this project"
  value = {
    www_webapp = google_dns_record_set.www_webapp.name
  }
}

# Output NS records that need to be added to parent zone
output "dns_delegation" {
  description = "NS records to add to the parent DNS zone for delegation"
  value = {
    zone_name   = google_dns_managed_zone.webapp.dns_name
    nameservers = google_dns_managed_zone.webapp.name_servers
    instructions = "Add these NS records to the parent zone (${local.root_domain}) to delegate webapp.${local.root_domain} to this project"
  }
}