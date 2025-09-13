# Database Integration Tests

This directory contains integration tests that connect to a real PostgreSQL database, similar to Rails/Phoenix testing patterns.

## Structure

- `helpers/database.js` - Database test helpers for setup, teardown, and seeding
- `integration/db.integration.test.js` - Integration tests using real database connections
- `setup.js` - Jest setup file for test environment

## Running Tests

### Quick Start

Run all tests (unit + integration with automatic database setup):
```bash
npm run test:all
```

### Manual Setup

1. Start the test database:
```bash
npm run test:integration:setup
```

2. Run integration tests:
```bash
npm run test:integration:run
```

3. Tear down the test database:
```bash
npm run test:integration:teardown
```

### Individual Test Suites

Run only unit tests:
```bash
npm run test:unit
```

Run only integration tests (requires database):
```bash
npm run test:integration
```

## Test Database Configuration

The test database runs in Docker using PostgreSQL 16:
- Host: localhost
- Port: 5433 (to avoid conflicts with local PostgreSQL)
- Database: webapp_test
- User: postgres
- Password: postgres

You can override these with environment variables:
```bash
TEST_DATABASE_HOST=localhost \
TEST_DATABASE_PORT=5433 \
TEST_DATABASE_NAME=webapp_test \
TEST_DATABASE_USER=postgres \
TEST_DATABASE_PASSWORD=postgres \
npm run test:integration
```

## Test Helpers

### Database Setup

The `setupTestDatabase()` helper:
1. Creates the test database if it doesn't exist
2. Runs all migrations
3. Cleans all tables (except pgmigrations)

### Database Seeding

Use `seedDatabase()` to insert test data:
```javascript
await seedDatabase({
  visits: [
    { endpoint: '/health', user_agent: 'bot', ip_address: '1.1.1.1' },
    { endpoint: '/info', user_agent: 'chrome', ip_address: '2.2.2.2' }
  ],
  featureFlags: [
    { name: 'darkMode', enabled: true },
    { name: 'betaFeatures', enabled: false }
  ],
  feedback: [
    { type: 'bug', message: 'Test bug', user_email: 'test@example.com' }
  ]
});
```

### Database Cleanup

The `resetTestDatabase()` helper truncates all tables (except migrations) between tests.

## Writing Integration Tests

Example test:
```javascript
describe('My Feature', () => {
  beforeAll(async () => {
    await setupTestDatabase();
  });

  afterEach(async () => {
    await resetTestDatabase();
  });

  afterAll(async () => {
    await teardownTestDatabase();
  });

  it('should do something with the database', async () => {
    // Seed test data
    await seedDatabase({
      visits: [{ endpoint: '/test', stage: 'test' }]
    });

    // Test your feature
    const result = await testPool.query('SELECT * FROM visits');
    expect(result.rows).toHaveLength(1);
  });
});
```

## Migrations

The test suite automatically runs migrations before tests. To create a new migration:

```bash
npm run migrate:create -- my_migration_name
```

To manually run migrations on the test database:
```bash
npm run migrate:test
```

## Troubleshooting

### Database Connection Errors

If you get connection errors, ensure Docker is running and the test database is up:
```bash
docker ps | grep webapp-test-db
```

### Port Conflicts

If port 5433 is already in use, change it in:
- `docker-compose.test.yml`
- Update `TEST_DATABASE_PORT` when running tests

### Clean State

To completely reset the test database:
```bash
npm run test:integration:teardown
npm run test:integration:setup
```

## CI/CD Integration

For CI environments, use:
```bash
# GitHub Actions example
- name: Start PostgreSQL
  run: |
    docker run -d \
      -e POSTGRES_PASSWORD=postgres \
      -e POSTGRES_DB=webapp_test \
      -p 5432:5432 \
      postgres:16-alpine

- name: Run Integration Tests
  run: |
    TEST_DATABASE_PORT=5432 npm run test:integration
```