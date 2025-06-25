variable "org_id" {
  description = "GCP Organization ID"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
}

variable "org_prefix" {
  description = "Organization prefix for resource naming"
  type        = string
  default     = "u2i"
}

variable "domain" {
  description = "Organization domain"
  type        = string
  default     = "u2i.com"
}

variable "primary_region" {
  description = "Primary region for resources"
  type        = string
  default     = "europe-west1"
}

variable "bigquery_location" {
  description = "Location for BigQuery resources"
  type        = string
  default     = "EU"
}

variable "failsafe_account" {
  description = "Failsafe account email"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for security alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "pagerduty_service_key" {
  description = "PagerDuty service key for on-call alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "corporate_ip_ranges" {
  description = "Corporate IP ranges for access levels"
  type        = list(string)
  default     = []
}

variable "enable_custom_detectors" {
  description = "Enable custom threat detectors in Security Command Center"
  type        = bool
  default     = false
}