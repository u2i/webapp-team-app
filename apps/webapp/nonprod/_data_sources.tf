// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "terraform_remote_state" "organization" {
  backend = "gcs"
  config = {
    bucket                      = "u2i-tfstate"
    impersonate_service_account = "terraform-shared@u2i-bootstrap.iam.gserviceaccount.com"
    prefix                      = "terramate/foundation/organization"
  }
}
data "terraform_remote_state" "security" {
  backend = "gcs"
  config = {
    bucket                      = "u2i-tfstate"
    impersonate_service_account = "terraform-shared@u2i-bootstrap.iam.gserviceaccount.com"
    prefix                      = "terramate/foundation/security"
  }
}
