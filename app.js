const express = require('express');
const app = express();
const port = process.env.PORT || 8080;
const boundary = process.env.BOUNDARY || 'nonprod';
const stage = process.env.STAGE || 'unknown';
const version = process.env.VERSION || process.env.K_REVISION || 'local';

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from webapp-team! v5 - Multi-stage deployment',
    boundary: boundary,
    stage: stage,
    version: version,
    region: 'europe-west1',
    compliance: 'iso27001-soc2-gdpr',
    timestamp: new Date().toISOString()
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
      uptime: process.uptime()
    }
  });
});

app.listen(port, () => {
  console.log(`Server running on port ${port} in ${stage} stage (${boundary} boundary)`);
});