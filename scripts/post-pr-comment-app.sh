#!/usr/bin/env bash
set -e

echo "=== Starting post-pr-comment-app.sh ==="

# Check if pr_number.txt exists
if [ ! -f /workspace/pr_number.txt ]; then
  echo "ERROR: /workspace/pr_number.txt not found"
  echo "Make sure get-pr-number.sh ran successfully"
  exit 1
fi

PR_ID=$(cat /workspace/pr_number.txt)
echo "PR ID from file: '$PR_ID'"

# Only post comment if we have a numeric PR number
if [[ "$PR_ID" =~ ^[0-9]+$ ]]; then
  PREVIEW_URL="https://pr${PR_ID}.webapp.u2i.dev"
  BUILD_URL="https://console.cloud.google.com/cloud-build/builds;region=${REGION}/$BUILD_ID?project=${PROJECT_ID}"
  
  # Get GitHub App credentials from Secret Manager
  echo "Fetching GitHub App credentials..."
  APP_ID=$(gcloud secrets versions access latest --secret=github-pr-app-id --project=u2i-bootstrap 2>&1)
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to fetch github-pr-app-id: $APP_ID"
    exit 1
  fi
  echo "Got App ID: $APP_ID"
  
  PRIVATE_KEY_CONTENT=$(gcloud secrets versions access latest --secret=github-pr-app-private-key --project=u2i-bootstrap 2>&1)
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to fetch github-pr-app-private-key: $PRIVATE_KEY_CONTENT"
    exit 1
  fi
  echo "Got private key (${#PRIVATE_KEY_CONTENT} characters)"
  
  # Save private key to temp file
  PRIVATE_KEY_FILE="/tmp/github-app-private-key.pem"
  echo "$PRIVATE_KEY_CONTENT" > "$PRIVATE_KEY_FILE"
  chmod 600 "$PRIVATE_KEY_FILE"
  
  # Generate JWT token
  echo "Generating GitHub App JWT..."
  JWT=$(scripts/github-app-token.sh "$APP_ID" "$PRIVATE_KEY_FILE")
  
  # Get installation ID for the repository
  echo "Getting GitHub App installation..."
  INSTALLATION_RESPONSE=$(curl -s -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/app/installations)
  
  # Find installation for u2i org
  INSTALLATION_ID=$(echo "$INSTALLATION_RESPONSE" | jq -r '.[] | select(.account.login == "u2i") | .id')
  
  if [ -z "$INSTALLATION_ID" ]; then
    echo "ERROR: Could not find GitHub App installation for u2i org"
    rm -f "$PRIVATE_KEY_FILE"
    exit 1
  fi
  
  # Get installation access token
  echo "Getting installation access token..."
  TOKEN_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens)
  
  ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token')
  
  if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "ERROR: Could not get installation access token"
    echo "Response: $TOKEN_RESPONSE"
    rm -f "$PRIVATE_KEY_FILE"
    exit 1
  fi
  
  # Check for existing comment from this app
  echo "Checking for existing preview deployment comment..."
  COMMENTS=$(curl -s -H "Authorization: token $ACCESS_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/u2i/webapp-team-app/issues/${PR_ID}/comments)
  
  # Look for existing comment with our marker
  COMMENT_ID=$(echo "$COMMENTS" | jq -r '.[] | select(.body | contains("<!-- gcp-preview-deployment -->")) | .id' | head -1)
  
  COMMENT_BODY="<!-- gcp-preview-deployment -->\n🚀 **Preview deployment updated!**\n\nYour preview will be available at: ${PREVIEW_URL}\n\nDeployment usually takes 5-10 minutes to complete.\n\n[View Build](${BUILD_URL})\n\n_Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")_"
  
  if [ -n "$COMMENT_ID" ] && [ "$COMMENT_ID" != "null" ]; then
    # Update existing comment
    echo "Updating existing comment #${COMMENT_ID}..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH \
      -H "Authorization: token $ACCESS_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/u2i/webapp-team-app/issues/comments/${COMMENT_ID} \
      -d "{
        \"body\": \"$COMMENT_BODY\"
      }")
  else
    # Create new comment
    echo "Creating new comment on PR #${PR_ID}..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
      -H "Authorization: token $ACCESS_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/u2i/webapp-team-app/issues/${PR_ID}/comments \
      -d "{
        \"body\": \"$COMMENT_BODY\"
      }")
  fi
  
  HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
  RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
  
  # Clean up
  rm -f "$PRIVATE_KEY_FILE"
  
  if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
    echo "Successfully updated PR #${PR_ID} comment"
  else
    echo "WARNING: Failed to update comment on PR #${PR_ID}"
    echo "HTTP Status: $HTTP_STATUS"
    echo "Response: $RESPONSE_BODY"
    # Don't fail the build for comment posting issues
    exit 0
  fi
else
  echo "Skipping PR comment - not a numeric PR number: $PR_ID"
fi