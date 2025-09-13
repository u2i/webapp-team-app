// Mock dependencies before any imports
jest.mock('pg');
jest.mock('@google-cloud/secret-manager');
jest.mock('./constants', () => ({
  DB_POOL_MAX_CONNECTIONS: 10,
  DB_POOL_IDLE_TIMEOUT_MS: 30000,
  DB_POOL_CONNECTION_TIMEOUT_MS: 10000,
  ALLOYDB_STARTUP_DELAY_MS: 1, // Short delay for tests
}));

const { Pool } = require('pg');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');

describe('Database Module Tests', () => {
  let db;
  let mockPool;
  let mockSecretClient;
  let originalEnv;

  beforeEach(() => {
    // Save original environment
    originalEnv = { ...process.env };
    
    // Clear module cache
    jest.resetModules();
    jest.clearAllMocks();

    // Mock console methods
    jest.spyOn(console, 'log').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});

    // Create mock pool
    mockPool = {
      query: jest.fn(),
      on: jest.fn(),
      end: jest.fn(),
    };

    // Mock Pool constructor
    Pool.mockImplementation(() => mockPool);

    // Create mock secret client
    mockSecretClient = {
      accessSecretVersion: jest.fn(),
    };

    // Mock SecretManagerServiceClient
    SecretManagerServiceClient.mockImplementation(() => mockSecretClient);

    // Set default environment variables
    process.env.PROJECT_ID = 'test-project';
    process.env.BOUNDARY = 'nonprod';
    process.env.STAGE = 'test';
  });

  afterEach(async () => {
    // Clean up any database connections
    if (db && db.cleanup) {
      await db.cleanup();
    }
    
    // Restore console methods
    console.log.mockRestore();
    console.error.mockRestore();

    // Restore original environment
    process.env = originalEnv;
  });

  describe('Database Configuration', () => {
    it('should use DATABASE_URL from environment when provided', async () => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      const isEnabled = await db.isEnabled();

      expect(isEnabled).toBe(true);
      expect(Pool).toHaveBeenCalledWith(
        expect.objectContaining({
          connectionString: 'postgresql://user:pass@host:5432/dbname',
        })
      );
    });

    it('should use individual database parameters when provided', async () => {
      process.env.DATABASE_HOST = 'test-host';
      process.env.DATABASE_PORT = '5433';
      process.env.DATABASE_NAME = 'testdb';
      process.env.DATABASE_USER = 'testuser';
      process.env.DATABASE_PASSWORD = 'testpass';
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      const isEnabled = await db.isEnabled();

      expect(isEnabled).toBe(true);
      expect(Pool).toHaveBeenCalledWith(
        expect.objectContaining({
          host: 'test-host',
          port: '5433',
          database: 'testdb',
          user: 'testuser',
          password: 'testpass',
        })
      );
    });

    it('should configure for AlloyDB Auth Proxy with IAM authentication', async () => {
      process.env.ALLOYDB_AUTH_PROXY = 'true';
      process.env.PROJECT_ID = 'test-project';
      process.env.STAGE = 'dev';
      mockPool.query.mockResolvedValue({ rows: [] });

      // Mock the Client for database creation check
      const mockClient = {
        connect: jest.fn().mockResolvedValue(),
        query: jest.fn().mockResolvedValue({ rows: [{ exists: true }] }),
        end: jest.fn().mockResolvedValue(),
      };
      const ClientMock = jest.fn(() => mockClient);
      require('pg').Client = ClientMock;

      db = require('./db');
      const isEnabled = await db.isEnabled();

      expect(isEnabled).toBe(true);
      expect(Pool).toHaveBeenCalledWith(
        expect.objectContaining({
          connectionString: 'postgresql://webapp-k8s@test-project.iam:@localhost:5432/webapp_dev',
          ssl: false, // SSL disabled for Auth Proxy
        })
      );
    }, 15000); // Increase timeout

    it('should handle SSL configuration correctly', async () => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
      process.env.DATABASE_SSL_MODE = 'require';
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      await db.isEnabled();

      expect(Pool).toHaveBeenCalledWith(
        expect.objectContaining({
          ssl: { rejectUnauthorized: false },
        })
      );
    });

    it('should disable SSL when DATABASE_SSL_MODE is disable', async () => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
      process.env.DATABASE_SSL_MODE = 'disable';
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      await db.isEnabled();

      expect(Pool).toHaveBeenCalledWith(
        expect.objectContaining({
          ssl: false,
        })
      );
    });
  });

  describe('Secret Manager Integration', () => {
    it('should fetch database URL from Secret Manager', async () => {
      const mockSecretData = 'postgresql://secret:pass@host:5432/db';
      mockSecretClient.accessSecretVersion.mockResolvedValue([
        {
          payload: {
            data: Buffer.from(mockSecretData),
          },
        },
      ]);
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      const isEnabled = await db.isEnabled();

      expect(isEnabled).toBe(true);
      expect(mockSecretClient.accessSecretVersion).toHaveBeenCalledWith({
        name: 'projects/test-project/secrets/webapp-nonprod-alloydb-connection/versions/latest',
      });
      expect(Pool).toHaveBeenCalledWith(
        expect.objectContaining({
          connectionString: mockSecretData,
        })
      );
    });

    it('should handle Secret Manager errors gracefully', async () => {
      mockSecretClient.accessSecretVersion.mockRejectedValue(
        new Error('Permission denied')
      );

      db = require('./db');
      const isEnabled = await db.isEnabled();

      expect(isEnabled).toBe(false);
      expect(console.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to fetch database credentials'),
        'Permission denied'
      );
    });

    it('should use correct secret name for production boundary', async () => {
      process.env.BOUNDARY = 'prod';
      process.env.PROJECT_ID = 'prod-project';

      const mockSecretData = 'postgresql://prod:pass@host:5432/db';
      mockSecretClient.accessSecretVersion.mockResolvedValue([
        {
          payload: {
            data: Buffer.from(mockSecretData),
          },
        },
      ]);
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      await db.isEnabled();

      expect(mockSecretClient.accessSecretVersion).toHaveBeenCalledWith({
        name: 'projects/prod-project/secrets/webapp-prod-alloydb-connection/versions/latest',
      });
    });
  });

  describe('Database Operations', () => {
    beforeEach(() => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
      mockPool.query.mockResolvedValue({ rows: [] });
    });

    it('should execute queries successfully', async () => {
      const mockResult = { rows: [{ id: 1, name: 'test' }] };
      mockPool.query.mockResolvedValue(mockResult);

      db = require('./db');
      const result = await db.query('SELECT * FROM users WHERE id = $1', [1]);

      expect(result).toEqual(mockResult);
      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT * FROM users WHERE id = $1',
        [1]
      );
    });

    it('should throw error when database is not configured', async () => {
      delete process.env.DATABASE_URL;
      delete process.env.DATABASE_HOST;

      db = require('./db');

      await expect(db.query('SELECT 1')).rejects.toThrow(
        'Database is not configured'
      );
    });

    it('should handle query errors', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // For initialization
        .mockRejectedValueOnce(new Error('Connection timeout'));

      db = require('./db');
      await db.isEnabled(); // Initialize

      await expect(db.query('SELECT 1')).rejects.toThrow('Connection timeout');
    });
  });

  describe('Migration Checks', () => {
    beforeEach(() => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
    });

    it('should detect when migrations table exists and has migrations', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // For initialization
        .mockResolvedValueOnce({ rows: [{ exists: true }] }) // Table exists check
        .mockResolvedValueOnce({
          // Latest migration
          rows: [
            {
              name: '001_initial_schema',
              run_on: new Date('2024-01-01'),
            },
          ],
        });

      db = require('./db');
      const migrationStatus = await db.checkMigrations();

      expect(migrationStatus).toEqual({
        migrated: true,
        latest: '001_initial_schema',
        runOn: new Date('2024-01-01'),
      });
    });

    it('should detect when migrations table does not exist', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // For initialization
        .mockResolvedValueOnce({ rows: [{ exists: false }] }); // Table doesn't exist

      db = require('./db');
      const migrationStatus = await db.checkMigrations();

      expect(migrationStatus).toEqual({
        migrated: false,
        message: 'Migrations table does not exist',
      });
    });

    it('should detect when no migrations have been run', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // For initialization
        .mockResolvedValueOnce({ rows: [{ exists: true }] }) // Table exists
        .mockResolvedValueOnce({ rows: [] }); // No migrations

      db = require('./db');
      const migrationStatus = await db.checkMigrations();

      expect(migrationStatus).toEqual({
        migrated: false,
        message: 'No migrations have been run',
      });
    });
  });

  describe('Visit Recording', () => {
    beforeEach(() => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
      process.env.STAGE = 'test';
    });

    it('should record visits successfully', async () => {
      const mockVisit = {
        id: 1,
        endpoint: '/health',
        user_agent: 'test-agent',
        ip_address: '127.0.0.1',
        response_time: 50,
        stage: 'test',
        timestamp: new Date(),
      };

      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // For initialization
        .mockResolvedValueOnce({ rows: [mockVisit] }) // INSERT result
        .mockResolvedValueOnce({ rows: [{ count: '100' }] }); // COUNT result

      db = require('./db');
      const result = await db.recordVisit(
        '/health',
        'test-agent',
        '127.0.0.1',
        50
      );

      expect(result).toEqual({
        visit: mockVisit,
        totalVisits: 100,
      });
    });

    it('should return empty result when database is disabled', async () => {
      delete process.env.DATABASE_URL;
      delete process.env.DATABASE_HOST;

      db = require('./db');
      const result = await db.recordVisit('/health');

      expect(result).toEqual({
        visit: null,
        totalVisits: 0,
      });
    });
  });

  describe('Visit Statistics', () => {
    beforeEach(() => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
    });

    it('should return visit statistics', async () => {
      const mockRecentVisits = [
        { id: 1, endpoint: '/health', timestamp: new Date() },
        { id: 2, endpoint: '/info', timestamp: new Date() },
      ];

      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // For initialization
        .mockResolvedValueOnce({ rows: [{ count: '500' }] }) // Total visits
        .mockResolvedValueOnce({ rows: [{ count: '10' }] }) // Unique paths
        .mockResolvedValueOnce({ rows: mockRecentVisits }); // Recent visits

      db = require('./db');
      const stats = await db.getVisitStats();

      expect(stats).toEqual({
        totalVisits: 500,
        uniquePaths: 10,
        recentVisits: mockRecentVisits,
      });
    });

    it('should return empty stats when database is disabled', async () => {
      delete process.env.DATABASE_URL;
      delete process.env.DATABASE_HOST;

      db = require('./db');
      const stats = await db.getVisitStats();

      expect(stats).toEqual({
        totalVisits: 0,
        uniquePaths: 0,
        recentVisits: [],
      });
    });
  });

  describe('Feature Flags', () => {
    beforeEach(() => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
    });

    it('should retrieve feature flags from database', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // For initialization
        .mockResolvedValueOnce({
          rows: [
            { name: 'darkMode', enabled: true },
            { name: 'betaFeatures', enabled: false },
            { name: 'debugMode', enabled: true },
          ],
        });

      db = require('./db');
      const flags = await db.getFeatureFlags();

      expect(flags).toEqual({
        darkMode: true,
        betaFeatures: false,
        debugMode: true,
      });
    });

    it('should return default flags when database is disabled', async () => {
      delete process.env.DATABASE_URL;
      delete process.env.DATABASE_HOST;

      db = require('./db');
      const flags = await db.getFeatureFlags();

      expect(flags).toEqual({
        darkMode: false,
        betaFeatures: false,
        debugMode: false,
      });
    });

    it('should return default flags on error', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // For initialization
        .mockRejectedValueOnce(new Error('Query failed'));

      db = require('./db');
      const flags = await db.getFeatureFlags();

      expect(flags).toEqual({
        darkMode: false,
        betaFeatures: false,
        debugMode: false,
      });
    });
  });

  describe('Connection Pool Management', () => {
    it('should initialize pool only once with multiple calls', async () => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');

      // Call isEnabled multiple times
      await Promise.all([db.isEnabled(), db.isEnabled(), db.isEnabled()]);

      // Pool should only be created once
      expect(Pool).toHaveBeenCalledTimes(1);
    });

    it('should clean up connections properly', async () => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      await db.isEnabled();
      await db.cleanup();

      expect(mockPool.end).toHaveBeenCalled();
    });

    it('should handle pool errors', async () => {
      process.env.DATABASE_URL = 'postgresql://user:pass@host:5432/dbname';
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      await db.isEnabled();

      // Get the error handler
      const errorHandler = mockPool.on.mock.calls.find(
        (call) => call[0] === 'error'
      )[1];

      // Should not throw when pool emits error
      expect(() => errorHandler(new Error('Pool error'))).not.toThrow();
      expect(console.error).toHaveBeenCalledWith(
        'Unexpected database pool error:',
        expect.any(Error)
      );
    });
  });

  describe('Database Creation for AlloyDB', () => {
    it('should create database if it does not exist', async () => {
      process.env.ALLOYDB_AUTH_PROXY = 'true';
      process.env.PROJECT_ID = 'test-project';
      process.env.STAGE = 'dev';

      const mockClient = {
        connect: jest.fn().mockResolvedValue(),
        query: jest
          .fn()
          .mockResolvedValueOnce({ rows: [] }) // Database doesn't exist
          .mockResolvedValueOnce({}), // CREATE DATABASE
        end: jest.fn().mockResolvedValue(),
      };
      const ClientMock = jest.fn(() => mockClient);
      require('pg').Client = ClientMock;

      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      await db.isEnabled();

      expect(mockClient.query).toHaveBeenCalledWith(
        'SELECT 1 FROM pg_database WHERE datname = $1',
        ['webapp_dev']
      );
      expect(mockClient.query).toHaveBeenCalledWith(
        'CREATE DATABASE "webapp_dev"'
      );
    }, 15000); // Increase timeout

    it('should not create database if it already exists', async () => {
      process.env.ALLOYDB_AUTH_PROXY = 'true';
      process.env.PROJECT_ID = 'test-project';
      process.env.STAGE = 'dev';

      const mockClient = {
        connect: jest.fn().mockResolvedValue(),
        query: jest.fn().mockResolvedValueOnce({ rows: [{ exists: true }] }), // Database exists
        end: jest.fn().mockResolvedValue(),
      };
      const ClientMock = jest.fn(() => mockClient);
      require('pg').Client = ClientMock;

      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      await db.isEnabled();

      expect(mockClient.query).toHaveBeenCalledTimes(1); // Only SELECT, no CREATE
      expect(mockClient.query).not.toHaveBeenCalledWith(
        expect.stringContaining('CREATE DATABASE')
      );
    }, 15000); // Increase timeout
  });

  describe('Environment Variable Handling', () => {
    it('should handle missing PROJECT_ID gracefully', async () => {
      delete process.env.PROJECT_ID;
      delete process.env.GCP_PROJECT;
      delete process.env.DATABASE_URL;
      delete process.env.DATABASE_HOST;

      db = require('./db');
      const isEnabled = await db.isEnabled();

      expect(isEnabled).toBe(false);
      expect(console.log).toHaveBeenCalledWith(
        'No PROJECT_ID found, database features disabled'
      );
    });

    it('should use GCP_PROJECT as fallback for PROJECT_ID', async () => {
      delete process.env.PROJECT_ID;
      process.env.GCP_PROJECT = 'gcp-project';

      const mockSecretData = 'postgresql://secret:pass@host:5432/db';
      mockSecretClient.accessSecretVersion.mockResolvedValue([
        {
          payload: {
            data: Buffer.from(mockSecretData),
          },
        },
      ]);
      mockPool.query.mockResolvedValue({ rows: [] });

      db = require('./db');
      await db.isEnabled();

      expect(mockSecretClient.accessSecretVersion).toHaveBeenCalledWith({
        name: 'projects/gcp-project/secrets/webapp-nonprod-alloydb-connection/versions/latest',
      });
    });
  });
});