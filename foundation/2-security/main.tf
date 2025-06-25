# Security Stack - PAM and Advanced Security Features
# Based on gcp-org-compliance 2-security implementation

locals {
  org_id          = var.org_id
  billing_account = var.billing_account
  
  # Groups aligned with GCP Break-Glass Policy v0.7
  groups = {
    developers  = "gcp-developers@${var.domain}"
    prodsupport = "gcp-prodsupport@${var.domain}"
    techlead    = "gcp-techlead@${var.domain}"
    techmgmt    = "gcp-techmgmt@${var.domain}"
    billing     = "gcp-billing@${var.domain}"
  }
}

# Import existing Security folder (created in organization stack)
data "google_folder" "security" {
  folder = "folders/361255560371"  # Existing Security folder
}

# Security project for centralized security services
resource "google_project" "security" {
  name            = "Security Operations"
  project_id      = "${var.org_prefix}-security"
  folder_id       = data.google_folder.security.name
  billing_account = local.billing_account

  labels = {
    environment = "security"
    purpose     = "security-operations"
    compliance  = "iso27001-soc2-gdpr"
  }
}

# Logging project for centralized audit logs
resource "google_project" "logging" {
  name            = "Centralized Logging"
  project_id      = "${var.org_prefix}-logging"
  folder_id       = data.google_folder.security.name
  billing_account = local.billing_account

  labels = {
    environment = "security"
    purpose     = "audit-logging"
    compliance  = "iso27001-soc2-gdpr"
  }
}

# Enable required APIs
resource "google_project_service" "security_apis" {
  for_each = toset([
    "privilegedaccessmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "bigquery.googleapis.com",
    "cloudasset.googleapis.com",
    "securitycenter.googleapis.com",
    "cloudfunctions.googleapis.com",
    "pubsub.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "accesscontextmanager.googleapis.com"
  ])

  project = google_project.security.project_id
  service = each.key

  disable_on_destroy = false
}

resource "google_project_service" "logging_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "logging.googleapis.com",
    "storage.googleapis.com"
  ])

  project = google_project.logging.project_id
  service = each.key

  disable_on_destroy = false
}

# BigQuery dataset for audit logs
resource "google_bigquery_dataset" "audit_logs" {
  project    = google_project.logging.project_id
  dataset_id = "audit_logs"
  location   = var.bigquery_location

  description = "Centralized audit logs for compliance and security monitoring"

  default_table_expiration_ms = 34560000000  # 400 days per policy

  access {
    role          = "OWNER"
    user_by_email = var.failsafe_account
  }

  access {
    role          = "READER"
    group_by_email = local.groups.techmgmt
  }

  access {
    role          = "READER"
    group_by_email = local.groups.techlead
  }

  labels = {
    compliance     = "iso27001-soc2-gdpr"
    data_residency = "eu"
    purpose        = "audit-logs"
  }
}

# Service account for GitHub Actions CI/CD
resource "google_service_account" "github_actions" {
  project      = google_project.security.project_id
  account_id   = "github-actions"
  display_name = "GitHub Actions CI/CD"
  description  = "Service account for GitHub Actions automation with PAM elevation"
}

# Notification channels for security alerts
resource "google_monitoring_notification_channel" "security_email" {
  project      = google_project.security.project_id
  display_name = "Security Team Email"
  type         = "email"
  
  labels = {
    email_address = "security@${var.domain}"
  }
}

resource "google_monitoring_notification_channel" "security_slack" {
  count        = var.slack_webhook_url != "" ? 1 : 0
  project      = google_project.security.project_id
  display_name = "Security Alerts Slack"
  type         = "slack"
  
  labels = {
    channel_name = "#security-alerts"
  }
  
  user_labels = {
    webhook_url = var.slack_webhook_url
  }
}

resource "google_monitoring_notification_channel" "oncall_pagerduty" {
  count        = var.pagerduty_service_key != "" ? 1 : 0
  project      = google_project.security.project_id
  display_name = "On-Call PagerDuty"
  type         = "pagerduty"
  
  user_labels = {
    service_key = var.pagerduty_service_key
  }
}

# KMS for security services
resource "google_kms_key_ring" "security" {
  project  = google_project.security.project_id
  name     = "security-keyring"
  location = var.primary_region
}

resource "google_kms_crypto_key" "security_key" {
  name     = "security-key"
  key_ring = google_kms_key_ring.security.id
  
  rotation_period = "7776000s" # 90 days
  
  lifecycle {
    prevent_destroy = true
  }
}

# Access Context Manager - Access Policy
resource "google_access_context_manager_access_policy" "policy" {
  parent = "organizations/${local.org_id}"
  title  = "${var.org_prefix} Access Policy"
}

# Access Levels for VPC SC
resource "google_access_context_manager_access_level" "corp_network" {
  parent = "accessPolicies/${google_access_context_manager_access_policy.policy.name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.policy.name}/accessLevels/corp_network"
  title  = "Corporate Network"
  
  basic {
    conditions {
      ip_subnetworks = var.corporate_ip_ranges
    }
  }
}

resource "google_access_context_manager_access_level" "trusted_users" {
  parent = "accessPolicies/${google_access_context_manager_access_policy.policy.name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.policy.name}/accessLevels/trusted_users"
  title  = "Trusted Users"
  
  basic {
    conditions {
      members = [
        "group:${local.groups.developers}",
        "group:${local.groups.techlead}",
        "group:${local.groups.techmgmt}"
      ]
    }
  }
}

# Security Command Center Configuration
# Note: Since enable_custom_detectors is false, this resource won't be created
# Keeping the resource definition for future use when custom detectors are enabled
resource "google_scc_organization_custom_module" "custom_detectors" {
  for_each = var.enable_custom_detectors ? {
    suspicious_iam = {
      display_name = "Suspicious IAM Changes"
      description  = "Detects unusual IAM permission changes"
      severity     = "HIGH"
    }
    data_exfiltration = {
      display_name = "Potential Data Exfiltration"  
      description  = "Detects large data transfers to external destinations"
      severity     = "CRITICAL"
    }
  } : {}
  
  organization = local.org_id
  display_name = each.value.display_name
  enablement_state = "ENABLED"
  
  custom_config {
    predicate {
      expression = file("${path.module}/detectors/${each.key}.cel")
    }
    
    custom_output {
      properties {
        name = "severity"
        value_expression {
          expression = "\"${each.value.severity}\""
        }
      }
    }
    
    resource_selector {
      resource_types = ["cloudresourcemanager.googleapis.com/Organization"]
    }
    
    severity = each.value.severity
    description = each.value.description
    recommendation = "Review the activity and ensure it's authorized"
  }
}

# Outputs
output "security_project_id" {
  value       = google_project.security.project_id
  description = "Security operations project ID"
}

output "logging_project_id" {
  value       = google_project.logging.project_id
  description = "Centralized logging project ID"
}

output "audit_dataset_id" {
  value       = google_bigquery_dataset.audit_logs.dataset_id
  description = "BigQuery dataset for audit logs"
}

output "notification_channels" {
  value = {
    security_email    = google_monitoring_notification_channel.security_email.id
    security_slack    = try(google_monitoring_notification_channel.security_slack[0].id, "")
    oncall_pagerduty = try(google_monitoring_notification_channel.oncall_pagerduty[0].id, "")
  }
  description = "Notification channel IDs for alerts"
}

output "groups" {
  description = "Map of group names to email addresses per policy v0.7"
  value       = local.groups
}

output "kms_keyring_id" {
  description = "Security KMS keyring ID"
  value       = google_kms_key_ring.security.id
}

output "access_policy_name" {
  description = "Access Context Manager policy name"
  value       = google_access_context_manager_access_policy.policy.name
}