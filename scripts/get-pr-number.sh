#!/usr/bin/env bash
set -e

# Debug: Print all available substitutions
echo "=== Cloud Build Substitutions ==="
echo "COMMIT_SHA: $COMMIT_SHA"
echo "SHORT_SHA: $SHORT_SHA"
echo "_PR_NUMBER: ${_PR_NUMBER:-not set}"
echo "_HEAD_BRANCH: ${_HEAD_BRANCH:-not set}"
echo "_BASE_BRANCH: ${_BASE_BRANCH:-not set}"
echo "BRANCH_NAME: ${BRANCH_NAME:-not set}"
echo "================================"

# Method 1: Get PR number from GitHub API using commit SHA
echo "Checking GitHub API for PR associated with commit $COMMIT_SHA..."
PR_NUMBER=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/u2i/webapp-team-app/commits/$COMMIT_SHA/pulls" | \
  jq -r '.[0].number // empty' || true)

if [ -n "$PR_NUMBER" ] && [ "$PR_NUMBER" != "null" ]; then
  echo "$PR_NUMBER" > /workspace/pr_number.txt
  echo "Found PR #$PR_NUMBER from GitHub API"
else
  # Fallback to commit SHA
  echo "$SHORT_SHA" > /workspace/pr_number.txt
  echo "WARNING: Could not determine PR number, using commit SHA: $SHORT_SHA"
fi

echo "Final PR identifier: $(cat /workspace/pr_number.txt)"