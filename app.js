const express = require('express');
const app = express();
const port = process.env.PORT || 8080;
const boundary = process.env.BOUNDARY || 'nonprod';

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from webapp-team! v4 - Using boundary terminology',
    boundary: boundary,
    region: 'europe-west1',
    compliance: 'iso27001-soc2-gdpr',
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(`Server running on port ${port} in ${boundary} boundary`);
});