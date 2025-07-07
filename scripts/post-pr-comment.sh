#!/usr/bin/env bash
set -e

PR_ID=$(cat /workspace/pr_number.txt)

# Only post comment if we have a numeric PR number
if [[ "$PR_ID" =~ ^[0-9]+$ ]]; then
  PREVIEW_URL="https://pr${PR_ID}.webapp.u2i.dev"
  BUILD_URL="https://console.cloud.google.com/cloud-build/builds;region=${REGION}/$BUILD_ID?project=${PROJECT_ID}"
  
  curl -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/u2i/webapp-team-app/issues/${PR_ID}/comments \
    -d "{
      \"body\": \"🚀 **Preview deployment started!**\\n\\nYour preview will be available at: ${PREVIEW_URL}\\n\\nDeployment usually takes 5-10 minutes to complete.\\n\\n[View Build](${BUILD_URL})\"
    }"
  
  echo "Posted comment to PR #${PR_ID}"
else
  echo "Skipping PR comment - not a numeric PR number: $PR_ID"
fi