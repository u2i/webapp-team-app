# Variables for webapp project deployment

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (prod or nonprod)"
  type        = string
  validation {
    condition     = contains(["prod", "nonprod"], var.environment)
    error_message = "Environment must be either 'prod' or 'nonprod'."
  }
}

# New boundary-stage-tier variables
variable "boundary" {
  description = "Security boundary (prod, nonprod)"
  type        = string
  default     = ""
  validation {
    condition     = var.boundary == "" || contains(["prod", "nonprod"], var.boundary)
    error_message = "Boundary must be either 'prod' or 'nonprod'."
  }
}

variable "stage" {
  description = "Deployment stage (dev, qa, staging, preprod, prod, preview-*)"
  type        = string
  default     = ""
  validation {
    condition     = var.stage == "" || can(regex("^(dev|qa|staging|preprod|prod|preview-.+)$", var.stage))
    error_message = "Stage must be one of: dev, qa, staging, preprod, prod, or preview-{id}."
  }
}

variable "tier" {
  description = "Resource tier (standard, perf, ci, preview)"
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["standard", "perf", "ci", "preview"], var.tier)
    error_message = "Tier must be one of: standard, perf, ci, preview."
  }
}

variable "mode" {
  description = "Runtime mode (production, development, test)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["production", "development", "test"], var.mode)
    error_message = "Mode must be one of: production, development, test."
  }
}

variable "root_domain" {
  description = "Root domain for DNS (e.g., u2i.dev or u2i.com)"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID for tenant projects"
  type        = string
}

variable "primary_region" {
  description = "Primary region for resources (Belgium/EU deployment)"
  type        = string
  default     = "europe-west1"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "u2i"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "webapp-team-infrastructure"
}

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "webapp-cluster"
}

variable "gke_subnet_cidr" {
  description = "CIDR range for GKE subnet"
  type        = string
  default     = "10.2.0.0/20"
}

variable "gke_pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.32.0.0/14"
}

variable "gke_services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.36.0.0/16"
}

variable "gke_master_cidr" {
  description = "CIDR range for GKE master"
  type        = string
  default     = "172.16.2.0/28"
}

variable "gke_project_id" {
  description = "GKE project ID where clusters are deployed"
  type        = string
  default     = ""  # Not used in per-app cluster architecture
}

variable "resource_version" {
  description = "Optional version suffix for resources that don't delete cleanly (e.g. workload identity pools)"
  type        = string
  default     = ""
  validation {
    condition     = var.resource_version == "" || can(regex("^v[0-9]+$", var.resource_version))
    error_message = "Resource version must be empty or in format 'v1', 'v2', etc."
  }
}

variable "organization_domain" {
  description = "Organization domain for group email addresses"
  type        = string
  default     = "u2i.com"
}

variable "validate_groups" {
  description = "Whether to validate that Google groups exist"
  type        = bool
  default     = false
}

variable "enable_audit_access" {
  description = "Whether to grant audit access to auditors group"
  type        = bool
  default     = false
}

variable "webapp_subdomain" {
  description = "Subdomain for the webapp (will be under root_domain)"
  type        = string
  default     = "webapp"
}

variable "create_project" {
  description = "Whether to create the project"
  type        = bool
  default     = true
}

variable "skip_group_creation" {
  description = "Skip creating groups (use existing ones)"
  type        = bool
  default     = false
}

variable "deploy_k8s_resources" {
  description = "Whether to deploy Kubernetes resources (set to false on first run)"
  type        = bool
  default     = false
}

variable "groups" {
  description = "Map of group names to email addresses (when skip_group_creation is true)"
  type        = map(string)
  default     = {}
}

variable "additional_labels" {
  description = "Additional labels to merge with default labels"
  type        = map(string)
  default     = {}
}

variable "gke_min_nodes" {
  description = "Minimum number of nodes in GKE node pool"
  type        = number
  default     = 3
}

variable "gke_max_nodes" {
  description = "Maximum number of nodes in GKE node pool"
  type        = number
  default     = 10
}