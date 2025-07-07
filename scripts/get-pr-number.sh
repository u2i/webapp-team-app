#!/usr/bin/env bash
set -e

echo "=== Starting get-pr-number.sh ==="
echo "Current directory: $(pwd)"
echo "Script location: $0"

# Debug: Print all available substitutions
echo "=== Cloud Build Substitutions ==="
echo "COMMIT_SHA: $COMMIT_SHA"
echo "SHORT_SHA: $SHORT_SHA"
echo "_PR_NUMBER: ${_PR_NUMBER:-not set}"
echo "_HEAD_BRANCH: ${_HEAD_BRANCH:-not set}"
echo "_BASE_BRANCH: ${_BASE_BRANCH:-not set}"
echo "BRANCH_NAME: ${BRANCH_NAME:-not set}"
echo "================================"

# First check if the GitHub token is available
if [ -z "$GITHUB_TOKEN" ]; then
  echo "ERROR: GITHUB_TOKEN is not set"
  exit 1
fi

# Method 1: Get PR number from GitHub API using commit SHA
echo "Checking GitHub API for PR associated with commit $COMMIT_SHA..."

# Make the API call and capture the response
API_RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/u2i/webapp-team-app/commits/$COMMIT_SHA/pulls")

# Extract HTTP status code and response body
HTTP_STATUS=$(echo "$API_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$API_RESPONSE" | sed '$d')

echo "GitHub API HTTP Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ]; then
  # Parse PR number from response
  PR_NUMBER=$(echo "$RESPONSE_BODY" | jq -r '.[0].number // empty' 2>/dev/null || echo "")
  
  if [ -n "$PR_NUMBER" ] && [ "$PR_NUMBER" != "null" ] && [ "$PR_NUMBER" != "" ]; then
    echo "$PR_NUMBER" > /workspace/pr_number.txt
    echo "Found PR #$PR_NUMBER from GitHub API"
  else
    echo "ERROR: No PR found in API response"
    exit 1
  fi
else
  echo "ERROR: GitHub API request failed with status $HTTP_STATUS"
  echo "Response: $RESPONSE_BODY"
  exit 1
fi

echo "Final PR identifier: $(cat /workspace/pr_number.txt)"