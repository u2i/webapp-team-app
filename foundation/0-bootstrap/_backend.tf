// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "gcs" {
    bucket                      = "u2i-tfstate"
    impersonate_service_account = "terraform-shared@u2i-bootstrap.iam.gserviceaccount.com"
    prefix                      = "terramate/foundation/bootstrap"
  }
}
