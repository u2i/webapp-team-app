# Configure Google provider
data "google_client_config" "provider" {}

# Note: kubectl provider moved to webapp-k8s module
# The webapp-k8s module should be applied after this module creates the GKE cluster