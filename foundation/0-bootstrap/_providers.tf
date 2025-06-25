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
  }
}
provider "google" {
  project = var.project_id
  region  = "europe-west1"
}
provider "google-beta" {
  project = var.project_id
  region  = "europe-west1"
}
