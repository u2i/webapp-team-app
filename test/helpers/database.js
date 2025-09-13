const { Pool } = require('pg');
const path = require('path');
const { spawn } = require('child_process');

// Test database configuration
const TEST_DB_CONFIG = {
  host: process.env.TEST_DATABASE_HOST || 'localhost',
  port: process.env.TEST_DATABASE_PORT || 5432,
  database: process.env.TEST_DATABASE_NAME || 'webapp_test',
  user: process.env.TEST_DATABASE_USER || 'postgres',
  password: process.env.TEST_DATABASE_PASSWORD || 'postgres',
};

// Create a test database pool
const testPool = new Pool({
  ...TEST_DB_CONFIG,
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

// Helper to create test database if it doesn't exist
async function createTestDatabase() {
  const adminPool = new Pool({
    ...TEST_DB_CONFIG,
    database: 'postgres', // Connect to default database
  });

  try {
    // Check if test database exists
    const result = await adminPool.query(
      'SELECT 1 FROM pg_database WHERE datname = $1',
      [TEST_DB_CONFIG.database]
    );

    if (result.rows.length === 0) {
      console.log(`Creating test database: ${TEST_DB_CONFIG.database}`);
      await adminPool.query(`CREATE DATABASE "${TEST_DB_CONFIG.database}"`);
      console.log('Test database created successfully');
    }
  } catch (error) {
    console.error('Error creating test database:', error);
    throw error;
  } finally {
    await adminPool.end();
  }
}

// Helper to run migrations
async function runMigrations() {
  return new Promise((resolve, reject) => {
    const env = {
      ...process.env,
      DATABASE_URL: `postgresql://${TEST_DB_CONFIG.user}:${TEST_DB_CONFIG.password}@${TEST_DB_CONFIG.host}:${TEST_DB_CONFIG.port}/${TEST_DB_CONFIG.database}`,
    };

    const migrate = spawn('npx', ['node-pg-migrate', 'up'], {
      env,
      stdio: 'inherit',
    });

    migrate.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Migration failed with code ${code}`));
      }
    });

    migrate.on('error', reject);
  });
}

// Helper to clean database (truncate all tables)
async function cleanDatabase() {
  try {
    // Get all table names except migrations
    const result = await testPool.query(`
      SELECT tablename FROM pg_tables 
      WHERE schemaname = 'public' 
      AND tablename != 'pgmigrations'
    `);

    // Truncate all tables
    for (const row of result.rows) {
      await testPool.query(`TRUNCATE TABLE "${row.tablename}" CASCADE`);
    }
  } catch (error) {
    console.error('Error cleaning database:', error);
    throw error;
  }
}

// Helper to seed test data
async function seedDatabase(seeds = {}) {
  try {
    // Seed visits if provided
    if (seeds.visits) {
      for (const visit of seeds.visits) {
        await testPool.query(
          `INSERT INTO visits (endpoint, user_agent, ip_address, response_time, stage, timestamp) 
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            visit.endpoint,
            visit.user_agent,
            visit.ip_address,
            visit.response_time,
            visit.stage || 'test',
            visit.timestamp || new Date(),
          ]
        );
      }
    }

    // Seed feedback if provided
    if (seeds.feedback) {
      for (const item of seeds.feedback) {
        await testPool.query(
          `INSERT INTO user_feedback (feedback_type, subject, message, user_id, status, metadata) 
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            item.feedback_type || item.type || 'other',
            item.subject || 'Test Feedback',
            item.message,
            item.user_id || item.user_email || 'test-user',
            item.status || 'pending',
            JSON.stringify(item.metadata || {}),
          ]
        );
      }
    }

    // Seed feature flags if provided
    if (seeds.featureFlags) {
      for (const flag of seeds.featureFlags) {
        await testPool.query(
          `INSERT INTO feature_flags (name, enabled, description) 
           VALUES ($1, $2, $3)
           ON CONFLICT (name) DO UPDATE SET enabled = $2`,
          [flag.name, flag.enabled, flag.description]
        );
      }
    }
  } catch (error) {
    console.error('Error seeding database:', error);
    throw error;
  }
}

// Setup test database before all tests
async function setupTestDatabase() {
  await createTestDatabase();
  await runMigrations();
  await cleanDatabase();
}

// Clean up after each test
async function resetTestDatabase() {
  await cleanDatabase();
}

// Tear down after all tests
async function teardownTestDatabase() {
  await testPool.end();
}

// Helper to get test database connection string
function getTestDatabaseUrl() {
  return `postgresql://${TEST_DB_CONFIG.user}:${TEST_DB_CONFIG.password}@${TEST_DB_CONFIG.host}:${TEST_DB_CONFIG.port}/${TEST_DB_CONFIG.database}`;
}

module.exports = {
  testPool,
  TEST_DB_CONFIG,
  createTestDatabase,
  runMigrations,
  cleanDatabase,
  seedDatabase,
  setupTestDatabase,
  resetTestDatabase,
  teardownTestDatabase,
  getTestDatabaseUrl,
};