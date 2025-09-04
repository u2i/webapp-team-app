const express = require('express');
const db = require('./db');
const app = express();
const port = process.env.PORT || 8080;
// Deployment trigger after WIF fix
const boundary = process.env.BOUNDARY || 'nonprod';
const stage = process.env.STAGE || 'unknown';
const version = process.env.VERSION || process.env.K_REVISION || 'local';

// Middleware to parse JSON
app.use(express.json());

// Initialize database on startup
db.isEnabled()
  .then((enabled) => {
    if (enabled) {
      return db.initializeSchema();
    }
  })
  .then(() => console.log('Database initialized'))
  .catch((err) => console.error('Database initialization failed:', err));

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
    message: 'Hello from webapp! v10.0 - Testing framework validation',
    boundary: boundary,
    stage: stage,
    version: version,
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
      });
    }
    
    const pool = await db.getPool();
    await pool.query('SELECT 1');
    res.json({
      database: { connected: true, message: 'Connected' },
      enabled: true,
    });
  } catch (error) {
    res.status(503).json({
      database: { connected: false, message: error.message },
      enabled: false,
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
