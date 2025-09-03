# Testing Documentation

## Overview

This application implements comprehensive testing at multiple stages of the deployment pipeline to ensure code quality, security, and compliance.

## Test Execution Points

### 1. Local Development

```bash
# Install dependencies
npm install

# Run tests with coverage
npm test

# Run tests in CI mode
npm run test:ci
```

### 2. Pull Request (GitHub Actions)

- Triggered automatically on PR creation/update
- Runs full test suite
- Validates Docker build
- Checks compliance requirements
- Posts results as PR comment

### 3. Cloud Build Pipeline

- Tests run before Docker image build
- Pipeline fails if tests don't pass
- Applies to: dev, qa, preview deployments

### 4. Docker Build

- Multi-stage Dockerfile runs tests in first stage
- Production image only built if tests pass
- Ensures deployed code is tested

## Test Suite Structure

### Unit Tests (`app.test.js`)

#### API Endpoint Tests

- `GET /health` - Health check endpoint
- `GET /ready` - Readiness check endpoint
- `GET /` - Main application endpoint
- `GET /info` - Application information endpoint

#### Compliance Tests

- GDPR data residency verification
- Compliance standards validation
- Security header checks

#### Performance Tests

- Response time validation (<100ms for health checks)
- Load testing for critical endpoints

## Test Configuration

### Jest Configuration (`jest.config.js`)

```javascript
{
  testEnvironment: 'node',
  coverageThresholds: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
}
```

### Required Coverage

- **Branches**: 80%
- **Functions**: 80%
- **Lines**: 80%
- **Statements**: 80%

## Running Tests

### Local Testing

```bash
# Run all tests
npm test

# Run with watch mode
npm test -- --watch

# Run specific test file
npm test app.test.js

# Generate coverage report
npm test -- --coverage
```

### CI Testing

```bash
# Run in CI mode (no watch, coverage summary)
npm run test:ci
```

### Docker Testing

```bash
# Build image (runs tests automatically)
docker build -t webapp:test .

# If build succeeds, tests passed
docker run -p 8080:8080 webapp:test
```

## Test Failures

### What Happens When Tests Fail

1. **Local Development**
   - Jest shows failed test details
   - Coverage report indicates untested code
   - Exit code 1 prevents accidental commits

2. **Pull Request**
   - GitHub Actions workflow fails
   - PR cannot be merged (branch protection)
   - Comment posted with failure details
   - Developer must fix and push updates

3. **Cloud Build**
   - Build stops at test step
   - No image pushed to registry
   - No deployment occurs
   - Slack notification sent (if configured)

4. **Docker Build**
   - Build fails at test stage
   - No production image created
   - Error visible in build logs

## Writing New Tests

### Test Structure

```javascript
describe('Feature Name', () => {
  beforeEach(() => {
    // Setup
  });

  it('should do something specific', async () => {
    // Arrange
    const expected = 'value';

    // Act
    const result = await someFunction();

    // Assert
    expect(result).toBe(expected);
  });

  afterEach(() => {
    // Cleanup
  });
});
```

### Best Practices

1. **Descriptive Names**: Use clear test descriptions
2. **Single Responsibility**: One assertion per test
3. **Isolation**: Tests shouldn't depend on each other
4. **Cleanup**: Always close servers/connections
5. **Mocking**: Mock external dependencies
6. **Coverage**: Aim for meaningful coverage, not 100%

## Debugging Tests

### Common Issues

| Problem               | Solution                                        |
| --------------------- | ----------------------------------------------- |
| Port already in use   | Use port 0 for random port in tests             |
| Timeout errors        | Increase Jest timeout: `jest.setTimeout(10000)` |
| Module not found      | Clear Jest cache: `npm test -- --clearCache`    |
| Async issues          | Always use async/await or return promises       |
| Environment variables | Set in beforeEach, clean in afterEach           |

### Debug Commands

```bash
# Run tests with verbose output
npm test -- --verbose

# Run single test
npm test -- --testNamePattern="should return healthy status"

# Debug with Node inspector
node --inspect-brk node_modules/.bin/jest --runInBand

# Show individual test timing
npm test -- --verbose --logHeapUsage
```

## Continuous Improvement

### Metrics to Track

- Test execution time
- Coverage trends
- Flaky test frequency
- Test failure rate by component

### Regular Reviews

- Weekly: Review failed tests in CI
- Monthly: Coverage report analysis
- Quarterly: Test suite optimization

## Integration with CI/CD

### GitHub Actions

- Workflow: `.github/workflows/pr-tests.yml`
- Runs on every PR
- Required for merge to main

### Cloud Build

- Added to all build configurations
- Runs before image build
- Prevents bad deployments

### Docker

- Multi-stage build with test stage
- Tests embedded in build process
- Guarantees tested images

## Support

For test-related issues:

- **Team**: webapp-team@u2i.com
- **Platform**: platform-team@u2i.com
- **Compliance**: compliance@u2i.com
