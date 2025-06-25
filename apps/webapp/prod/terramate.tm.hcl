stack {
  name        = "webapp-prod"
  description = "Webapp production environment"
  id          = "7d1e8f15-2b10-7a56-e789-012345678901"
  tags        = ["app", "webapp", "prod", "boundary-prod"]
}

globals {
  environment    = "prod"
  boundary       = "prod"
  project_id     = "u2i-tenant-webapp-prod"
  project_number = "911966679777"
  
  # Domain for this boundary
  root_domain     = global.prod_domain
  webapp_subdomain = global.app_name
  
  # Service account for this boundary
  app_service_account = "terraform@${global.project_id}.iam.gserviceaccount.com"
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