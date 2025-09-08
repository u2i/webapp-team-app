#!/bin/bash

# AlloyDB Integration Test Script
# This script tests all aspects of the AlloyDB integration with IAM authentication

set -e

echo "========================================="
echo "AlloyDB Integration Test Suite"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
NAMESPACE="webapp-dev"
SERVICE="dev-webapp-service"
TEST_PORT=9999

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

# Function to cleanup port-forward
cleanup() {
    if [ ! -z "$PF_PID" ]; then
        kill $PF_PID 2>/dev/null || true
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo "1. Checking Pod Status"
echo "----------------------"
POD_COUNT=$(kubectl get pods -n $NAMESPACE -l app=webapp --no-headers | grep "2/2" | wc -l)
if [ $POD_COUNT -ge 1 ]; then
    print_result 0 "Pods running with both containers (app + auth proxy)"
    kubectl get pods -n $NAMESPACE -l app=webapp
else
    print_result 1 "Pods not healthy"
    exit 1
fi
echo ""

echo "2. Checking Auth Proxy Status"
echo "-----------------------------"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=webapp --no-headers | head -1 | awk '{print $1}')
PROXY_STATUS=$(kubectl logs $POD_NAME -c alloydb-auth-proxy -n $NAMESPACE --tail=100 | grep -c "The proxy has started successfully" || echo 0)
if [ $PROXY_STATUS -gt 0 ]; then
    print_result 0 "Auth Proxy started successfully"
    echo "Recent Auth Proxy connections:"
    kubectl logs $POD_NAME -c alloydb-auth-proxy -n $NAMESPACE --tail=10 | grep -E "accepted connection|client closed" | tail -5
else
    print_result 1 "Auth Proxy not started"
fi
echo ""

echo "3. Checking Database Connection"
echo "-------------------------------"
DB_STATUS=$(kubectl logs $POD_NAME -c webapp -n $NAMESPACE --tail=100 | grep -c "Database connection pool initialized successfully" || echo 0)
if [ $DB_STATUS -gt 0 ]; then
    print_result 0 "Database connection initialized"
else
    print_result 1 "Database connection failed"
    echo "Recent webapp logs:"
    kubectl logs $POD_NAME -c webapp -n $NAMESPACE --tail=20
fi
echo ""

echo "4. Testing Application Endpoints"
echo "--------------------------------"

# Start port-forward in background
echo "Setting up port-forward..."
kubectl port-forward svc/$SERVICE $TEST_PORT:80 -n $NAMESPACE > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Test health endpoint
echo -n "Testing /health endpoint... "
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:$TEST_PORT/health 2>/dev/null | tail -1)
if [ "$HEALTH_RESPONSE" = "200" ]; then
    print_result 0 "Health check passed"
    curl -s http://localhost:$TEST_PORT/health | jq -c '.'
else
    print_result 1 "Health check failed (HTTP $HEALTH_RESPONSE)"
fi

# Test root endpoint
echo -n "Testing / endpoint... "
ROOT_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:$TEST_PORT/ 2>/dev/null | tail -1)
if [ "$ROOT_RESPONSE" = "200" ]; then
    print_result 0 "Root endpoint accessible"
else
    print_result 1 "Root endpoint failed (HTTP $ROOT_RESPONSE)"
fi

# Test feedback stats endpoint
echo -n "Testing /feedback/stats/summary endpoint... "
STATS_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:$TEST_PORT/feedback/stats/summary 2>/dev/null | tail -1)
if [ "$STATS_RESPONSE" = "200" ]; then
    print_result 0 "Feedback stats endpoint working"
    echo "Stats data:"
    curl -s http://localhost:$TEST_PORT/feedback/stats/summary | jq -c '.'
else
    print_result 1 "Feedback stats failed (HTTP $STATS_RESPONSE)"
fi
echo ""

echo "5. Database Verification"
echo "------------------------"

# Check if test-proxy pod exists
if kubectl get pod test-proxy -n $NAMESPACE > /dev/null 2>&1; then
    echo "Using test-proxy pod for database verification..."
    
    # Check tables
    echo -n "Checking database tables... "
    TABLE_COUNT=$(kubectl exec test-proxy -c psql -n $NAMESPACE -- psql -h localhost -p 5432 -U "webapp-k8s@u2i-tenant-webapp-nonprod.iam" -d webapp_dev -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null | tr -d ' ')
    if [ "$TABLE_COUNT" -gt 0 ]; then
        print_result 0 "Found $TABLE_COUNT tables"
        echo "Tables in database:"
        kubectl exec test-proxy -c psql -n $NAMESPACE -- psql -h localhost -p 5432 -U "webapp-k8s@u2i-tenant-webapp-nonprod.iam" -d webapp_dev -c "\dt" 2>/dev/null
    else
        print_result 1 "No tables found"
    fi
    
    # Check migrations
    echo -n "Checking migrations... "
    MIGRATION_COUNT=$(kubectl exec test-proxy -c psql -n $NAMESPACE -- psql -h localhost -p 5432 -U "webapp-k8s@u2i-tenant-webapp-nonprod.iam" -d webapp_dev -t -c "SELECT COUNT(*) FROM pgmigrations;" 2>/dev/null | tr -d ' ')
    if [ "$MIGRATION_COUNT" -gt 0 ]; then
        print_result 0 "Found $MIGRATION_COUNT migrations"
    else
        print_result 1 "No migrations found"
    fi
else
    echo -e "${YELLOW}Warning:${NC} test-proxy pod not found, skipping direct database verification"
fi
echo ""

echo "6. Network Policy Verification"
echo "------------------------------"
NP_EXISTS=$(kubectl get networkpolicy -n $NAMESPACE -o name | grep -c webapp-network-policy || echo 0)
if [ $NP_EXISTS -gt 0 ]; then
    print_result 0 "Network policy exists"
    
    # Check for metadata server rule
    METADATA_RULE=$(kubectl get networkpolicy dev-webapp-network-policy -n $NAMESPACE -o yaml | grep -c "169.254.169.254" || echo 0)
    if [ $METADATA_RULE -gt 0 ]; then
        print_result 0 "Metadata server access configured"
    else
        print_result 1 "Metadata server access missing"
    fi
    
    # Check for AlloyDB rule
    ALLOYDB_RULE=$(kubectl get networkpolicy dev-webapp-network-policy -n $NAMESPACE -o yaml | grep -c "10.152.0.0" || echo 0)
    if [ $ALLOYDB_RULE -gt 0 ]; then
        print_result 0 "AlloyDB network access configured"
    else
        print_result 1 "AlloyDB network access missing"
    fi
else
    print_result 1 "Network policy not found"
fi
echo ""

echo "7. Workload Identity Verification"
echo "---------------------------------"
SA_ANNOTATION=$(kubectl get sa webapp -n $NAMESPACE -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null)
if [ ! -z "$SA_ANNOTATION" ]; then
    print_result 0 "Workload Identity configured: $SA_ANNOTATION"
    
    # Check IAM binding
    echo -n "Checking IAM binding... "
    BINDING_EXISTS=$(gcloud iam service-accounts get-iam-policy $SA_ANNOTATION --format=json 2>/dev/null | jq -r '.bindings[].members[]' | grep -c "webapp-dev/webapp" || echo 0)
    if [ $BINDING_EXISTS -gt 0 ]; then
        print_result 0 "Workload Identity binding exists"
    else
        print_result 1 "Workload Identity binding missing"
    fi
else
    print_result 1 "Workload Identity not configured"
fi
echo ""

echo "8. AlloyDB Instance Status"
echo "--------------------------"
INSTANCE_STATE=$(gcloud alloydb instances describe webapp-nonprod-alloydb-primary --cluster=webapp-nonprod-alloydb --region=europe-west1 --project=u2i-tenant-webapp-nonprod --format="value(state)" 2>/dev/null || echo "UNKNOWN")
if [ "$INSTANCE_STATE" = "READY" ]; then
    print_result 0 "AlloyDB instance is READY"
    echo "Instance details:"
    gcloud alloydb instances describe webapp-nonprod-alloydb-primary --cluster=webapp-nonprod-alloydb --region=europe-west1 --project=u2i-tenant-webapp-nonprod --format="table(name,state,instanceType,availabilityType,ipAddress)" 2>/dev/null
else
    print_result 1 "AlloyDB instance state: $INSTANCE_STATE"
fi
echo ""

echo "========================================="
echo "Test Summary"
echo "========================================="
echo ""
echo -e "${GREEN}AlloyDB integration is fully operational!${NC}"
echo ""
echo "Key components verified:"
echo "• Pods running with Auth Proxy sidecars"
echo "• Database connection established"
echo "• Application endpoints responsive"
echo "• Network policies correctly configured"
echo "• Workload Identity functioning"
echo "• AlloyDB instance accessible"
echo ""
echo "The application is successfully using AlloyDB with IAM authentication."