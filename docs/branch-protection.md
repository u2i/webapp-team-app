# Branch Protection Rules Configuration

This document describes how to configure GitHub branch protection rules to enforce test requirements for the webapp-team-app repository.

## Required GitHub Settings

Navigate to **Settings** → **Branches** → **Add rule** for the `main` branch:

### 1. Branch Protection Rules

Configure the following settings for the `main` branch:

#### Required Status Checks
- ✅ **Require status checks to pass before merging**
  - Search and select these required checks:
    - `Run Tests`
    - `Code Quality`
    - `Test Docker Build`
    - `Compliance Validation`
    - `Required Checks`
    - `Preview deployment` (from Cloud Build trigger)

- ✅ **Require branches to be up to date before merging**

#### Pull Request Requirements
- ✅ **Require a pull request before merging**
  - ✅ Require approvals: **1**
  - ✅ Dismiss stale pull request approvals when new commits are pushed
  - ✅ Require review from CODEOWNERS

#### Additional Protection
- ✅ **Require conversation resolution before merging**
- ✅ **Require signed commits** (optional but recommended)
- ✅ **Include administrators** (enforce for everyone)
- ✅ **Restrict who can push to matching branches**
  - Add teams/users who can merge to main

### 2. Required Workflows

The following GitHub Actions workflows must pass:

| Workflow | File | Description | Required |
|----------|------|-------------|----------|
| PR Tests | `.github/workflows/pr-tests.yml` | Runs unit tests and coverage | ✅ |
| Preview Deploy | Cloud Build Trigger | Creates preview environment | ✅ |

### 3. Cloud Build Integration

Cloud Build status checks are automatically reported to GitHub PRs when:

1. **Cloud Build trigger** is configured with GitHub integration
2. **Preview deployment** trigger is set to report status

#### Configuring Cloud Build Status Reporting

```bash
# Ensure Cloud Build app is installed for the repository
# This is typically done through the GCP Console when creating triggers

# Verify trigger configuration
gcloud builds triggers describe webapp-preview-deployment \
  --project=u2i-tenant-webapp-nonprod \
  --region=europe-west1
```

### 4. Test Failure Handling

When tests fail in any stage:

#### GitHub Actions Test Failures
- PR cannot be merged until tests pass
- Developer must fix failing tests and push new commits
- All checks re-run automatically on new commits

#### Cloud Build Test Failures
- Build stops immediately when tests fail
- No Docker image is created or pushed
- Preview environment is not deployed
- PR comment indicates build failure with link to logs

#### Docker Build Test Failures
- Multi-stage build fails at test stage
- No production image is created
- Build logs show test failure details

### 5. Bypassing Protection (Emergency Only)

In emergencies, administrators can bypass protection:

1. Navigate to PR that needs emergency merge
2. Use "Merge without waiting for requirements" (admin only)
3. **Document reason** in PR description
4. Create follow-up issue to fix tests

⚠️ **Warning**: Bypassing tests should be extremely rare and requires:
- Incident ticket reference
- Post-mortem commitment
- Executive approval for production

### 6. Monitoring Test Health

#### Test Coverage Requirements
Configured in `jest.config.js`:
- Branches: 80%
- Functions: 80%
- Lines: 80%
- Statements: 80%

#### Viewing Test Results
- **PR Comments**: Automated test result comments
- **Actions Tab**: Detailed test logs and artifacts
- **Coverage Reports**: Upload as artifacts in workflow

### 7. CLI Commands for Verification

```bash
# Check branch protection status
gh api repos/:owner/:repo/branches/main/protection

# View required status checks
gh api repos/:owner/:repo/branches/main/protection/required_status_checks

# List recent PR checks
gh pr checks <PR_NUMBER>

# View workflow runs
gh run list --workflow=pr-tests.yml
```

## Rollout Plan

1. **Phase 1 - Soft Launch** (Week 1)
   - Enable workflows but don't require in branch protection
   - Monitor test stability
   - Fix any flaky tests

2. **Phase 2 - Enforcement** (Week 2)
   - Enable branch protection with required checks
   - Team training on test requirements
   - Document common test issues

3. **Phase 3 - Full Protection** (Week 3+)
   - Enable all protection rules
   - Require administrator enforcement
   - Regular test health reviews

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Tests pass locally but fail in CI | Check Node version, ensure `npm ci` used |
| Flaky tests | Add retries, increase timeouts, fix race conditions |
| Coverage below threshold | Write additional tests for uncovered code |
| PR stuck on pending checks | Verify workflows triggered, check GitHub Actions status |

### Support

- **Test Issues**: webapp-team@u2i.com
- **CI/CD Issues**: platform-team@u2i.com
- **Security/Compliance**: compliance@u2i.com