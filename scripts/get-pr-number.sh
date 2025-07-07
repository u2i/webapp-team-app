#!/usr/bin/env bash
set -e

echo "=== Starting get-pr-number.sh ==="

# For Cloud Build v2 PR triggers, _PR_NUMBER should be available
if [ -n "$_PR_NUMBER" ]; then
  echo "Using PR number from Cloud Build: $_PR_NUMBER"
  echo "$_PR_NUMBER" > /workspace/pr_number.txt
else
  echo "ERROR: _PR_NUMBER not set by Cloud Build"
  echo "This script should only run on PR triggers"
  exit 1
fi

echo "Final PR identifier: $(cat /workspace/pr_number.txt)"