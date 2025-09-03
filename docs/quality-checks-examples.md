# Quality Checks Configuration Examples

This document provides comprehensive examples of static analysis, linting, and formatting configurations for various platforms.

## Node.js / JavaScript / TypeScript

```yaml
# Test configuration
tests:
  enabled: true
  runner_image: node:18-alpine
  commands:
    install: npm ci
    test: npm run test:ci
  success_message: 'Tests passed successfully!'
  fail_on_error: true

# Static Analysis
analysis:
  enabled: true
  runner_image: node:18-alpine
  commands:
    install: npm ci
    analyze: |
      # Security audit
      npm audit --audit-level=high
      # TypeScript type checking
      npx tsc --noEmit || true
      # Dependency license check
      npx license-checker --production --onlyAllow 'MIT;Apache-2.0;BSD;ISC' || true
  success_message: 'Static analysis completed!'
  fail_on_error: false

# Lint
lint:
  enabled: true
  runner_image: node:18-alpine
  commands:
    install: npm ci
    lint: |
      npx eslint . --ext .js,.jsx,.ts,.tsx --max-warnings 0
  success_message: 'Linting passed!'
  fail_on_error: true

# Format
format:
  enabled: true
  runner_image: node:18-alpine
  commands:
    install: npm ci
    check: npx prettier --check "**/*.{js,jsx,ts,tsx,json,css,md}"
  success_message: 'Code formatting verified!'
  fail_on_error: false
```

## Python

```yaml
tests:
  enabled: true
  runner_image: python:3.11-alpine
  commands:
    install: |
      apk add --no-cache gcc musl-dev
      pip install -r requirements.txt
      pip install pytest pytest-cov
    test: pytest tests/ -v --cov=app --cov-report=term-missing
  success_message: 'Tests passed!'
  fail_on_error: true

analysis:
  enabled: true
  runner_image: python:3.11-alpine
  commands:
    install: |
      pip install -r requirements.txt
      pip install bandit safety mypy
    analyze: |
      # Security scanning
      bandit -r . -ll
      # Dependency vulnerability check
      safety check
      # Type checking
      mypy . --ignore-missing-imports || true
  success_message: 'Security analysis completed!'
  fail_on_error: false

lint:
  enabled: true
  runner_image: python:3.11-alpine
  commands:
    install: pip install flake8 pylint
    lint: |
      flake8 . --max-complexity=10
      pylint **/*.py --fail-under=8.0
  success_message: 'Linting passed!'
  fail_on_error: true

format:
  enabled: true
  runner_image: python:3.11-alpine
  commands:
    install: pip install black isort
    check: |
      black --check .
      isort --check-only .
  success_message: 'Format check passed!'
  fail_on_error: false
```

## Go

```yaml
tests:
  enabled: true
  runner_image: golang:1.21-alpine
  commands:
    install: go mod download
    test: go test -v -cover -race ./...
  success_message: 'Tests passed!'
  fail_on_error: true

analysis:
  enabled: true
  runner_image: golang:1.21-alpine
  commands:
    install: |
      go install github.com/securego/gosec/v2/cmd/gosec@latest
      go install honnef.co/go/tools/cmd/staticcheck@latest
    analyze: |
      # Security scanning
      gosec ./...
      # Static analysis
      staticcheck ./...
      # Vet
      go vet ./...
  success_message: 'Static analysis completed!'
  fail_on_error: true

lint:
  enabled: true
  runner_image: golangci/golangci-lint:latest-alpine
  commands:
    install: echo "golangci-lint pre-installed"
    lint: golangci-lint run --timeout=5m
  success_message: 'Linting passed!'
  fail_on_error: true

format:
  enabled: true
  runner_image: golang:1.21-alpine
  commands:
    install: go install golang.org/x/tools/cmd/goimports@latest
    check: |
      test -z "$(gofmt -l .)"
      test -z "$(goimports -l .)"
  success_message: 'Format check passed!'
  fail_on_error: true
```

## Elixir/Phoenix

```yaml
tests:
  enabled: true
  runner_image: elixir:1.15-alpine
  commands:
    install: |
      apk add --no-cache build-base
      mix local.hex --force
      mix local.rebar --force
      mix deps.get
    test: mix test --trace
  success_message: 'Tests passed!'
  fail_on_error: true

analysis:
  enabled: true
  runner_image: elixir:1.15-alpine
  commands:
    install: |
      mix local.hex --force
      mix deps.get
      mix deps.compile
    analyze: |
      # Security audit
      mix deps.audit
      # Unused dependencies
      mix deps.unlock --check-unused
      # Compile warnings as errors
      mix compile --warnings-as-errors
  success_message: 'Analysis completed!'
  fail_on_error: false

lint:
  enabled: true
  runner_image: elixir:1.15-alpine
  commands:
    install: |
      mix local.hex --force
      mix deps.get
      mix archive.install hex credo --force
    lint: mix credo --strict
  success_message: 'Linting passed!'
  fail_on_error: true

format:
  enabled: true
  runner_image: elixir:1.15-alpine
  commands:
    install: |
      mix local.hex --force
      mix deps.get
    check: mix format --check-formatted
  success_message: 'Format check passed!'
  fail_on_error: true
```

## Ruby/Rails

```yaml
tests:
  enabled: true
  runner_image: ruby:3.2-alpine
  commands:
    install: |
      apk add --no-cache build-base postgresql-dev
      bundle install
    test: bundle exec rspec --format documentation
  success_message: 'Tests passed!'
  fail_on_error: true

analysis:
  enabled: true
  runner_image: ruby:3.2-alpine
  commands:
    install: |
      apk add --no-cache build-base
      bundle install
      gem install brakeman bundle-audit
    analyze: |
      # Security scanning
      brakeman --no-pager
      # Dependency audit
      bundle-audit check --update
  success_message: 'Security analysis completed!'
  fail_on_error: false

lint:
  enabled: true
  runner_image: ruby:3.2-alpine
  commands:
    install: |
      apk add --no-cache build-base
      bundle install
      gem install rubocop rubocop-rails rubocop-rspec
    lint: rubocop --parallel
  success_message: 'Linting passed!'
  fail_on_error: true

format:
  enabled: true
  runner_image: ruby:3.2-alpine
  commands:
    install: gem install rubocop
    check: rubocop --auto-correct --dry-run
  success_message: 'Format check passed!'
  fail_on_error: false
```

## Java/Spring Boot

```yaml
tests:
  enabled: true
  runner_image: maven:3.9-openjdk-17-slim
  commands:
    install: mvn dependency:go-offline
    test: mvn test
  success_message: 'Tests passed!'
  fail_on_error: true

analysis:
  enabled: true
  runner_image: maven:3.9-openjdk-17-slim
  commands:
    install: mvn dependency:go-offline
    analyze: |
      # SpotBugs for bug detection
      mvn spotbugs:check
      # Dependency vulnerability check
      mvn dependency-check:check
  success_message: 'Static analysis completed!'
  fail_on_error: false

lint:
  enabled: true
  runner_image: maven:3.9-openjdk-17-slim
  commands:
    install: mvn dependency:go-offline
    lint: mvn checkstyle:check
  success_message: 'Checkstyle passed!'
  fail_on_error: true

format:
  enabled: true
  runner_image: maven:3.9-openjdk-17-slim
  commands:
    install: echo "No install needed"
    check: mvn formatter:validate
  success_message: 'Format check passed!'
  fail_on_error: false
```

## Rust

```yaml
tests:
  enabled: true
  runner_image: rust:1.73-alpine
  commands:
    install: |
      apk add --no-cache musl-dev
      cargo fetch
    test: cargo test --verbose
  success_message: 'Tests passed!'
  fail_on_error: true

analysis:
  enabled: true
  runner_image: rust:1.73-alpine
  commands:
    install: |
      rustup component add clippy
      cargo install cargo-audit
    analyze: |
      # Clippy lints
      cargo clippy -- -D warnings
      # Security audit
      cargo audit
  success_message: 'Analysis completed!'
  fail_on_error: true

lint:
  enabled: true
  runner_image: rust:1.73-alpine
  commands:
    install: rustup component add clippy
    lint: cargo clippy -- -D warnings
  success_message: 'Linting passed!'
  fail_on_error: true

format:
  enabled: true
  runner_image: rust:1.73-alpine
  commands:
    install: rustup component add rustfmt
    check: cargo fmt -- --check
  success_message: 'Format check passed!'
  fail_on_error: true
```

## PHP/Laravel

```yaml
tests:
  enabled: true
  runner_image: php:8.2-alpine
  commands:
    install: |
      apk add --no-cache git
      composer install --no-interaction
    test: php artisan test --parallel
  success_message: 'Tests passed!'
  fail_on_error: true

analysis:
  enabled: true
  runner_image: php:8.2-alpine
  commands:
    install: |
      apk add --no-cache git
      composer install
      composer require --dev phpstan/phpstan psalm/phar
    analyze: |
      # PHPStan static analysis
      vendor/bin/phpstan analyse
      # Psalm type checking
      vendor/bin/psalm --no-cache
  success_message: 'Static analysis completed!'
  fail_on_error: false

lint:
  enabled: true
  runner_image: php:8.2-alpine
  commands:
    install: |
      composer global require squizlabs/php_codesniffer
      export PATH=$PATH:$HOME/.composer/vendor/bin
    lint: phpcs --standard=PSR12 app/
  success_message: 'Linting passed!'
  fail_on_error: true

format:
  enabled: true
  runner_image: php:8.2-alpine
  commands:
    install: composer global require friendsofphp/php-cs-fixer
    check: php-cs-fixer fix --dry-run --diff
  success_message: 'Format check passed!'
  fail_on_error: false
```

## Configuration Strategy

### Development vs Production

For development builds (pushes to main):

- Run all checks but set `fail_on_error: false` for analysis and format
- This provides feedback without blocking development

For production builds (tags/releases):

- Set all `fail_on_error: true` to ensure quality
- Consider running additional security scans

### Performance Optimization

1. **Parallel Execution**: When possible, run analysis, lint, and format in parallel:

```yaml
# In Cloud Build, these can run simultaneously
- name: 'node:18-alpine'
  id: 'lint'
  # no waitFor means it starts immediately

- name: 'node:18-alpine'
  id: 'format'
  # no waitFor means it starts immediately

- name: 'node:18-alpine'
  id: 'tests'
  waitFor: ['lint', 'format'] # Wait for both
```

2. **Caching**: Use Docker layer caching for dependencies:

```yaml
# Create a base image with dependencies
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'deps', '-f', 'Dockerfile.deps', '.']

# Use it in subsequent steps
- name: 'deps'
  id: 'run-tests'
```

3. **Conditional Execution**: Only run expensive checks on certain files:

```yaml
analysis:
  commands:
    analyze: |
      # Only run if source files changed
      if git diff --name-only HEAD^ | grep -q "\.py$"; then
        mypy .
      fi
```

## Gradual Adoption

Start with warnings, then enforce:

### Phase 1 - Information Only

```yaml
lint:
  enabled: true
  fail_on_error: false # Just inform
```

### Phase 2 - Enforce New Code

```yaml
lint:
  commands:
    lint: |
      # Only check changed files
      git diff --name-only HEAD^ | xargs eslint
  fail_on_error: true
```

### Phase 3 - Full Enforcement

```yaml
lint:
  commands:
    lint: eslint .
  fail_on_error: true
```

## Tool Selection Guidelines

| Language              | Analysis                         | Lint            | Format             |
| --------------------- | -------------------------------- | --------------- | ------------------ |
| JavaScript/TypeScript | ESLint, npm audit                | ESLint          | Prettier           |
| Python                | Bandit, Safety, mypy             | Flake8, Pylint  | Black, isort       |
| Go                    | gosec, staticcheck               | golangci-lint   | gofmt, goimports   |
| Ruby                  | Brakeman, bundle-audit           | RuboCop         | RuboCop            |
| Java                  | SpotBugs, OWASP Dependency Check | Checkstyle      | Google Java Format |
| Rust                  | cargo-audit, clippy              | clippy          | rustfmt            |
| PHP                   | PHPStan, Psalm                   | PHP_CodeSniffer | PHP CS Fixer       |
| Elixir                | mix deps.audit                   | Credo           | mix format         |
