stack {
  name        = "security"
  description = "Security configuration including audit logging, PAM, and monitoring"
  id          = "6c0d7e14-1a09-6f45-d678-901234567890"
  tags        = ["foundation", "critical"]
  after       = ["tag:foundation:organization"]
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
        prefix                      = "${global.shared_state_prefix}/foundation/security"
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
        archive = {
          source  = "hashicorp/archive"
          version = "~> 2.4"
        }
        null = {
          source  = "hashicorp/null"
          version = "~> 3.2"
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
  }
}