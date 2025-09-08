const express = require('express');
const db = require('./db');
const feedbackRouter = require('./feedback');
const app = express();
const port = process.env.PORT || 8080;
const boundary = process.env.BOUNDARY || 'nonprod';
const stage = process.env.STAGE || 'unknown';
const version = process.env.VERSION || process.env.K_REVISION || 'local';

// Middleware to parse JSON
app.use(express.json());


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
        console.log(`Database migrations up to date. Latest: ${migrationStatus.latest}`);
      } else {
        console.warn('Database migrations not run:', migrationStatus.message);
      }
    }
  })
  .catch((err) => console.error('Database/migration error:', err));

app.get('/health', (req, res) => {
  res
    .status(200)
    .json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      migrationsRefactor: 'test-2025-09-08'
    });
});

app.get('/ready', (req, res) => {
  res
    .status(200)
    .json({ status: 'ready', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from webapp! v12.0 - With AlloyDB Integration!',
    boundary: boundary,
    stage: stage,
    version: version,
    features: {
      feedback: true,
      alloydb: process.env.ALLOYDB_AUTH_PROXY === 'true',
      endpoints: [
        'POST /feedback/submit - Submit new feedback',
        'GET /feedback/list - View feedback list',
        'GET /feedback/:id - Get specific feedback',
        'POST /feedback/:id/vote - Vote on feedback',
        'GET /feedback/stats/summary - View statistics',
        'GET /db/alloydb-status - AlloyDB connection status (NEW!)'
      ]
    },
    region: 'europe-west1',
    compliance: 'iso27001-soc2-gdpr',
    preview: process.env.PREVIEW_NAME || false,
    deployment: 'simplified compliance-cli',
    timestamp: new Date().toISOString(),
  });
});

app.get('/info', (req, res) => {
  res.json({
    app: 'webapp',
    team: 'webapp-team',
    boundary: boundary,
    stage: stage,
    version: version,
    environment: {
      node: process.version,
      uptime: process.uptime(),
    },
  });
});

// Database status endpoint
app.get('/db/status', async (req, res) => {
  try {
    const enabled = await db.isEnabled();
    if (!enabled) {
      return res.status(503).json({
        database: { connected: false, message: 'Database not configured' },
        enabled: false,
        migrations: { migrated: false, message: 'Database not enabled' }
      });
    }
    
    const pool = await db.getPool();
    await pool.query('SELECT 1');
    
    // Check migration status
    const migrationStatus = await db.checkMigrations();
    
    res.json({
      database: { connected: true, message: 'Connected' },
      enabled: true,
      migrations: migrationStatus
    });
  } catch (error) {
    res.status(503).json({
      database: { connected: false, message: error.message },
      enabled: false,
      migrations: { migrated: false, message: 'Unable to check migrations' }
    });
  }
});

// Get recent visits
app.get('/db/visits', async (req, res) => {
  const enabled = await db.isEnabled();
  if (!enabled) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  
  try {
    const stats = await db.getVisitStats();
    res.json({ 
      visits: stats.recentVisits, 
      count: stats.recentVisits.length,
      totalVisits: stats.totalVisits,
      uniquePaths: stats.uniquePaths
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// AlloyDB Status Endpoint - shows connection details
app.get('/db/alloydb-status', async (req, res) => {
  const enabled = await db.isEnabled();
  
  const status = {
    timestamp: new Date().toISOString(),
    alloydb: {
      enabled: process.env.ALLOYDB_AUTH_PROXY === 'true',
      authProxy: {
        configured: process.env.ALLOYDB_AUTH_PROXY === 'true',
        connectionMethod: 'IAM Authentication'
      }
    },
    database: {
      connected: enabled,
      stage: process.env.STAGE || 'unknown',
      boundary: process.env.BOUNDARY || 'unknown'
    }
  };
  
  if (enabled) {
    try {
      // Test the connection with a simple query
      const result = await db.query('SELECT current_database(), current_user, version()');
      status.database.details = {
        database: result.rows[0].current_database,
        user: result.rows[0].current_user,
        version: result.rows[0].version.split(' ')[0] + ' ' + result.rows[0].version.split(' ')[1]
      };
      
      // Get connection pool stats
      const pool = await db.getPool();
      status.database.pool = {
        totalCount: pool.totalCount,
        idleCount: pool.idleCount,
        waitingCount: pool.waitingCount
      };
      
      // Check migrations status
      const migrations = await db.checkMigrations();
      status.database.migrations = migrations;
      
    } catch (error) {
      status.database.error = error.message;
    }
  }
  
  res.json(status);
});

// Get feature flags
app.get('/db/features', async (req, res) => {
  const enabled = await db.isEnabled();
  if (!enabled) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  
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
      const ipAddress = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
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
  app.listen(port, () => {
    // eslint-disable-next-line no-console
    console.log(
      `Server running on port ${port} in ${stage} stage (${boundary} boundary)`
    );
  });
}

module.exports = app;
