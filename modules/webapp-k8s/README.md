# WebApp K8s Resources Module

This module deploys Kubernetes resources to an existing GKE cluster created by the webapp-complete module.

## Usage

This module should be applied AFTER the webapp-complete module has successfully created the GKE cluster.

```hcl
module "webapp_k8s" {
  source = "../../../modules/webapp-k8s"
  
  project_id       = var.project_id
  cluster_name     = module.webapp.gke_cluster_name
  cluster_location = var.primary_region
  
  # Service accounts from webapp-complete
  config_connector_sa = module.webapp.config_connector_sa_email
  external_dns_sa     = module.webapp.external_dns_sa_email
  cloud_deploy_sa     = module.webapp.cloud_deploy_sa_email
  
  # DNS zone from webapp-complete
  dns_zone_name = module.webapp.dns_zone_name
}
```