// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
provider "google" {
  impersonate_service_account = "terraform@u2i-tenant-webapp-prod.iam.gserviceaccount.com"
  project                     = var.project_id
  region                      = "europe-west1"
}
provider "google-beta" {
  impersonate_service_account = "terraform@u2i-tenant-webapp-prod.iam.gserviceaccount.com"
  project                     = var.project_id
  region                      = "europe-west1"
}
