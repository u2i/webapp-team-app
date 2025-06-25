# Groups Configuration
# Centralized definition of group names following the simplified structure

locals {
  # Core groups - use provided groups or defaults
  groups = var.skip_group_creation ? var.groups : {
    admins     = "gcp-admins@${var.organization_domain}"
    approvers  = "gcp-approvers@${var.organization_domain}"
    developers = "gcp-developers@${var.organization_domain}"
    auditors   = "gcp-auditors@${var.organization_domain}"
  }
  
  # Group membership can be validated (optional)
  # This helps ensure groups exist and have members
  validate_groups = var.validate_groups
}

# Note: Group validation is disabled as google_cloud_identity_group 
# data source requires additional APIs and permissions.
# Groups are managed in Google Workspace Admin.

# Output the groups for reference
output "configured_groups" {
  value = local.groups
  description = "Google groups configured for this project"
}