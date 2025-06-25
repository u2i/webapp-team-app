#!/bin/bash
# Script to set up Cloud Deploy approval permissions

PROJECT_ID="u2i-tenant-webapp"
REGION="europe-west1"
PIPELINE="webapp-pipeline"

echo "🔐 Setting up Cloud Deploy Approval Permissions"
echo "=============================================="

# Function to grant approver role
grant_approver() {
    local member=$1
    local description=$2
    
    echo "Granting approver role to: $member"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="$member" \
        --role="roles/clouddeploy.approver" \
        --condition="expression=resource.name.startsWith('projects/$PROJECT_ID/locations/$REGION/deliveryPipelines/$PIPELINE'),title=webapp-pipeline-approver,description=Can approve deployments for webapp-pipeline only"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully granted approver role to $member"
    else
        echo "❌ Failed to grant approver role to $member"
    fi
    echo ""
}

# Grant approver role to existing organization groups

echo "1. Granting approver role to GCP Approvers group..."
# This group is already defined for PAM approvals at org level
grant_approver "group:gcp-approvers@u2i.com" "GCP PAM Approvers Group"

echo "2. Optionally grant to developers group for non-prod..."
# Uncomment if you want developers to approve non-prod deployments
# Note: Our pipeline only requires approval for production
# grant_approver "group:gcp-developers@u2i.com" "GCP Developers Group"

# Example: Grant approver role to specific users if needed
# grant_approver "user:team-lead@u2i.com" "Team Lead"

echo "📋 Current Approvers:"
echo "===================="
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.role:clouddeploy.approver" \
    --format="table(bindings.members)"

echo ""
echo "📋 Who Can Currently Approve (including owners):"
echo "=============================================="
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.role:clouddeploy.approver OR bindings.role:clouddeploy.admin OR bindings.role:owner" \
    --format="table(bindings.role,bindings.members)"

echo ""
echo "💡 Recommendations:"
echo "=================="
echo "1. Create a Google Group for approvers (e.g., webapp-approvers@u2i.com)"
echo "2. Add team leads and senior engineers to the group"
echo "3. Grant the clouddeploy.approver role to the group"
echo "4. Consider removing owner role from service accounts for production approval"
echo "5. Set up notification emails for the approvers group"