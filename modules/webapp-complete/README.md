# webapp-complete Module

A comprehensive Terraform module that creates a complete webapp infrastructure including dedicated GKE cluster, networking, CI/CD pipeline, and all supporting resources.

## Overview

This module creates a production-ready webapp infrastructure with:
- Dedicated GKE Autopilot cluster with VPC and networking
- Complete CI/CD pipeline using Cloud Deploy
- DNS management with External DNS
- Config Connector for Kubernetes-native resource management
- Full compliance features (ISO27001, SOC2, GDPR)
- CMEK encryption for all storage resources

## Architecture

This module creates:
1. **GKE Cluster**: Autopilot cluster with dedicated VPC, subnets, NAT, and firewall rules
2. **CI/CD Infrastructure**: Cloud Deploy pipeline, Artifact Registry, GitHub Actions integration
3. **DNS Management**: Dedicated DNS zone and External DNS for automatic record management
4. **Security**: KMS encryption, IAM roles, audit logging, group-based access control
5. **Kubernetes Components**: Config Connector, RBAC, External DNS deployment

## Usage

```hcl
module "webapp" {
  source = "git::https://github.com/u2i/u2i-terraform-modules.git//modules/webapp-complete?ref=v2.0.0"

  project_id      = "my-webapp-prod"
  environment     = "prod"
  billing_account = "01AA86-A09BB4-30E84E"
  
  # GitHub repository for CI/CD
  github_repo = "myorg/webapp-infrastructure"
  
  # Domain configuration
  parent_dns_zone_name = "example-com"
  webapp_subdomain     = "myapp"
  
  # Optional: Custom node configuration
  gke_min_nodes = 3
  gke_max_nodes = 10
}
```

## Features

### Dedicated Infrastructure
- Creates its own GKE cluster for complete isolation
- Dedicated VPC with custom subnets
- Cloud NAT for outbound connectivity
- Firewall rules for security

### CI/CD Pipeline
- Cloud Deploy pipeline with environment progression
- Automated deployments from GitHub Actions
- Artifact Registry with vulnerability scanning
- Approval workflows for production deployments

### DNS and Ingress
- Creates webapp subdomain (e.g., myapp.example.com)
- External DNS for automatic DNS record management
- Load balancer configuration
- SSL certificate management

### Security and Compliance
- CMEK encryption for all storage resources
- Binary Authorization for container security
- Audit logging and monitoring
- Group-based access control
- Compliance labels (ISO27001, SOC2, GDPR)

## Requirements

- Terraform >= 1.6
- Google Cloud Project with billing enabled
- Organization-level permissions for some resources
- DNS zone in parent project (for subdomain delegation)

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project_id | The GCP project ID | string | yes |
| environment | Environment (prod, staging, dev) | string | yes |
| billing_account | Billing account ID | string | yes |
| github_repo | GitHub repository (org/repo format) | string | yes |
| parent_dns_zone_name | Parent DNS zone name | string | yes |
| webapp_subdomain | Subdomain for the webapp | string | yes |
| gke_min_nodes | Minimum nodes for GKE cluster | number | no |
| gke_max_nodes | Maximum nodes for GKE cluster | number | no |

## Outputs

| Name | Description |
|------|-------------|
| gke_cluster_id | GKE cluster ID |
| gke_cluster_endpoint | GKE cluster endpoint |
| artifact_registry_url | Artifact Registry repository URL |
| cloud_deploy_pipeline | Cloud Deploy pipeline name |
| dns_name_servers | DNS name servers for subdomain |
| load_balancer_ip | Reserved IP for load balancer |

## When to Use This Module

Use this module when you need:
- Complete infrastructure isolation
- Dedicated GKE cluster for your application
- Full control over networking and security
- Production-grade infrastructure with compliance
- Complex applications with specific requirements

## When NOT to Use This Module

Consider `u2i-webapp-base` instead when:
- You want to use shared organizational infrastructure
- Cost optimization is a priority
- Your application is simple and doesn't need dedicated resources
- You're deploying to a shared platform