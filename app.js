const express = require('express');
const db = require('./db');
const feedbackRouter = require('./feedback');
const { attachDatabase, requireDatabase } = require('./middleware');
const config = require('./config');
const { getHealthStatus } = require('./health');

const app = express();

// Validate configuration
if (!config.validateConfig()) {
  console.error('Invalid configuration detected');
  process.exit(1);
}

// Middleware to parse JSON
app.use(express.json());

// Attach database to requests
app.use(attachDatabase);

// Check database connection and migration status
db.isEnabled()
  .then((enabled) => {
    if (enabled) {
      console.log('Database connection available');
      return db.checkMigrations();
    }
    return null;
  })
  .then((migrationStatus) => {
    if (migrationStatus) {
      if (migrationStatus.migrated) {
        console.log(
          `Database migrations up to date. Latest: ${migrationStatus.latest}`
        );
      } else {
        console.warn('Database migrations not run:', migrationStatus.message);
      }
    }
  })
  .catch((err) => console.error('Database/migration error:', err));

// Basic health check (fast, minimal info)
app.get('/health', async (_req, res) => {
  try {
    const health = await getHealthStatus(false);
    res.status(200).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: error.message,
    });
  }
});

// Readiness check (same as health for now)
app.get('/ready', async (_req, res) => {
  try {
    const health = await getHealthStatus(false);
    const ready = {
      ...health,
      status: health.status === 'healthy' ? 'ready' : health.status,
    };
    res.status(health.status === 'healthy' ? 200 : 503).json(ready);
  } catch (error) {
    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: error.message,
    });
  }
});

// Detailed health check (includes database, memory, etc.)
app.get('/health/detailed', async (_req, res) => {
  try {
    const health = await getHealthStatus(true);
    const statusCode =
      health.status === 'healthy'
        ? 200
        : health.status === 'degraded'
          ? 207
          : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: error.message,
    });
  }
});

app.get('/', (_req, res) => {
  res.json({
    message: 'Hello from webapp! v12.0 - With AlloyDB Integration!',
    boundary: config.boundary,
    stage: config.stage,
    version: config.version,
    features: {
      ...config.features,
      endpoints: [
        'POST /feedback/submit - Submit new feedback',
        'GET /feedback/list - View feedback list',
        'GET /feedback/:id - Get specific feedback',
        'POST /feedback/:id/vote - Vote on feedback',
        'GET /feedback/stats/summary - View statistics',
        'GET /db/alloydb-status - AlloyDB connection status (NEW!)',
      ],
    },
    region: 'europe-west1',
    compliance: 'iso27001-soc2-gdpr',
    preview: config.features.preview,
    deployment: 'simplified compliance-cli',
    timestamp: new Date().toISOString(),
  });
});

app.get('/info', (_req, res) => {
  res.json({
    app: 'webapp',
    team: 'webapp-team',
    boundary: config.boundary,
    stage: config.stage,
    version: config.version,
    environment: {
      node: process.version,
      uptime: process.uptime(),
    },
  });
});

// Database status endpoint (legacy - redirects to detailed health)
app.get('/db/status', async (_req, res) => {
  try {
    const health = await getHealthStatus(true);
    if (health.database) {
      const statusCode = health.database.status === 'healthy' ? 200 : 503;
      res.status(statusCode).json({
        database: health.database.connected
          ? { connected: true, message: 'Connected' }
          : {
              connected: false,
              message: health.database.error || health.database.message,
            },
        enabled: health.database.status !== 'disabled',
        migrations: health.database.migrations || {
          migrated: false,
          message: 'Unable to check migrations',
        },
      });
    } else {
      res.status(503).json({
        database: { connected: false, message: 'Database status unavailable' },
        enabled: false,
        migrations: { migrated: false, message: 'Unable to check migrations' },
      });
    }
  } catch (error) {
    res.status(503).json({
      database: { connected: false, message: error.message },
      enabled: false,
      migrations: { migrated: false, message: 'Unable to check migrations' },
    });
  }
});

// Get recent visits
app.get('/db/visits', requireDatabase, async (_req, res) => {
  try {
    const stats = await db.getVisitStats();
    res.json({
      visits: stats.recentVisits,
      count: stats.recentVisits.length,
      totalVisits: stats.totalVisits,
      uniquePaths: stats.uniquePaths,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// AlloyDB Status Endpoint (legacy - use /health/detailed instead)
app.get('/db/alloydb-status', async (_req, res) => {
  try {
    const health = await getHealthStatus(true);
    const status = {
      timestamp: health.timestamp,
      alloydb: {
        enabled: config.alloydb.authProxy,
        authProxy: {
          configured: config.alloydb.authProxy,
          connectionMethod: 'IAM Authentication',
        },
      },
      database: {
        connected: health.database?.connected || false,
        stage: config.stage,
        boundary: config.boundary,
      },
    };

    if (health.database?.alloydb) {
      status.database.details = {
        database: health.database.alloydb.database,
        user: health.database.alloydb.user,
        version: health.database.alloydb.version,
      };
    }

    if (health.database?.pool) {
      status.database.pool = health.database.pool;
    }

    if (health.database?.migrations) {
      status.database.migrations = health.database.migrations;
    }

    if (health.database?.error) {
      status.database.error = health.database.error;
    }

    res.json(status);
  } catch (error) {
    res.status(503).json({
      timestamp: new Date().toISOString(),
      error: error.message,
    });
  }
});

// Get feature flags
app.get('/db/features', requireDatabase, async (_req, res) => {
  try {
    const flags = await db.getFeatureFlags();
    res.json({ features: flags });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Mount feedback router
app.use('/feedback', feedbackRouter);

// Middleware to log visits (after routes are defined)
app.use(async (req, res, next) => {
  // Log visit to database if enabled
  const enabled = await db.isEnabled();
  if (enabled) {
    try {
      const userAgent = req.headers['user-agent'] || 'unknown';
      const ipAddress =
        req.headers['x-forwarded-for'] || req.socket.remoteAddress;
      const startTime = Date.now();

      // Log response time after response is sent
      res.on('finish', async () => {
        const responseTime = Date.now() - startTime;
        try {
          await db.recordVisit(req.path, userAgent, ipAddress, responseTime);
        } catch (error) {
          console.error('Failed to record visit:', error);
        }
      });
    } catch (error) {
      console.error('Error setting up visit logging:', error);
    }
  }
  next();
});

// Only start server if this file is run directly (not in tests)
if (require.main === module) {
  app.listen(config.port, () => {
    // eslint-disable-next-line no-console
    console.log(
      `Server running on port ${config.port} in ${config.stage} stage (${config.boundary} boundary)`
    );
  });
}

module.exports = app;
