# Audit Access Configuration
# Optional access for auditors group - only created if enabled

# Grant auditors read-only access to billing and logs
resource "google_project_iam_member" "audit_access" {
  for_each = var.enable_audit_access ? toset([
    "roles/billing.viewer",           # View billing information
    "roles/logging.viewer",           # View audit logs
    "roles/cloudasset.viewer",        # View asset inventory
    "roles/iam.securityReviewer",     # Review IAM policies
    "roles/compute.viewer",           # View compute resources
    "roles/storage.objectViewer"      # View storage objects
  ]) : toset([])
  
  project = data.google_project.tenant_app.project_id
  role    = each.key
  member  = "group:${local.groups.auditors}"
}

# Grant auditors access to view monitoring dashboards
resource "google_project_iam_member" "audit_monitoring_access" {
  count = var.enable_audit_access ? 1 : 0
  
  project = data.google_project.tenant_app.project_id
  role    = "roles/monitoring.viewer"
  member  = "group:${local.groups.auditors}"
}

# Output audit configuration
output "audit_access_enabled" {
  value       = var.enable_audit_access
  description = "Whether audit access is enabled"
}

output "audit_access_group" {
  value       = var.enable_audit_access ? local.groups.auditors : ""
  description = "Auditor group email if enabled"
}

output "audit_access_permissions" {
  value = var.enable_audit_access ? [
    "View billing and cost data",
    "View audit logs",
    "View asset inventory",
    "Review IAM policies",
    "View compute and storage resources",
    "View monitoring dashboards"
  ] : []
  description = "List of permissions granted to auditors"
}