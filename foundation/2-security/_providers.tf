// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = ">= 1.6"
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
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
