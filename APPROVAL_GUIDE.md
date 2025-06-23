# Cloud Deploy Approval Guide

This guide explains how approvals work in the Cloud Deploy pipeline and how to approve production deployments.

## How Approvals Work

### 1. Approval Requirements
- **Dev**: No approval required (automatic)
- **QA**: No approval required (automatic) 
- **Production**: Manual approval REQUIRED

### 2. Approval Trigger
When a release is promoted to production, Cloud Deploy:
1. Creates a rollout in `PENDING_APPROVAL` state
2. Sends notifications (if configured)
3. Waits for manual approval before deploying

### 3. Who Can Approve
To approve a rollout, you need one of these IAM roles:
- `roles/clouddeploy.approver` (specific permission)
- `roles/clouddeploy.admin` (includes approval)
- `roles/owner` (includes all permissions)

## Approval Methods

### Method 1: Google Cloud Console (Web UI)

1. **Navigate to Cloud Deploy**
   ```
   https://console.cloud.google.com/deploy/delivery-pipelines/europe-west1/webapp-pipeline
   ```

2. **Find Pending Approval**
   - Look for rollouts with "Needs approval" status
   - Or check the "Pending approvals" section

3. **Review and Approve**
   - Click on the rollout
   - Review the changes (manifest diff, etc.)
   - Click "Review"
   - Add optional comment
   - Click "Approve" or "Reject"

### Method 2: gcloud CLI

1. **List Pending Approvals**
   ```bash
   gcloud deploy rollouts list \
     --delivery-pipeline=webapp-pipeline \
     --region=europe-west1 \
     --project=u2i-tenant-webapp \
     --filter="approvalState=NEEDS_APPROVAL"
   ```

2. **Get Rollout Details**
   ```bash
   gcloud deploy rollouts describe ROLLOUT_NAME \
     --release=RELEASE_NAME \
     --delivery-pipeline=webapp-pipeline \
     --region=europe-west1 \
     --project=u2i-tenant-webapp
   ```

3. **Approve the Rollout**
   ```bash
   gcloud deploy rollouts approve ROLLOUT_NAME \
     --release=RELEASE_NAME \
     --delivery-pipeline=webapp-pipeline \
     --region=europe-west1 \
     --project=u2i-tenant-webapp
   ```

4. **Reject the Rollout (if needed)**
   ```bash
   gcloud deploy rollouts reject ROLLOUT_NAME \
     --release=RELEASE_NAME \
     --delivery-pipeline=webapp-pipeline \
     --region=europe-west1 \
     --project=u2i-tenant-webapp
   ```

### Method 3: Cloud Deploy API

```bash
# Approve via API
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{"approved": true}' \
  "https://clouddeploy.googleapis.com/v1/projects/u2i-tenant-webapp/locations/europe-west1/deliveryPipelines/webapp-pipeline/releases/RELEASE_NAME/rollouts/ROLLOUT_NAME:approve"
```

## Example: Approving Current Production Deployment

Based on the current pending approval:

```bash
# Using gcloud CLI
gcloud deploy rollouts approve qa-v1-1-0-20250623-012114-to-prod-gke-0001 \
  --release=qa-v1-1-0-20250623-012114 \
  --delivery-pipeline=webapp-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp
```

## Approval Best Practices

### 1. Review Before Approval
- Check the release notes/reason
- Review manifest changes
- Verify QA testing completed
- Check monitoring/alerts

### 2. Approval Comments
When approving via CLI, add comments:
```bash
gcloud deploy rollouts approve ROLLOUT_NAME \
  --release=RELEASE_NAME \
  --delivery-pipeline=webapp-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp \
  --annotations="approval-reason=Tested in QA, no issues found"
```

### 3. Emergency Approvals
For urgent fixes:
1. Still follow approval process
2. Document emergency reason
3. Perform post-deployment review

## Setting Up Notifications

### Email Notifications
1. Go to Cloud Deploy in Console
2. Click on the pipeline
3. Go to "Notifications"
4. Add email addresses

### Slack/Teams Integration
Use Cloud Functions with Pub/Sub:
```python
# Example Cloud Function for Slack
import json
import requests
from google.cloud import secretmanager

def notify_slack(event, context):
    """Triggered by Cloud Deploy Pub/Sub message"""
    
    message = json.loads(base64.b64decode(event['data']).decode('utf-8'))
    
    if message['approvalState'] == 'NEEDS_APPROVAL':
        slack_message = {
            "text": f"🚨 Production deployment needs approval!\n"
                    f"Release: {message['release']}\n"
                    f"<https://console.cloud.google.com/deploy|Review in Console>"
        }
        
        # Send to Slack webhook
        requests.post(SLACK_WEBHOOK_URL, json=slack_message)
```

## Approval Delegation

### Setting Up Approval Groups
```bash
# Create a Google Group for approvers
# Then grant the group approval permissions

gcloud projects add-iam-policy-binding u2i-tenant-webapp \
  --member="group:prod-approvers@u2i.com" \
  --role="roles/clouddeploy.approver" \
  --condition="expression=resource.name.startsWith('projects/u2i-tenant-webapp/locations/europe-west1/deliveryPipelines/webapp-pipeline'),title=webapp-pipeline-approvers"
```

### Approval Policies
Configure approval requirements in the target:
```yaml
apiVersion: deploy.cloud.google.com/v1
kind: Target
metadata:
  name: prod-gke
spec:
  requireApproval: true
  # Future: multiTarget for canary deployments
  # Future: approvalConfig for multiple approvers
```

## Monitoring Approvals

### View Approval History
```bash
# List all rollouts with approval info
gcloud deploy rollouts list \
  --delivery-pipeline=webapp-pipeline \
  --region=europe-west1 \
  --project=u2i-tenant-webapp \
  --limit=50 \
  --format="table(name,approvalState,approveTime,deployStartTime)"
```

### Audit Logs
```bash
# Check who approved deployments
gcloud logging read \
  'resource.type="clouddeploy.googleapis.com/DeliveryPipeline"
   AND protoPayload.methodName="google.cloud.deploy.v1.CloudDeploy.ApproveRollout"' \
  --project=u2i-tenant-webapp \
  --limit=10 \
  --format=json
```

## Troubleshooting

### "Permission Denied" on Approval
- Check IAM roles: need `clouddeploy.approver` or higher
- Verify project and pipeline names
- Check if using correct authentication

### Approval Button Disabled
- Pipeline might be paused
- Previous stage might have failed
- Check for active Cloud Deploy operations

### Rollout Stuck After Approval
- Check Cloud Build logs
- Verify cluster connectivity
- Check deployment manifest validity