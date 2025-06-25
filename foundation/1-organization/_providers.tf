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
  billing_project       = "u2i-bootstrap"
  region                = "europe-west1"
  user_project_override = true
}
provider "google-beta" {
  billing_project       = "u2i-bootstrap"
  region                = "europe-west1"
  user_project_override = true
}
