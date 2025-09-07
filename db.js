const { Pool } = require('pg');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');

// Secret Manager configuration
const PROJECT_ID = process.env.PROJECT_ID || process.env.GCP_PROJECT;
const BOUNDARY = process.env.BOUNDARY || 'nonprod';

// Database configuration
let pool = null;
let dbEnabled = false;
let initializationPromise = null;

// Function to fetch database URL from Secret Manager
async function fetchDatabaseUrl() {
  // First check if DATABASE_URL is already provided via environment
  if (process.env.DATABASE_URL) {
    console.log('Using DATABASE_URL from environment variable');
    return process.env.DATABASE_URL;
  }

  // Check for individual database parameters
  if (process.env.DATABASE_HOST) {
    console.log('Using individual database parameters from environment');
    return null; // Will use individual params
  }

  // Check if AlloyDB Auth Proxy is being used (connects via localhost)
  if (process.env.ALLOYDB_AUTH_PROXY === 'true' || process.env.USE_AUTH_PROXY === 'true') {
    console.log('AlloyDB Auth Proxy detected with IAM authentication');
    // No secrets needed - Auth Proxy handles IAM authentication
    const stage = process.env.STAGE || 'dev';
    const iamUser = `webapp-k8s@${PROJECT_ID.replace('u2i-tenant-webapp-', '')}`; // e.g., webapp-k8s@nonprod
    const database = `webapp_${stage}`; // e.g., webapp_dev
    const databaseUrl = `postgresql://${iamUser}@localhost:5432/${database}`;
    console.log(`Connecting as IAM user: ${iamUser}`);
    console.log(`Database: ${database}`);
    return databaseUrl;
  }

  // Try to fetch from Secret Manager (direct connection)
  if (!PROJECT_ID) {
    console.log('No PROJECT_ID found, database features disabled');
    return null;
  }

  try {
    // Construct the secret name based on boundary (nonprod/prod)
    // Infrastructure creates secrets as webapp-{boundary}-alloydb-connection
    const secretName = `webapp-${BOUNDARY}-alloydb-connection`;
    const name = `projects/${PROJECT_ID}/secrets/${secretName}/versions/latest`;
    
    console.log(`Fetching database credentials from Secret Manager: ${secretName}`);
    console.log(`Project: ${PROJECT_ID}`);
    
    // Create Secret Manager client when needed
    console.log('Creating Secret Manager client...');
    const secretClient = new SecretManagerServiceClient();
    console.log('Client created successfully');
    
    console.log('Calling accessSecretVersion...');
    const [version] = await secretClient.accessSecretVersion({ name });
    console.log('Got secret version');
    const payload = version.payload.data.toString('utf8');
    
    console.log('Successfully retrieved database credentials from Secret Manager');
    return payload;
  } catch (error) {
    console.error('Failed to fetch database credentials from Secret Manager:', error.message);
    console.log('Database features will be disabled');
    return null;
  }
}

// Helper function to wait for Auth Proxy to be ready
async function waitForAuthProxy(maxAttempts = 10, delayMs = 3000) {
  const { Client } = require('pg');
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const testClient = new Client({ 
        connectionString: 'postgresql://test@localhost:5432/postgres' 
      });
      await testClient.connect();
      await testClient.end();
      console.log('Auth Proxy is ready');
      return true;
    } catch (error) {
      if (attempt === maxAttempts) {
        console.error('Auth Proxy not ready after', maxAttempts, 'attempts');
        return false;
      }
      console.log(`Waiting for Auth Proxy to be ready... (attempt ${attempt}/${maxAttempts})`);
      await new Promise(resolve => setTimeout(resolve, delayMs));
    }
  }
}

// Helper function to create database if it doesn't exist
async function createDatabaseIfNotExists(connectionString) {
  const { Client } = require('pg');
  
  // Parse the connection string to extract database name
  const url = new URL(connectionString.replace('postgresql://', 'postgres://'));
  const targetDatabase = url.pathname.substring(1);
  
  // Connect to postgres database first
  url.pathname = '/postgres';
  const adminUrl = url.toString();
  
  const client = new Client({ connectionString: adminUrl });
  
  try {
    await client.connect();
    
    // Check if database exists
    const result = await client.query(
      'SELECT 1 FROM pg_database WHERE datname = $1',
      [targetDatabase]
    );
    
    if (result.rows.length === 0) {
      console.log(`Creating database '${targetDatabase}'...`);
      await client.query(`CREATE DATABASE "${targetDatabase}"`);
      console.log(`Database '${targetDatabase}' created successfully`);
    }
  } catch (error) {
    console.error('Error checking/creating database:', error.message);
    // Don't throw - let the connection pool handle the error
  } finally {
    await client.end();
  }
}

// Initialize database connection
async function initializeDatabase() {
  if (initializationPromise) {
    return initializationPromise;
  }

  initializationPromise = (async () => {
    try {
      const databaseUrl = await fetchDatabaseUrl();
      
      // Configure database connection
      const dbConfig = {
        ssl: process.env.DATABASE_SSL_MODE === 'require' 
          ? { rejectUnauthorized: false }
          : process.env.DATABASE_SSL_MODE === 'disable'
          ? false
          : BOUNDARY !== 'local' 
          ? { rejectUnauthorized: false } 
          : false,
        max: 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
      };

      if (databaseUrl) {
        // Use the connection string as-is 
        dbConfig.connectionString = databaseUrl;
        console.log('Using database connection string from Secret Manager');
        
        // Create database if it doesn't exist (for AlloyDB with IAM auth)
        if (process.env.ALLOYDB_AUTH_PROXY === 'true') {
          // Wait for Auth Proxy to be ready
          const proxyReady = await waitForAuthProxy();
          if (!proxyReady) {
            throw new Error('AlloyDB Auth Proxy is not ready');
          }
          await createDatabaseIfNotExists(databaseUrl);
        }
      } else if (process.env.DATABASE_HOST) {
        // Use individual parameters
        dbConfig.host = process.env.DATABASE_HOST;
        dbConfig.port = process.env.DATABASE_PORT || 5432;
        dbConfig.database = process.env.DATABASE_NAME;
        dbConfig.user = process.env.DATABASE_USER;
        dbConfig.password = process.env.DATABASE_PASSWORD;
      } else {
        console.log('No database configuration available');
        return false;
      }

      // Create the connection pool
      pool = new Pool(dbConfig);
      
      // Test the connection
      await pool.query('SELECT 1');
      
      dbEnabled = true;
      console.log('Database connection pool initialized successfully');
      
      // Handle pool errors
      pool.on('error', (err) => {
        console.error('Unexpected database pool error:', err);
      });
      
      return true;
    } catch (error) {
      console.error('Failed to initialize database:', error.message);
      dbEnabled = false;
      pool = null;
      return false;
    }
  })();

  return initializationPromise;
}

// Database helper functions
const db = {
  // Check if database is enabled (now async)
  isEnabled: async () => {
    await initializeDatabase();
    return dbEnabled;
  },

  // Synchronous check (for backward compatibility)
  isEnabledSync: () => dbEnabled,

  // Get the connection pool
  getPool: async () => {
    await initializeDatabase();
    return pool;
  },

  // Execute a query
  query: async (text, params) => {
    await initializeDatabase();
    if (!dbEnabled) {
      throw new Error('Database is not configured');
    }
    try {
      const result = await pool.query(text, params);
      return result;
    } catch (error) {
      console.error('Database query error:', error);
      throw error;
    }
  },

  // Check if migrations have been run (for health checks)
  checkMigrations: async () => {
    await initializeDatabase();
    if (!dbEnabled) {
      return { migrated: false, message: 'Database not enabled' };
    }

    try {
      // Check if migrations table exists
      const result = await db.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_schema = 'public' 
          AND table_name = 'pgmigrations'
        )
      `);
      
      const migrationsTableExists = result.rows[0].exists;
      
      if (!migrationsTableExists) {
        return { migrated: false, message: 'Migrations table does not exist' };
      }
      
      // Get latest migration
      const migrationResult = await db.query(`
        SELECT name, run_on 
        FROM pgmigrations 
        ORDER BY run_on DESC 
        LIMIT 1
      `);
      
      if (migrationResult.rows.length === 0) {
        return { migrated: false, message: 'No migrations have been run' };
      }
      
      return {
        migrated: true,
        latest: migrationResult.rows[0].name,
        runOn: migrationResult.rows[0].run_on
      };
    } catch (error) {
      console.error('Failed to check migrations:', error);
      return { migrated: false, message: error.message };
    }
  },

  // Record a visit
  recordVisit: async (endpoint, userAgent = null, ipAddress = null, responseTime = null) => {
    await initializeDatabase();
    if (!dbEnabled) {
      return { visit: null, totalVisits: 0 };
    }

    try {
      const stage = process.env.STAGE || 'unknown';
      const result = await db.query(`
        INSERT INTO visits (endpoint, user_agent, ip_address, response_time, stage)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *
      `, [endpoint, userAgent, ipAddress, responseTime, stage]);

      const countResult = await db.query('SELECT COUNT(*) FROM visits');
      const totalVisits = parseInt(countResult.rows[0].count);

      return {
        visit: result.rows[0],
        totalVisits
      };
    } catch (error) {
      console.error('Failed to record visit:', error);
      throw error;
    }
  },

  // Get visit statistics
  getVisitStats: async () => {
    await initializeDatabase();
    if (!dbEnabled) {
      return {
        totalVisits: 0,
        uniquePaths: 0,
        recentVisits: []
      };
    }

    try {
      const totalResult = await db.query('SELECT COUNT(*) FROM visits');
      const uniqueResult = await db.query('SELECT COUNT(DISTINCT endpoint) FROM visits');
      const recentResult = await db.query(`
        SELECT * FROM visits 
        ORDER BY timestamp DESC 
        LIMIT 10
      `);

      return {
        totalVisits: parseInt(totalResult.rows[0].count),
        uniquePaths: parseInt(uniqueResult.rows[0].count),
        recentVisits: recentResult.rows
      };
    } catch (error) {
      console.error('Failed to get visit stats:', error);
      throw error;
    }
  },

  // Get feature flags
  getFeatureFlags: async () => {
    await initializeDatabase();
    if (!dbEnabled) {
      return {
        darkMode: false,
        betaFeatures: false,
        debugMode: false
      };
    }

    try {
      const result = await db.query('SELECT name, enabled FROM feature_flags');
      const flags = {};
      result.rows.forEach(row => {
        flags[row.name] = row.enabled;
      });
      return flags;
    } catch (error) {
      console.error('Failed to get feature flags:', error);
      return {
        darkMode: false,
        betaFeatures: false,
        debugMode: false
      };
    }
  },

  // Clean up connections
  cleanup: async () => {
    if (pool) {
      await pool.end();
      pool = null;
      dbEnabled = false;
      console.log('Database connection pool closed');
    }
  }
};

module.exports = db;