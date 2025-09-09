/**
 * Application constants and configuration
 */

module.exports = {
  // Database configuration
  DB_RETRY_ATTEMPTS: 30,
  DB_RETRY_DELAY_MS: 2000,
  MIGRATION_TIMEOUT_MS: 30000,
  ALLOYDB_STARTUP_DELAY_MS: 20000,
  
  // Database connection pool
  DB_POOL_MAX_CONNECTIONS: 20,
  DB_POOL_IDLE_TIMEOUT_MS: 30000,
  DB_POOL_CONNECTION_TIMEOUT_MS: 2000,
  
  // Server configuration
  DEFAULT_PORT: 8080,
  
  // Pagination defaults
  DEFAULT_PAGE_LIMIT: 20,
  DEFAULT_PAGE_OFFSET: 0,
  
  // Valid feedback types
  VALID_FEEDBACK_TYPES: ['bug', 'feature', 'improvement', 'question', 'other'],
  
  // Health check configuration
  HEALTHCHECK_INTERVAL_SEC: 30,
  HEALTHCHECK_TIMEOUT_SEC: 3,
  HEALTHCHECK_START_PERIOD_SEC: 5,
  HEALTHCHECK_RETRIES: 3
};