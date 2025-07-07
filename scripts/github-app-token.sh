#!/usr/bin/env bash
set -e

# Generate a JWT token for GitHub App authentication
# This script is used by post-pr-comment.sh

APP_ID="$1"
PRIVATE_KEY="$2"

if [ -z "$APP_ID" ] || [ -z "$PRIVATE_KEY" ]; then
  echo "Usage: $0 <app_id> <private_key_path>"
  exit 1
fi

# Generate JWT header
header=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Generate JWT payload
now=$(date +%s)
iat=$((now - 60))  # Issued 60 seconds ago
exp=$((now + 600)) # Expires in 10 minutes
payload=$(echo -n "{\"iat\":$iat,\"exp\":$exp,\"iss\":\"$APP_ID\"}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Create signature
signature=$(echo -n "${header}.${payload}" | openssl dgst -sha256 -sign "$PRIVATE_KEY" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Combine to create JWT
jwt="${header}.${payload}.${signature}"

echo "$jwt"