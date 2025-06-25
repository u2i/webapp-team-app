stack {
  name        = "webapp-nonprod"
  description = "Webapp non-production environment"
  id          = "8e2f9a16-3c21-8b67-f890-123456789012"
  tags        = ["app", "webapp", "nonprod", "boundary-nonprod"]
}

globals {
  environment    = "nonprod"
  boundary       = "nonprod"
  project_id     = "u2i-tenant-webapp"
  project_number = "310843575960"
  
  # Domain for this boundary
  root_domain     = global.nonprod_domain
  webapp_subdomain = global.app_name
  
  # Service account for this boundary (from bootstrap)
  app_service_account = "terraform-webapp-nonprod@u2i-bootstrap.iam.gserviceaccount.com"
}

generate_hcl "_backend.tf" {
  content {
    terraform {
      backend "gcs" {
        bucket                      = global.shared_state_bucket
        prefix                      = "${global.shared_state_prefix}/apps/${global.app_name}/${global.boundary}"
        impersonate_service_account = "terraform-shared@u2i-bootstrap.iam.gserviceaccount.com"
      }
    }
  }
}

generate_hcl "_providers.tf" {
  content {
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
      project                     = var.project_id
      region                      = global.primary_region
      impersonate_service_account = global.app_service_account
    }

    provider "google-beta" {
      project                     = var.project_id
      region                      = global.primary_region
      impersonate_service_account = global.app_service_account
    }
  }
}

generate_hcl "_data_sources.tf" {
  content {
    # Reference organization outputs
    data "terraform_remote_state" "organization" {
      backend = "gcs"
      config = {
        bucket                      = global.shared_state_bucket
        prefix                      = "${global.shared_state_prefix}/foundation/organization"
        impersonate_service_account = "terraform-shared@u2i-bootstrap.iam.gserviceaccount.com"
      }
    }
    
    # Reference security outputs
    data "terraform_remote_state" "security" {
      backend = "gcs"
      config = {
        bucket                      = global.shared_state_bucket
        prefix                      = "${global.shared_state_prefix}/foundation/security"
        impersonate_service_account = "terraform-shared@u2i-bootstrap.iam.gserviceaccount.com"
      }
    }
  }
}