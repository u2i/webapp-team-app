stack {
  name        = "bootstrap"
  description = "Bootstrap configuration including state bucket and CI/CD service accounts"
  id          = "4a8b5c12-9e87-4d23-b456-789012345678"
  tags        = ["foundation", "critical"]
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
        prefix                      = "${global.shared_state_prefix}/foundation/bootstrap"
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
      project = var.project_id
      region  = global.primary_region
    }

    provider "google-beta" {
      project = var.project_id
      region  = global.primary_region
    }
  }
}