stack {
  name        = "organization"
  description = "Organization-level configuration including folders, policies, and groups"
  id          = "5b9c6d13-0f98-5e34-c567-890123456789"
  tags        = ["foundation", "critical"]
  after       = ["tag:foundation:bootstrap"]
}

globals {
  environment = "prod"
  team        = "platform"
}

generate_hcl "_backend.tf" {
  content {
    terraform {
      backend "gcs" {
        bucket                      = global.shared_state_bucket
        prefix                      = "${global.shared_state_prefix}/foundation/organization"
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
      }
    }

    provider "google" {
      region                      = global.primary_region
      user_project_override       = true
      billing_project             = "u2i-bootstrap"
    }

    provider "google-beta" {
      region                      = global.primary_region
      user_project_override       = true
      billing_project             = "u2i-bootstrap"
    }
  }
}