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

  // Try to fetch from Secret Manager
  if (!PROJECT_ID) {
    console.log('No PROJECT_ID found, database features disabled');
    return null;
  }

  try {
    // Construct the secret name based on boundary (nonprod/prod)
    // Infrastructure creates secrets as webapp-{boundary}-neon-db-connection
    const secretName = `webapp-${BOUNDARY}-neon-db-connection`;
    const name = `projects/${PROJECT_ID}/secrets/${secretName}/versions/latest`;
    
    console.log(`Fetching database credentials from Secret Manager: ${secretName}`);
    
    // Create Secret Manager client when needed
    const secretClient = new SecretManagerServiceClient();
    
    const [version] = await secretClient.accessSecretVersion({ name });
    const payload = version.payload.data.toString('utf8');
    
    console.log('Successfully retrieved database credentials from Secret Manager');
    return payload;
  } catch (error) {
    console.error('Failed to fetch database credentials from Secret Manager:', error.message);
    console.log('Database features will be disabled');
    return null;
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
        dbConfig.connectionString = databaseUrl;
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