/**
 * Centralized application configuration
 */

const { DEFAULT_PORT } = require('./constants');

// Environment configuration with validation
const config = {
  // Server configuration
  port: parseInt(process.env.PORT) || DEFAULT_PORT,
  boundary: process.env.BOUNDARY || 'nonprod',
  stage: process.env.STAGE || 'unknown',
  version: process.env.VERSION || process.env.K_REVISION || 'local',

  // GCP configuration
  projectId: process.env.PROJECT_ID || process.env.GCP_PROJECT,
  region: process.env.REGION || 'europe-west1',

  // Database configuration
  database: {
    host: process.env.DATABASE_HOST,
    port: parseInt(process.env.DATABASE_PORT) || 5432,
    name: process.env.DATABASE_NAME,
    user: process.env.DATABASE_USER,
    password: process.env.DATABASE_PASSWORD,
    url: process.env.DATABASE_URL,
    sslMode: process.env.DATABASE_SSL_MODE,
  },

  // AlloyDB configuration
  alloydb: {
    authProxy:
      process.env.ALLOYDB_AUTH_PROXY === 'true' ||
      process.env.USE_AUTH_PROXY === 'true',
  },

  // Migration configuration
  migrations: {
    runOnStartup: process.env.RUN_MIGRATIONS_ON_STARTUP === 'true',
  },

  // Feature flags
  features: {
    preview: process.env.PREVIEW_NAME || false,
    alloydb: process.env.ALLOYDB_AUTH_PROXY === 'true',
    feedback: true,
  },

  // Development flags
  isDevelopment: process.env.NODE_ENV === 'development',
  isProduction: process.env.NODE_ENV === 'production',
  isTest: process.env.NODE_ENV === 'test',
};

// Validation functions
const validators = {
  required: (value, name) => {
    if (!value) {
      throw new Error(`Required configuration missing: ${name}`);
    }
    return value;
  },

  positiveInteger: (value, name) => {
    const num = parseInt(value);
    if (isNaN(num) || num <= 0) {
      throw new Error(`Invalid positive integer for ${name}: ${value}`);
    }
    return num;
  },
};

// Configuration validation (optional - only validate what's critical)
function validateConfig() {
  try {
    // Only validate truly critical values
    validators.positiveInteger(config.port, 'PORT');

    // Validate database config if database features are expected
    if (config.database.host && !config.database.name) {
      console.warn('Database host specified but no database name provided');
    }

    return true;
  } catch (error) {
    console.error('Configuration validation failed:', error.message);
    return false;
  }
}

module.exports = {
  ...config,
  validateConfig,
};
