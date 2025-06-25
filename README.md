# U2I Infrastructure

Terramate-based infrastructure management for U2I organization.

## Structure

```
.
├── foundation/           # Organization-wide foundational resources
│   ├── 0-bootstrap/     # Bootstrap: State bucket, shared service accounts
│   ├── 1-organization/  # Organization: Folders, policies, groups
│   └── 2-security/      # Security: Audit logging, PAM, monitoring
├── apps/                # Application stacks (webapp-like projects)
│   └── webapp/          # Example webapp with prod/nonprod boundaries
└── modules/             # Shared Terraform modules
```

## Key Concepts

### Boundaries
Each app has two "boundaries" (not Terramate environments):
- `prod`: Production resources
- `nonprod`: Non-production resources (dev, staging, etc.)

### State Management
- Single shared state bucket: `u2i-terraform-shared-state`
- State paths: `terramate/<stack-path>`
- Impersonation: All stacks use the shared terraform service account

### Service Accounts
- **Shared SA**: `terraform-shared@u2i-bootstrap.iam.gserviceaccount.com` (org-wide permissions)
- **App SAs**: Each app boundary has its own SA with project-level permissions
- **GitHub Actions**: Uses workload identity federation

## Getting Started

### Prerequisites
```bash
# Install Terramate
brew install terramate

# Install Terraform
brew install terraform

# Authenticate with Google Cloud
gcloud auth application-default login
```

### Initialize Terramate
```bash
# Initialize Terramate
terramate init

# List all stacks
terramate list

# Generate code for all stacks
terramate generate
```

### Deploy Foundation
Foundation stacks must be deployed in order:

```bash
# 1. Bootstrap (creates state bucket and shared SAs)
cd foundation/0-bootstrap
terraform init
terraform apply

# 2. Organization (after bootstrap)
cd ../1-organization
terramate run terraform init
terramate run terraform apply

# 3. Security (after organization)
cd ../2-security
terramate run terraform init
terramate run terraform apply
```

### Deploy Apps
Apps can be deployed independently:

```bash
# Deploy webapp prod
cd apps/webapp/prod
terramate run terraform init
terramate run terraform apply

# Deploy webapp nonprod
cd apps/webapp/nonprod
terramate run terraform init
terramate run terraform apply
```

### Using Terramate Commands
```bash
# Run command in all stacks
terramate run terraform plan

# Run in stacks with specific tags
terramate run --tags foundation terraform apply

# Run in changed stacks only
terramate run --changed terraform apply
```

## Adding a New App

1. Copy the webapp template:
```bash
cp -r apps/webapp apps/myapp
```

2. Update the Terramate configuration in `apps/myapp/terramate.tm.hcl`

3. Update variables in `apps/myapp/{prod,nonprod}/terraform.tfvars`

4. Deploy:
```bash
cd apps/myapp/prod
terramate run terraform init
terramate run terraform apply
```

## CI/CD

GitHub Actions workflows are provided for:
- Plan on PR
- Apply on merge to main
- Drift detection (scheduled)

The workflows use workload identity federation for authentication.

## Security

- All state is encrypted at rest
- Service accounts follow least privilege principle
- Audit logging enabled for all operations
- PAM (Privileged Access Manager) for emergency access