# Contributing Guidelines

## 🚨 Golden Rule: All Changes via Pull Request

**NEVER push directly to the `main` branch.** All changes, no matter how small, must go through a pull request for:

- Code review
- Automated testing
- Preview deployment
- Compliance checks

## Development Workflow

### 1. Create a Feature Branch

```bash
# Always branch from main
git checkout main
git pull origin main
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

```bash
# Make your code changes
# Test locally
npm install
npm start

# Commit with conventional commits
git add .
git commit -m "feat: Add new feature"  # or fix:, docs:, refactor:, etc.
```

### 3. Create Pull Request

```bash
# Push your branch
git push origin feature/your-feature-name

# Create PR using GitHub CLI
gh pr create --title "feat: Your feature" --body "Description of changes"

# Or create via GitHub UI
```

### 4. PR Review Process

- [ ] Automated checks will run (compliance, security)
- [ ] Preview environment will be deployed
- [ ] Wait for code review approval
- [ ] Test preview deployment URL provided in PR comment

### 5. Merge

- Only merge after approval
- Use "Squash and merge" for clean history
- Delete branch after merge

## Commit Message Convention

Use conventional commits for clear history:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Test additions/changes
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes

## Branch Naming Convention

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `chore/` - Maintenance tasks

## Testing Requirements

Before creating a PR:

1. **Local Testing**: Run `npm start` and verify locally
2. **Health Check**: Test `/health` endpoint
3. **No Direct Secrets**: Never commit secrets or credentials
4. **Clean Code**: Remove debug logs and commented code

## Preview Deployments

Every PR automatically gets a preview deployment:

- URL: `https://preview-pr<number>.webapp.u2i.dev`
- Automatically cleaned up after merge/close
- Test your changes in a production-like environment

## Emergency Hotfixes

Even for critical fixes:

1. Create a `hotfix/` branch
2. Create PR with `[HOTFIX]` prefix in title
3. Tag relevant reviewers for expedited review
4. Still requires approval before merge

## Code Review Checklist

Reviewers will check:

- [ ] Code follows existing patterns
- [ ] No hardcoded secrets
- [ ] Appropriate error handling
- [ ] Documentation updated if needed
- [ ] Tests added/updated if applicable
- [ ] Preview deployment works correctly

## Questions?

- Check existing docs in `/docs` folder
- Review `CLAUDE.md` for deployment details
- Ask in team Slack channel

Remember: **Every change through a PR, no exceptions!**
