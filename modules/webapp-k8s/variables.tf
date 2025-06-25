variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cluster_location" {
  description = "Location of the GKE cluster"
  type        = string
}

variable "config_connector_sa" {
  description = "Email of the Config Connector service account"
  type        = string
}

variable "external_dns_sa" {
  description = "Email of the External DNS service account"
  type        = string
}

variable "cloud_deploy_sa" {
  description = "Email of the Cloud Deploy service account"
  type        = string
}

variable "dns_zone_name" {
  description = "Name of the DNS zone"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain" {
  description = "Domain for the webapp"
  type        = string
}