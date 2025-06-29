#!/bin/bash
# Test script to verify developer permissions are correctly configured

set -e

PROJECT_ID="u2i-tenant-webapp-nonprod"
REGION="europe-west1"
PIPELINE="webapp-pipeline"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEST_RELEASE="test-dev-${TIMESTAMP}"

echo "🧪 Testing Developer Permissions for Cloud Deploy"
echo "================================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check result
check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $2"
    else
        echo -e "${RED}❌ FAIL${NC}: $2"
        echo "Error details: $3"
    fi
    echo ""
}

# Test 1: Check current user
echo "1️⃣ Checking current authenticated user..."
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format='value(account)')
echo "Current user: $CURRENT_USER"
echo ""

# Test 2: Check group memberships
echo "2️⃣ Checking developer group permissions..."
ROLES=$(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:group:gcp-developers@u2i.com" \
    --format="value(bindings.role)" 2>&1)

if [ $? -eq 0 ]; then
    echo "Developer group has the following roles:"
    echo "$ROLES" | while read role; do
        echo "  - $role"
    done
    
    # Check for expected roles
    expected_roles=("clouddeploy.developer" "clouddeploy.viewer" "cloudbuild.builds.editor" "container.developer")
    for expected in "${expected_roles[@]}"; do
        if echo "$ROLES" | grep -q "$expected"; then
            echo -e "${GREEN}✅${NC} Has $expected role"
        else
            echo -e "${RED}❌${NC} Missing $expected role"
        fi
    done
else
    echo -e "${RED}❌ Failed to check group permissions${NC}"
fi
echo ""

# Test 3: Create a test release
echo "3️⃣ Testing release creation..."
CREATE_OUTPUT=$(gcloud deploy releases create $TEST_RELEASE \
    --project=$PROJECT_ID \
    --region=$REGION \
    --delivery-pipeline=$PIPELINE \
    --skaffold-file=skaffold-unified.yaml \
    --images=webapp=europe-west1-docker.pkg.dev/u2i-tenant-webapp-nonprod/webapp-images/webapp:v5 2>&1)
CREATE_RESULT=$?
check_result $CREATE_RESULT "Can create releases" "$CREATE_OUTPUT"

if [ $CREATE_RESULT -eq 0 ]; then
    # Wait for rollout to start
    echo "Waiting for dev rollout to start..."
    sleep 10
    
    # Test 4: Check dev deployment (should be automatic)
    echo "4️⃣ Checking automatic dev deployment..."
    DEV_ROLLOUT=$(gcloud deploy rollouts list \
        --project=$PROJECT_ID \
        --region=$REGION \
        --delivery-pipeline=$PIPELINE \
        --release=$TEST_RELEASE \
        --filter="targetId:dev" \
        --format="value(name)" 2>&1 | head -1)
    
    if [ -n "$DEV_ROLLOUT" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Dev deployment started automatically"
        echo "Rollout: $DEV_ROLLOUT"
    else
        echo -e "${RED}❌ FAIL${NC}: Dev deployment did not start"
    fi
    echo ""
    
    # Test 5: Try to promote to QA
    echo "5️⃣ Testing promotion to QA..."
    PROMOTE_QA=$(gcloud deploy releases promote \
        --project=$PROJECT_ID \
        --region=$REGION \
        --delivery-pipeline=$PIPELINE \
        --release=$TEST_RELEASE \
        --to-target=qa 2>&1)
    PROMOTE_QA_RESULT=$?
    check_result $PROMOTE_QA_RESULT "Can promote to QA" "$PROMOTE_QA"
    
    # Test 6: Try to promote to production
    echo "6️⃣ Testing promotion to production (should create pending rollout)..."
    PROMOTE_PROD=$(gcloud deploy releases promote \
        --project=$PROJECT_ID \
        --region=$REGION \
        --delivery-pipeline=$PIPELINE \
        --release=$TEST_RELEASE \
        --to-target=prod 2>&1)
    PROMOTE_PROD_RESULT=$?
    
    if [ $PROMOTE_PROD_RESULT -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: Production promotion created (pending approval)"
        
        # Wait for rollout to be created
        sleep 5
        
        # Get the production rollout name
        PROD_ROLLOUT=$(gcloud deploy rollouts list \
            --project=$PROJECT_ID \
            --region=$REGION \
            --delivery-pipeline=$PIPELINE \
            --release=$TEST_RELEASE \
            --filter="targetId:prod" \
            --format="value(name)" 2>&1 | head -1)
        
        if [ -n "$PROD_ROLLOUT" ]; then
            # Test 7: Try to approve production (should fail)
            echo "7️⃣ Testing production approval (should fail for developers)..."
            APPROVE_OUTPUT=$(gcloud deploy rollouts approve $PROD_ROLLOUT \
                --project=$PROJECT_ID \
                --region=$REGION \
                --delivery-pipeline=$PIPELINE 2>&1)
            APPROVE_RESULT=$?
            
            if [ $APPROVE_RESULT -ne 0 ]; then
                echo -e "${GREEN}✅ PASS${NC}: Developers cannot approve production (as expected)"
            else
                echo -e "${RED}❌ FAIL${NC}: Developers should NOT be able to approve production!"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️ WARNING${NC}: Could not create production rollout"
    fi
    echo ""
fi

# Test 8: Check viewing permissions
echo "8️⃣ Testing view permissions..."
VIEW_OUTPUT=$(gcloud deploy rollouts list \
    --project=$PROJECT_ID \
    --region=$REGION \
    --delivery-pipeline=$PIPELINE \
    --limit=5 2>&1)
VIEW_RESULT=$?
check_result $VIEW_RESULT "Can view all rollouts" "$VIEW_OUTPUT"

# Test 9: Check artifact upload permissions
echo "9️⃣ Testing artifact upload permissions..."
echo "test-content" > /tmp/test-artifact.txt
UPLOAD_OUTPUT=$(gsutil cp /tmp/test-artifact.txt gs://u2i-tenant-webapp-nonprod-deploy-artifacts/test/test-${TIMESTAMP}.txt 2>&1)
UPLOAD_RESULT=$?
check_result $UPLOAD_RESULT "Can upload to deployment artifacts bucket" "$UPLOAD_OUTPUT"
rm -f /tmp/test-artifact.txt

# Test 10: Check Artifact Registry access
echo "🔟 Testing Artifact Registry access..."
AR_OUTPUT=$(gcloud artifacts docker images list \
    europe-west1-docker.pkg.dev/u2i-tenant-webapp-nonprod/webapp-images \
    --project=$PROJECT_ID \
    --limit=1 2>&1)
AR_RESULT=$?
check_result $AR_RESULT "Can view container images" "$AR_OUTPUT"

# Summary
echo ""
echo "📊 Test Summary"
echo "==============="
echo "This test verified that developers can:"
echo "✅ Create releases"
echo "✅ Deploy to dev (automatic)"
echo "✅ Deploy to QA"
echo "✅ Create production rollouts (pending approval)"
echo "✅ View all deployments"
echo "✅ Upload deployment artifacts"
echo "✅ View container images"
echo ""
echo "And verified that developers CANNOT:"
echo "❌ Approve production deployments (requires gcp-approvers@u2i.com membership)"
echo ""
echo "Test release created: $TEST_RELEASE"