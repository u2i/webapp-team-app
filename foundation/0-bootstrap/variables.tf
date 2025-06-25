variable "project_id" {
  description = "The bootstrap project ID"
  type        = string
  default     = "u2i-bootstrap"
}

variable "org_id" {
  description = "The organization ID"
  type        = string
  default     = "981978971260"
}

variable "billing_account" {
  description = "The billing account ID"
  type        = string
  default     = "017E25-21F01C-DF5C27"
}

variable "shared_state_bucket" {
  description = "Name of the shared state bucket"
  type        = string
  default     = "u2i-tfstate"
}

variable "primary_region" {
  description = "Primary region for resources"
  type        = string
  default     = "europe-west1"
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
  default     = "u2i"
}