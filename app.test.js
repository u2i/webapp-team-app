const request = require('supertest');

// Mock the database module
jest.mock('./db');

// Mock the express app for testing
describe('WebApp API Tests', () => {
  let app;

  beforeEach(() => {
    // Clear module cache to get fresh app instance
    jest.resetModules();
    
    // Clear mock calls
    jest.clearAllMocks();

    // Set test environment variables
    process.env.PORT = '3000';
    process.env.BOUNDARY = 'test';
    process.env.STAGE = 'test-stage';
    process.env.VERSION = 'v1.0.0-test';

    // Import app
    app = require('./app');
  });

  describe('GET /health', () => {
    it('should return healthy status', async () => {
      const server = app.listen(0);
      const response = await request(server)
        .get('/health')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      server.close();
    });

    it('should return valid timestamp', async () => {
      const server = app.listen(0);
      const response = await request(server).get('/health');
      const timestamp = new Date(response.body.timestamp);

      expect(timestamp).toBeInstanceOf(Date);
      expect(timestamp.getTime()).not.toBeNaN();
      server.close();
    });
  });

  describe('GET /ready', () => {
    it('should return ready status', async () => {
      const server = app.listen(0);
      const response = await request(server)
        .get('/ready')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ready');
      expect(response.body).toHaveProperty('timestamp');
      server.close();
    });
  });

  describe('GET /', () => {
    it('should return application information', async () => {
      const server = app.listen(0);
      const response = await request(server)
        .get('/')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toContain('v10.0'); // Verify version update
      expect(response.body).toHaveProperty('boundary', 'test');
      expect(response.body).toHaveProperty('stage', 'test-stage');
      expect(response.body).toHaveProperty('version', 'v1.0.0-test');
      expect(response.body).toHaveProperty('region', 'europe-west1');
      expect(response.body).toHaveProperty('compliance', 'iso27001-soc2-gdpr');
      server.close();
    });

    it('should include preview information when set', async () => {
      process.env.PREVIEW_NAME = 'pr-123';
      jest.resetModules();
      const appWithPreview = require('./app');
      const server = appWithPreview.listen(0);

      const response = await request(server).get('/');
      expect(response.body).toHaveProperty('preview', 'pr-123');

      delete process.env.PREVIEW_NAME;
      server.close();
    });
  });

  describe('GET /info', () => {
    it('should return detailed application info', async () => {
      const server = app.listen(0);
      const response = await request(server)
        .get('/info')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('app', 'webapp');
      expect(response.body).toHaveProperty('team', 'webapp-team');
      expect(response.body).toHaveProperty('boundary', 'test');
      expect(response.body).toHaveProperty('stage', 'test-stage');
      expect(response.body).toHaveProperty('version', 'v1.0.0-test');
      expect(response.body).toHaveProperty('environment');
      expect(response.body.environment).toHaveProperty('node');
      expect(response.body.environment).toHaveProperty('uptime');
      server.close();
    });

    it('should return valid uptime', async () => {
      const server = app.listen(0);
      const response = await request(server).get('/info');

      expect(typeof response.body.environment.uptime).toBe('number');
      expect(response.body.environment.uptime).toBeGreaterThanOrEqual(0);
      server.close();
    });
  });

  describe('Environment Variables', () => {
    it('should use default values when env vars are not set', () => {
      delete process.env.BOUNDARY;
      delete process.env.STAGE;
      delete process.env.VERSION;
      jest.resetModules();

      const appWithDefaults = require('./app');
      // The module sets defaults on load
      expect(appWithDefaults).toBeDefined();
    });
  });

  describe('404 Handling', () => {
    it('should return 404 for unknown routes', async () => {
      const server = app.listen(0);
      await request(server).get('/unknown-route').expect(404);
      server.close();
    });
  });
});

// Compliance Tests
describe('Compliance Requirements', () => {
  let app;

  beforeEach(() => {
    jest.resetModules();
    process.env.BOUNDARY = 'test';
    process.env.STAGE = 'test-stage';
    app = require('./app');
  });

  it('should enforce GDPR data residency in EU', async () => {
    const server = app.listen(0);
    const response = await request(server).get('/');

    expect(response.body.region).toBe('europe-west1');
    server.close();
  });

  it('should include compliance standards in response', async () => {
    const server = app.listen(0);
    const response = await request(server).get('/');

    expect(response.body.compliance).toContain('iso27001');
    expect(response.body.compliance).toContain('soc2');
    expect(response.body.compliance).toContain('gdpr');
    server.close();
  });
});

// Performance Tests
describe('Performance Requirements', () => {
  let app;

  beforeEach(() => {
    jest.resetModules();
    process.env.BOUNDARY = 'test';
    process.env.STAGE = 'test-stage';
    app = require('./app');
  });

  it('health check should respond quickly', async () => {
    const server = app.listen(0);
    const startTime = Date.now();
    await request(server).get('/health');
    const responseTime = Date.now() - startTime;

    expect(responseTime).toBeLessThan(100); // Should respond in less than 100ms
    server.close();
  });

  it('ready check should respond quickly', async () => {
    const server = app.listen(0);
    const startTime = Date.now();
    await request(server).get('/ready');
    const responseTime = Date.now() - startTime;

    expect(responseTime).toBeLessThan(100); // Should respond in less than 100ms
    server.close();
  });
});
