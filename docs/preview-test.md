# Preview Deployment Test

This file is part of a test PR to verify that our preview deployment system works correctly.

## What this tests:

1. GitHub Actions trigger on PR creation
2. Automatic preview deployment to pr-{number}.webapp.u2i.dev
3. 3-stage deployment pipeline (cert → infra → app)
4. PR comment with preview URL
5. Cleanup on PR close

## Expected behavior:

- [ ] PR creates a preview at pr-{number}.webapp.u2i.dev
- [ ] Certificate is provisioned automatically
- [ ] Application shows preview name in response
- [ ] PR gets a comment with the preview URL
- [ ] Closing PR triggers cleanup

## Test endpoint:

The main endpoint should return:
```json
{
  "message": "Hello from webapp-team! v6 - Testing Preview Deployments",
  "preview": "pr-{number}",
  ...
}
```