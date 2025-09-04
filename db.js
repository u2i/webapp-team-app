const { Pool } = require('pg');

// Database configuration from environment variables
const dbConfig = {
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL_MODE === 'require' ? { rejectUnauthorized: false } : false,
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // How long a client is allowed to remain idle before being closed
  connectionTimeoutMillis: 2000, // How long to wait before timing out when connecting
};

// Alternative configuration using individual environment variables
if (!process.env.DATABASE_URL && process.env.DATABASE_HOST) {
  dbConfig.host = process.env.DATABASE_HOST;
  dbConfig.port = process.env.DATABASE_PORT || 5432;
  dbConfig.database = process.env.DATABASE_NAME;
  dbConfig.user = process.env.DATABASE_USER;
  dbConfig.password = process.env.DATABASE_PASSWORD;
  delete dbConfig.connectionString;
}

// Create connection pool only if database is configured
let pool = null;
let dbEnabled = false;

if (process.env.DATABASE_HOST || process.env.DATABASE_URL) {
  try {
    pool = new Pool(dbConfig);
    dbEnabled = true;
    console.log('Database connection pool created');
  } catch (error) {
    console.error('Failed to create database pool:', error);
  }
}

// Database helper functions
const db = {
  // Check if database is enabled and configured
  isEnabled: () => dbEnabled,

  // Get the connection pool
  getPool: () => pool,

  // Execute a query
  query: async (text, params) => {
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

  // Test database connection
  testConnection: async () => {
    if (!dbEnabled) {
      return { connected: false, message: 'Database not configured' };
    }
    try {
      const result = await pool.query('SELECT NOW() as current_time, version() as db_version');
      return {
        connected: true,
        time: result.rows[0].current_time,
        version: result.rows[0].db_version,
      };
    } catch (error) {
      return {
        connected: false,
        error: error.message,
      };
    }
  },

  // Initialize database schema
  initializeSchema: async () => {
    if (!dbEnabled) {
      console.log('Skipping database initialization - not configured');
      return;
    }

    const schemas = [
      // Create visits table
      `CREATE TABLE IF NOT EXISTS visits (
        id SERIAL PRIMARY KEY,
        path VARCHAR(255) NOT NULL,
        method VARCHAR(10) NOT NULL,
        user_agent TEXT,
        ip_address VARCHAR(45),
        stage VARCHAR(50),
        boundary VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`,
      // Create application_logs table
      `CREATE TABLE IF NOT EXISTS application_logs (
        id SERIAL PRIMARY KEY,
        level VARCHAR(20) NOT NULL,
        message TEXT NOT NULL,
        metadata JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`,
      // Create feature_flags table
      `CREATE TABLE IF NOT EXISTS feature_flags (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) UNIQUE NOT NULL,
        enabled BOOLEAN DEFAULT false,
        description TEXT,
        metadata JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`,
    ];

    try {
      for (const schema of schemas) {
        await pool.query(schema);
      }
      console.log('Database schema initialized successfully');

      // Insert default feature flags if they don't exist
      const defaultFlags = [
        { name: 'new_ui', enabled: false, description: 'Enable new UI design' },
        { name: 'beta_features', enabled: false, description: 'Enable beta features' },
        { name: 'enhanced_logging', enabled: true, description: 'Enable enhanced logging' },
      ];

      for (const flag of defaultFlags) {
        await pool.query(
          `INSERT INTO feature_flags (name, enabled, description) 
           VALUES ($1, $2, $3) 
           ON CONFLICT (name) DO NOTHING`,
          [flag.name, flag.enabled, flag.description]
        );
      }
    } catch (error) {
      console.error('Failed to initialize database schema:', error);
      throw error;
    }
  },

  // Log a visit
  logVisit: async (path, method, userAgent, ipAddress) => {
    if (!dbEnabled) return;

    try {
      await pool.query(
        `INSERT INTO visits (path, method, user_agent, ip_address, stage, boundary) 
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          path,
          method,
          userAgent,
          ipAddress,
          process.env.STAGE || 'unknown',
          process.env.BOUNDARY || 'unknown',
        ]
      );
    } catch (error) {
      console.error('Failed to log visit:', error);
    }
  },

  // Get recent visits
  getRecentVisits: async (limit = 10) => {
    if (!dbEnabled) return [];

    try {
      const result = await pool.query(
        'SELECT * FROM visits ORDER BY created_at DESC LIMIT $1',
        [limit]
      );
      return result.rows;
    } catch (error) {
      console.error('Failed to get recent visits:', error);
      return [];
    }
  },

  // Get feature flag status
  getFeatureFlag: async (name) => {
    if (!dbEnabled) return false;

    try {
      const result = await pool.query(
        'SELECT enabled FROM feature_flags WHERE name = $1',
        [name]
      );
      return result.rows.length > 0 ? result.rows[0].enabled : false;
    } catch (error) {
      console.error('Failed to get feature flag:', error);
      return false;
    }
  },

  // Get all feature flags
  getAllFeatureFlags: async () => {
    if (!dbEnabled) return [];

    try {
      const result = await pool.query('SELECT * FROM feature_flags ORDER BY name');
      return result.rows;
    } catch (error) {
      console.error('Failed to get feature flags:', error);
      return [];
    }
  },

  // Close database connections
  close: async () => {
    if (pool) {
      await pool.end();
      console.log('Database connection pool closed');
    }
  },
};

module.exports = db;