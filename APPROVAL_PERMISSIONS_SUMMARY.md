# Cloud Deploy Approval Permissions Summary

Last Updated: 2025-06-23

## Current Approval Permissions

### ✅ Who Can Approve Production Deployments

1. **`group:gcp-approvers@u2i.com`** - Cloud Deploy Approver Role
   - Organization-level PAM approvers group
   - Has conditional permission to approve only webapp-pipeline deployments
   - Cannot approve deployments for other pipelines

2. **`user:gcp-failsafe@u2i.com`** - Owner Role
   - Emergency failsafe account
   - Has full permissions (use sparingly)

3. **`serviceAccount:terraform@u2i-tenant-webapp.iam.gserviceaccount.com`** - Owner Role
   - Terraform automation account
   - Should not be used for manual approvals

### 👀 Who Can View Deployments (But NOT Approve)

1. **`group:gcp-developers@u2i.com`** - Cloud Deploy Viewer Role
   - Can see all deployments and their status
   - Can view rollout details and logs
   - Cannot approve or reject rollouts

### ❌ Service Accounts That CANNOT Approve

1. **`cloud-deploy-sa@u2i-tenant-webapp.iam.gserviceaccount.com`**
   - Has releaser and jobRunner roles
   - Can create releases and rollouts
   - Cannot approve production deployments

## How to Add Someone to Approvers

To add someone as an approver, they need to be added to the `gcp-approvers@u2i.com` Google Group:

1. Contact your Google Workspace admin
2. Request to add the user to `gcp-approvers@u2i.com`
3. Once added, they will automatically have approval permissions

## Security Model

### Conditional IAM Binding
The `gcp-approvers@u2i.com` group has a conditional IAM binding that restricts approvals to only the webapp-pipeline:

```
Condition: resource.name.startsWith('projects/u2i-tenant-webapp/locations/europe-west1/deliveryPipelines/webapp-pipeline')
```

This ensures that even if someone is in the approvers group, they can only approve deployments for this specific pipeline.

### Separation of Duties
- **Developers** can create releases and view deployments
- **Approvers** can approve production deployments
- **Service Accounts** can automate deployments but not approve

This follows the principle of least privilege and ensures proper separation of duties for compliance.

## Compliance Notes

This setup aligns with:
- **ISO 27001 A.9.2.3** - Management of privileged access rights
- **SOC 2 CC6.1** - Logical access controls
- **GDPR Article 32** - Security of processing

The approval process ensures that production changes are reviewed by authorized personnel before deployment.