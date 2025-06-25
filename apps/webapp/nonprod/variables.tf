variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_number" {
  description = "The GCP project number"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "boundary" {
  description = "Boundary name (prod or nonprod)"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "team" {
  description = "Team name"
  type        = string
}

variable "primary_region" {
  description = "Primary region for resources"
  type        = string
  default     = "europe-west1"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "gke_min_nodes" {
  description = "Minimum number of nodes in the GKE cluster"
  type        = number
  default     = 3
}

variable "gke_max_nodes" {
  description = "Maximum number of nodes in the GKE cluster"
  type        = number
  default     = 10
}

variable "root_domain" {
  description = "Root domain for DNS"
  type        = string
}

variable "webapp_subdomain" {
  description = "Subdomain for the webapp"
  type        = string
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository for infrastructure"
  type        = string
}

variable "app_repo" {
  description = "GitHub repository for application code"
  type        = string
}

variable "default_labels" {
  description = "Default labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "shared_tfstate_bucket" {
  description = "Shared Terraform state bucket"
  type        = string
  default     = "u2i-tfstate"
}

variable "shared_tfstate_prefix" {
  description = "Prefix for shared Terraform state"
  type        = string
  default     = "terramate"
}