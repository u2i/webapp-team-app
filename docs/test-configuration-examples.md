# Test Configuration Examples for Different Platforms

This document provides example test configurations for various technology stacks that can be used in `.compliance-cli.yml`.

## Node.js / Express

```yaml
tests:
  enabled: true
  runner_image: node:18-alpine
  commands:
    install: npm ci
    test: npm run test:ci
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## Elixir / Phoenix

```yaml
tests:
  enabled: true
  runner_image: elixir:1.15-alpine
  commands:
    install: |
      mix local.hex --force
      mix local.rebar --force
      mix deps.get
    test: mix test --trace
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## Ruby on Rails

```yaml
tests:
  enabled: true
  runner_image: ruby:3.2-alpine
  commands:
    install: |
      bundle config set --local deployment 'true'
      bundle install
    test: bundle exec rspec --format documentation
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## Python / Django

```yaml
tests:
  enabled: true
  runner_image: python:3.11-alpine
  commands:
    install: |
      pip install --no-cache-dir -r requirements.txt
      pip install --no-cache-dir -r requirements-test.txt
    test: python manage.py test --parallel
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## Python / FastAPI

```yaml
tests:
  enabled: true
  runner_image: python:3.11-alpine
  commands:
    install: pip install --no-cache-dir -r requirements.txt pytest pytest-cov
    test: pytest tests/ -v --cov=app --cov-report=term-missing
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## Go

```yaml
tests:
  enabled: true
  runner_image: golang:1.21-alpine
  commands:
    install: go mod download
    test: go test -v -cover ./...
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## Java / Spring Boot

```yaml
tests:
  enabled: true
  runner_image: maven:3.9-openjdk-17-slim
  commands:
    install: mvn dependency:go-offline
    test: mvn test
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## Rust

```yaml
tests:
  enabled: true
  runner_image: rust:1.73-alpine
  commands:
    install: cargo fetch
    test: cargo test --verbose
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## .NET Core / C#

```yaml
tests:
  enabled: true
  runner_image: mcr.microsoft.com/dotnet/sdk:7.0-alpine
  commands:
    install: dotnet restore
    test: dotnet test --logger "console;verbosity=detailed"
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## PHP / Laravel

```yaml
tests:
  enabled: true
  runner_image: php:8.2-alpine
  commands:
    install: |
      apk add --no-cache git
      composer install --no-interaction --prefer-dist
    test: php artisan test --parallel
  success_message: "Tests passed successfully!"
  fail_on_error: true
```

## Advanced Configuration Options

### Multi-Command Testing

For complex test scenarios, you can chain multiple commands:

```yaml
tests:
  enabled: true
  runner_image: node:18-alpine
  commands:
    install: npm ci
    test: |
      npm run lint
      npm run test:unit
      npm run test:integration
      npm run test:e2e
  success_message: "All test suites passed!"
  fail_on_error: true
```

### Custom Test Scripts

You can also reference custom test scripts:

```yaml
tests:
  enabled: true
  runner_image: alpine:3.18
  commands:
    install: |
      apk add --no-cache bash make
      chmod +x ./scripts/install-deps.sh
      ./scripts/install-deps.sh
    test: make test
  success_message: "Tests completed successfully!"
  fail_on_error: true
```

### Conditional Testing

To disable tests for certain environments:

```yaml
tests:
  enabled: false  # Set to false to skip tests
  runner_image: node:18-alpine
  commands:
    install: echo "Tests disabled"
    test: echo "Tests disabled"
  success_message: "Tests skipped"
  fail_on_error: false
```

## Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `enabled` | boolean | Yes | Whether to run tests in the pipeline |
| `runner_image` | string | Yes | Docker image to use for test execution |
| `commands.install` | string | Yes | Command(s) to install dependencies |
| `commands.test` | string | Yes | Command(s) to run tests |
| `success_message` | string | No | Message to display on success (default: "Tests passed!") |
| `fail_on_error` | boolean | No | Whether to fail build on test failure (default: true) |

## Best Practices

1. **Use Alpine Images**: When possible, use Alpine-based images for faster downloads
2. **Cache Dependencies**: Consider using Cloud Build cache for dependencies
3. **Fail Fast**: Keep `fail_on_error: true` to catch issues early
4. **Verbose Output**: Use verbose flags in test commands for better debugging
5. **Timeouts**: Set appropriate timeouts for long-running test suites
6. **Parallel Testing**: Use parallel test execution when supported by the framework

## Migration Guide

When migrating an existing project to use this configuration:

1. Add the `tests` section to your `.compliance-cli.yml`
2. Choose the appropriate example for your platform
3. Adjust commands based on your specific setup
4. Test locally first: `docker run -it <runner_image> sh` then run commands
5. Commit and create a PR to verify tests run correctly
6. Monitor the first few deployments after migration

## Troubleshooting

### Tests Not Running
- Verify `enabled: true` in configuration
- Check that runner_image exists and is accessible
- Ensure commands are properly formatted (use `|` for multi-line)

### Tests Failing in CI but Passing Locally
- Check for environment variable differences
- Verify the runner_image version matches local environment
- Look for missing dependencies in the install command
- Consider adding debugging output to test command

### Build Continuing Despite Test Failures
- Ensure `fail_on_error: true` is set
- Check Cloud Build logs for error handling
- Verify the test command returns non-zero exit code on failure