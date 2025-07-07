#!/usr/bin/env bash
set -e

PR_ID=$(cat /workspace/pr_number.txt)

# Only post comment if we have a numeric PR number
if [[ "$PR_ID" =~ ^[0-9]+$ ]]; then
  PREVIEW_URL="https://pr${PR_ID}.webapp.u2i.dev"
  BUILD_URL="https://console.cloud.google.com/cloud-build/builds;region=${REGION}/$BUILD_ID?project=${PROJECT_ID}"
  
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/u2i/webapp-team-app/issues/${PR_ID}/comments \
    -d "{
      \"body\": \"🚀 **Preview deployment started!**\\n\\nYour preview will be available at: ${PREVIEW_URL}\\n\\nDeployment usually takes 5-10 minutes to complete.\\n\\n[View Build](${BUILD_URL})\"
    }")
  
  HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
  RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
  
  if [ "$HTTP_STATUS" = "201" ]; then
    echo "Posted comment to PR #${PR_ID}"
  else
    echo "WARNING: Failed to post comment to PR #${PR_ID}"
    echo "HTTP Status: $HTTP_STATUS"
    echo "Response: $RESPONSE_BODY"
    # Don't fail the build for comment posting issues
    exit 0
  fi
else
  echo "Skipping PR comment - not a numeric PR number: $PR_ID"
fi