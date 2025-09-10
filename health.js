const db = require('./db');
const config = require('./config');

/**
 * Comprehensive health check that combines all health information
 * @param {boolean} includeDetails - Whether to include detailed information
 * @returns {Object} Health status object
 */
async function getHealthStatus(includeDetails = false) {
  const timestamp = new Date().toISOString();
  const baseHealth = {
    status: 'healthy',
    timestamp,
  };

  if (!includeDetails) {
    return baseHealth;
  }

  const health = {
    ...baseHealth,
    application: {
      version: config.version,
      stage: config.stage,
      boundary: config.boundary,
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      node: process.version,
    },
  };

  // Database health check
  try {
    const dbEnabled = await db.isEnabled();
    if (dbEnabled) {
      const pool = await db.getPool();

      // Test database connection
      try {
        await pool.query('SELECT 1');
        const migrationStatus = await db.checkMigrations();

        health.database = {
          status: 'healthy',
          connected: true,
          pool: {
            totalCount: pool.totalCount,
            idleCount: pool.idleCount,
            waitingCount: pool.waitingCount,
          },
          migrations: migrationStatus,
        };

        // AlloyDB specific info
        if (config.alloydb.authProxy) {
          try {
            const result = await db.query(
              'SELECT current_database(), current_user, version()'
            );
            health.database.alloydb = {
              enabled: true,
              database: result.rows[0].current_database,
              user: result.rows[0].current_user,
              version:
                result.rows[0].version.split(' ')[0] +
                ' ' +
                result.rows[0].version.split(' ')[1],
            };
          } catch (error) {
            health.database.alloydb = {
              enabled: true,
              error: error.message,
            };
          }
        }
      } catch (error) {
        health.database = {
          status: 'unhealthy',
          connected: false,
          error: error.message,
        };
        health.status = 'degraded';
      }
    } else {
      health.database = {
        status: 'disabled',
        connected: false,
        message: 'Database not configured',
      };
    }
  } catch (error) {
    health.database = {
      status: 'error',
      error: error.message,
    };
    health.status = 'degraded';
  }

  return health;
}

module.exports = {
  getHealthStatus,
};
