const db = require('./db');

// Middleware to check if database is available
const requireDatabase = async (req, res, next) => {
  const enabled = await db.isEnabled();
  if (!enabled) {
    return res.status(503).json({ error: 'Database not configured' });
  }
  next();
};

// Middleware to add database connection to request object
const attachDatabase = async (req, res, next) => {
  const enabled = await db.isEnabled();
  if (enabled) {
    req.db = db;
  }
  next();
};

module.exports = {
  requireDatabase,
  attachDatabase,
};
