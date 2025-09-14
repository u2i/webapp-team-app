#!/bin/bash
# Run CI tests with proper database setup
# This script can be used both locally and in CI environments

set -e

echo "🚀 Starting CI test suite..."

# Wait for database to be ready
echo "⏳ Waiting for database..."
for i in {1..30}; do
  if pg_isready -h ${TEST_DATABASE_HOST:-localhost} -p ${TEST_DATABASE_PORT:-5432} -U ${TEST_DATABASE_USER:-postgres} 2>/dev/null; then
    echo "✅ Database is ready!"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ Database failed to start"
    exit 1
  fi
  sleep 1
done

# Run migrations
echo "📝 Running migrations..."
npm run migrate:test

# Run integration tests
echo "🧪 Running integration tests..."
npm run test:integration

# Run API tests
echo "🔍 Running API tests..."
npx jest app.test.js --coverage=false

echo "✅ All tests passed!"