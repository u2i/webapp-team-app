const express = require('express');
const db = require('./db');
const feedbackRouter = require('./feedback');
const { spawn } = require('child_process');
const app = express();
const port = process.env.PORT || 8080;
// Deployment trigger after WIF fix
const boundary = process.env.BOUNDARY || 'nonprod';
const stage = process.env.STAGE || 'unknown';
const version = process.env.VERSION || process.env.K_REVISION || 'local';

// Middleware to parse JSON
app.use(express.json());

// Function to run migrations
async function runMigrationsIfNeeded() {
  if (process.env.RUN_MIGRATIONS_ON_STARTUP === 'true') {
    console.log('Running database migrations on startup...');
    
    // Wait for database to be ready (for sidecar containers)
    if (process.env.DATABASE_HOST === 'localhost') {
      const { Client } = require('pg');
      for (let i = 0; i < 30; i++) {
        try {
          const client = new Client({
            host: process.env.DATABASE_HOST,
            port: process.env.DATABASE_PORT,
            database: process.env.DATABASE_NAME,
            user: process.env.DATABASE_USER,
            password: process.env.DATABASE_PASSWORD
          });
          await client.connect();
          await client.end();
          console.log('Database is ready!');
          break;
        } catch (error) {
          console.log(`Waiting for database... (${i+1}/30)`);
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      }
    }
    
    return new Promise((resolve, reject) => {
      const migrate = spawn('npm', ['run', 'migrate'], {
        stdio: 'inherit',
        env: process.env
      });
      
      migrate.on('close', (code) => {
        if (code === 0) {
          console.log('Migrations completed successfully');
          resolve();
        } else {
          console.error('Migrations failed with code:', code);
          reject(new Error('Migration failed'));
        }
      });
    });
  }
}

// Run migrations if needed, then check database
runMigrationsIfNeeded()
  .then(() => db.isEnabled())
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
    .json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/ready', (req, res) => {
  res
    .status(200)
    .json({ status: 'ready', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from webapp! v11.0 - Now with User Feedback System!',
    boundary: boundary,
    stage: stage,
    version: version,
    features: {
      feedback: true,
      endpoints: [
        'POST /feedback/submit - Submit new feedback',
        'GET /feedback/list - View feedback list',
        'GET /feedback/:id - Get specific feedback',
        'POST /feedback/:id/vote - Vote on feedback',
        'GET /feedback/stats/summary - View statistics'
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
