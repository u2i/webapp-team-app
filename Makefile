# Makefile for webapp-team-app
# This is a convenience wrapper around bin/compliance-cli

# Default target shows help
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make test-local     - Start local test environment with database"
	@echo "  make test-run       - Run tests in local test environment"
	@echo "  make test-down      - Stop and clean up test environment"
	@echo "  make test-shell     - Open shell in test container"
	@echo "  make test-db        - Connect to test database"
	@echo "  make pipelines      - Generate and apply pipeline configs"
	@echo "  make status         - Show pipeline and environment status"
	@echo "  make dev/qa/prod    - Deploy to respective environments"

# Common operations
.PHONY: pipelines
pipelines:
	@bin/compliance-cli generate pipeline --all --write-dir=deploy/clouddeploy
	@bin/compliance-cli validate pipelines  
	@bin/compliance-cli apply pipelines

.PHONY: status
status:
	@bin/compliance-cli status pipelines
	@bin/compliance-cli status environments

.PHONY: dev
dev:
	@bin/compliance-cli dev

.PHONY: qa
qa:
	@bin/compliance-cli qa

.PHONY: prod
prod:
	@bin/compliance-cli prod --release=$(RELEASE)

# Test environment targets
.PHONY: test-local
test-local:
	@echo "🚀 Starting local test environment..."
	@DB_PORT=$${DB_PORT:-5433} docker compose --profile test up -d
	@echo "✅ Test environment ready! Run 'make test-run' to execute tests"

.PHONY: test-run
test-run:
	@echo "🧪 Running tests in local environment..."
	@docker compose exec app npm run migrate:test
	@docker compose exec app npm run test:integration
	@docker compose exec app npx jest app.test.js --coverage=false

.PHONY: test-shell
test-shell:
	@echo "📂 Opening shell in test container..."
	@docker compose exec app sh

.PHONY: test-db
test-db:
	@echo "🗄️ Connecting to test database..."
	@docker compose exec postgres psql -U postgres -d webapp_test

.PHONY: test-down
test-down:
	@echo "🧹 Cleaning up test environment..."
	@docker compose --profile test down -v
	@echo "✅ Test environment cleaned up"

# CI test target (mimics what runs in Cloud Build)
.PHONY: test-ci
test-ci:
	@echo "🏃 Running CI test suite..."
	@APP_CONTAINER_NAME=ci-app-test POSTGRES_CONTAINER_NAME=ci-postgres-test \
		docker compose -f docker-compose.yml -f docker-compose.ci.yml --profile test up -d --build
	@sleep 5
	@echo "Running migrations..."
	@docker exec ci-app-test npm run migrate:test
	@echo "Running integration tests..."
	@docker exec ci-app-test npm run test:integration
	@echo "Running API tests..."
	@docker exec ci-app-test npx jest app.test.js --coverage=false
	@docker compose -f docker-compose.yml -f docker-compose.ci.yml --profile test down -v

# Production build target
.PHONY: build-prod
build-prod:
	@echo "🏗️ Building production image..."
	@DOCKERFILE=Dockerfile docker build -t webapp:prod .
	@echo "✅ Production image built: webapp:prod"

# All other targets just pass through to compliance-cli
%:
	@bin/compliance-cli $@