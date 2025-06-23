# 🚨 Emergency Break Glass Procedure

## How to Activate 1-Hour Emergency Access

### Prerequisites
- You must be either:
  - The failsafe account holder (`gcp-failsafe@u2i.com`)
  - A member of the emergency responders group
- You need `gcloud` CLI installed and authenticated

### Step 1: Request Break Glass Access

```bash
# Request emergency access
gcloud pam grants create \
  --entitlement="break-glass-emergency" \
  --justification="EMERGENCY: [Brief description of emergency]" \
  --requested-duration="3600s" \
  --location="global" \
  --project="u2i-bootstrap"
```

Example:
```bash
gcloud pam grants create \
  --entitlement="break-glass-emergency" \
  --justification="EMERGENCY: Production outage, all service accounts locked out" \
  --requested-duration="3600s" \
  --location="global" \
  --project="u2i-bootstrap"
```

### Step 2: Access Will Be Granted Immediately
- **No approval needed** - The break-glass entitlement has self-approval
- You'll receive organization-wide owner permissions
- Access expires automatically after 1 hour

### Step 3: Verify Access

```bash
# Check your current permissions
gcloud organizations get-iam-policy [ORG_ID]

# Verify you have owner role
gcloud auth list
```

### Step 4: Perform Emergency Actions

With break glass access, you can:
- Fix IAM policies
- Recover locked out accounts
- Restore deleted resources
- Override organization policies
- Access any project in the organization

### Step 5: Document Actions

**IMPORTANT**: Document everything you do:
```bash
# Create an incident log
echo "$(date): [Your action]" >> ~/emergency-incident-$(date +%Y%m%d).log
```

## What Happens When You Activate Break Glass

1. **Immediate Alerts Sent To:**
   - Security team
   - Compliance team
   - CISO
   - All configured notification channels

2. **Audit Logging:**
   - All actions logged to BigQuery audit dataset
   - Real-time monitoring activated
   - Monthly review report generated

3. **Automatic Expiration:**
   - Access revoked after 1 hour
   - No manual cleanup needed

## Example Emergency Scenarios

### Scenario 1: Locked Out Service Accounts
```bash
# Grant temporary access to fix service account
gcloud iam service-accounts add-iam-policy-binding \
  terraform@u2i-bootstrap.iam.gserviceaccount.com \
  --member="user:your-email@u2i.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

### Scenario 2: Corrupted IAM Policy
```bash
# Remove problematic binding
gcloud organizations remove-iam-policy-binding [ORG_ID] \
  --member="[PROBLEMATIC_MEMBER]" \
  --role="[ROLE]"
```

### Scenario 3: Restore Deleted Resources
```bash
# Undelete a project
gcloud projects undelete [PROJECT_ID]
```

## Post-Emergency Checklist

After the emergency:

- [ ] Document all actions taken in incident report
- [ ] Verify systems are restored
- [ ] Review what caused the emergency
- [ ] Update runbooks if needed
- [ ] Schedule post-mortem meeting
- [ ] Check audit logs for any unexpected actions

## Important Notes

⚠️ **Use Only in Real Emergencies**: Break glass access triggers organization-wide alerts

⚠️ **Everything is Logged**: All actions are recorded and reviewed

⚠️ **1 Hour Limit**: Plan your actions - you cannot extend the duration

⚠️ **Coordinate with Team**: Notify your team when using break glass

## Contact Information

- **Security Team**: security@u2i.com
- **On-Call**: Use PagerDuty escalation
- **Compliance**: compliance@u2i.com
- **CISO**: ciso@u2i.com

## Monitoring Dashboard

View real-time break glass usage:
- Cloud Console → Monitoring → Dashboards → "PAM Emergency Access"
- BigQuery audit logs: `u2i-security.audit_logs.pam_activities`