# Security Monitoring Module

variable "project_id" {
  description = "Security operations project ID"
  type        = string
}

variable "notification_email" {
  description = "Email for security notifications"
  type        = string
}

variable "org_id" {
  description = "Organization ID"
  type        = string
}

variable "enable_threat_detection" {
  description = "Enable threat detection features"
  type        = bool
  default     = true
}

# Alert policies for security events
resource "google_monitoring_alert_policy" "suspicious_iam_changes" {
  count = var.enable_threat_detection ? 1 : 0
  
  project      = var.project_id
  display_name = "Suspicious IAM Changes"
  
  conditions {
    display_name = "IAM role grants to external users"
    
    condition_threshold {
      filter = <<-EOT
        resource.type="audited_resource"
        AND protoPayload.methodName="SetIamPolicy"
        AND protoPayload.authenticationInfo.principalEmail!~".*@${data.google_organization.org.domain}"
      EOT
      
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.security_email.id]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "service_account_key_creation" {
  count = var.enable_threat_detection ? 1 : 0
  
  project      = var.project_id
  display_name = "Service Account Key Creation"
  
  conditions {
    display_name = "Service account key created"
    
    condition_threshold {
      filter = <<-EOT
        resource.type="service_account"
        AND protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"
      EOT
      
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.security_email.id]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Data to get org domain
data "google_organization" "org" {
  organization = var.org_id
}

# Security notification channel
resource "google_monitoring_notification_channel" "security_email" {
  project      = var.project_id
  display_name = "Security Team Email"
  type         = "email"
  
  labels = {
    email_address = var.notification_email
  }
}

# Output alert policy IDs
output "alert_policies" {
  value = {
    suspicious_iam = try(google_monitoring_alert_policy.suspicious_iam_changes[0].id, null)
    sa_key_creation = try(google_monitoring_alert_policy.service_account_key_creation[0].id, null)
  }
}