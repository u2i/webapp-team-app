#!/usr/bin/env bash
set -e

echo "=== Starting get-pr-number.sh ==="

# Debug: Show all environment variables related to PR
echo "Debug: Looking for PR-related variables..."
env | grep -i pr || true
env | grep -i pull || true
env | grep -i _NUMBER || true

# Cloud Build v2 with GitHub uses different variable names
PR_NUMBER=""

# Check various possible PR number variables
if [ -n "$_PR_NUMBER" ]; then
  PR_NUMBER="$_PR_NUMBER"
  echo "Found PR number in _PR_NUMBER: $PR_NUMBER"
elif [ -n "$_PULL_REQUEST_NUMBER" ]; then
  PR_NUMBER="$_PULL_REQUEST_NUMBER"
  echo "Found PR number in _PULL_REQUEST_NUMBER: $PR_NUMBER"
elif [ -n "$PULL_REQUEST_NUMBER" ]; then
  PR_NUMBER="$PULL_REQUEST_NUMBER"
  echo "Found PR number in PULL_REQUEST_NUMBER: $PR_NUMBER"
elif [ -n "$_PR" ]; then
  PR_NUMBER="$_PR"
  echo "Found PR number in _PR: $PR_NUMBER"
else
  echo "ERROR: No PR number found in environment variables"
  echo "This script should only run on PR triggers"
  echo "Available substitutions:"
  env | grep "^_" | sort
  exit 1
fi

echo "$PR_NUMBER" > /workspace/pr_number.txt
echo "Final PR identifier: $(cat /workspace/pr_number.txt)"