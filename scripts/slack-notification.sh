#!/usr/bin/env bash
set -e

echo "=== Sending Slack notification ==="

# Check required variables
if [ -z "$COMMIT_SHA" ] || [ -z "$BUILD_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
  echo "ERROR: Missing required variables for Slack notification"
  exit 1
fi

# Extract commit information
COMMIT_SHA_SHORT=${COMMIT_SHA:0:7}
COMMIT_MESSAGE=$(git log -1 --pretty=%s)
AUTHOR=$(git log -1 --pretty=%an)
DEV_URL="https://dev.webapp.u2i.dev"
BUILD_URL="https://console.cloud.google.com/cloud-build/builds;region=${REGION}/${BUILD_ID}?project=${PROJECT_ID}"

# Get Slack token from Secret Manager
echo "Fetching Slack token..."
SLACK_TOKEN=$(gcloud secrets versions access latest --secret=slack-bot-token --project=u2i-security 2>/dev/null || echo "")

if [ -z "$SLACK_TOKEN" ]; then
  echo "WARNING: Could not fetch Slack token, skipping notification"
  exit 0
fi

# Send Slack notification
echo "Posting to Slack channel #webapp-deployments..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer ${SLACK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "#webapp-deployments",
    "blocks": [
      {
        "type": "header",
        "text": {
          "type": "plain_text",
          "text": "🚀 Dev Deployment Complete"
        }
      },
      {
        "type": "section",
        "fields": [
          {
            "type": "mrkdwn",
            "text": "*Environment:*\nDev"
          },
          {
            "type": "mrkdwn",
            "text": "*Commit:*\n`'"${COMMIT_SHA_SHORT}"'`"
          },
          {
            "type": "mrkdwn",
            "text": "*Author:*\n'"${AUTHOR}"'"
          },
          {
            "type": "mrkdwn",
            "text": "*Message:*\n'"${COMMIT_MESSAGE}"'"
          }
        ]
      },
      {
        "type": "actions",
        "elements": [
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": "View Application"
            },
            "url": "'"${DEV_URL}"'"
          },
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": "View Build"
            },
            "url": "'"${BUILD_URL}"'"
          }
        ]
      }
    ]
  }')

HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" = "200" ]; then
  # Check if Slack API returned ok
  OK_STATUS=$(echo "$RESPONSE_BODY" | jq -r '.ok' 2>/dev/null || echo "false")
  if [ "$OK_STATUS" = "true" ]; then
    echo "✅ Slack notification sent successfully"
  else
    echo "WARNING: Slack API returned error"
    echo "Response: $RESPONSE_BODY"
  fi
else
  echo "WARNING: Failed to send Slack notification"
  echo "HTTP Status: $HTTP_STATUS"
fi

# Don't fail the build for notification issues
exit 0