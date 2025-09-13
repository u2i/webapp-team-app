const {
  testPool,
  setupTestDatabase,
  resetTestDatabase,
  teardownTestDatabase,
  seedDatabase,
  getTestDatabaseUrl,
} = require('../helpers/database');

describe('Database Integration Tests', () => {
  // Setup test database before all tests
  beforeAll(async () => {
    // Set environment for test database
    process.env.DATABASE_URL = getTestDatabaseUrl();
    process.env.STAGE = 'test';
    process.env.BOUNDARY = 'test';
    process.env.DATABASE_SSL_MODE = 'disable'; // Disable SSL for local test database
    
    await setupTestDatabase();
  }, 30000); // 30 second timeout for setup

  // Clean database after each test
  afterEach(async () => {
    await resetTestDatabase();
  });

  // Tear down after all tests
  afterAll(async () => {
    await teardownTestDatabase();
  });

  describe('Database Connection', () => {
    it('should connect to the test database', async () => {
      const result = await testPool.query('SELECT 1 as value');
      expect(result.rows[0].value).toBe(1);
    });

    it('should have the correct database name', async () => {
      const result = await testPool.query('SELECT current_database()');
      expect(result.rows[0].current_database).toBe('webapp_test');
    });
  });

  describe('Migrations', () => {
    it('should have migrations table', async () => {
      const result = await testPool.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_schema = 'public' 
          AND table_name = 'pgmigrations'
        )
      `);
      expect(result.rows[0].exists).toBe(true);
    });

    it('should have visits table with correct schema', async () => {
      const result = await testPool.query(`
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_name = 'visits'
        ORDER BY ordinal_position
      `);

      const columns = result.rows.map(row => row.column_name);
      expect(columns).toContain('id');
      expect(columns).toContain('endpoint');
      expect(columns).toContain('user_agent');
      expect(columns).toContain('ip_address');
      expect(columns).toContain('response_time');
      expect(columns).toContain('stage');
      expect(columns).toContain('timestamp');
    });

    it('should have user_feedback table with correct schema', async () => {
      const result = await testPool.query(`
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = 'user_feedback'
        ORDER BY ordinal_position
      `);

      const columns = result.rows.map(row => row.column_name);
      expect(columns).toContain('id');
      expect(columns).toContain('feedback_type');
      expect(columns).toContain('message');
      expect(columns).toContain('user_id');
      expect(columns).toContain('status');
      expect(columns).toContain('metadata');
      expect(columns).toContain('created_at');
    });

    it('should have feature_flags table', async () => {
      const result = await testPool.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'feature_flags'
      `);

      const columns = result.rows.map(row => row.column_name);
      expect(columns).toContain('id');
      expect(columns).toContain('name');
      expect(columns).toContain('enabled');
      expect(columns).toContain('description');
    });
  });

  describe('Visit Recording', () => {
    it('should record a visit successfully', async () => {
      const visitData = {
        endpoint: '/health',
        user_agent: 'test-agent',
        ip_address: '127.0.0.1',
        response_time: 50,
        stage: 'test',
      };

      const result = await testPool.query(
        `INSERT INTO visits (endpoint, user_agent, ip_address, response_time, stage)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [visitData.endpoint, visitData.user_agent, visitData.ip_address, visitData.response_time, visitData.stage]
      );

      expect(result.rows[0]).toMatchObject(visitData);
      expect(result.rows[0].id).toBeDefined();
      expect(result.rows[0].timestamp).toBeDefined();
    });

    it('should calculate visit statistics correctly', async () => {
      // Seed test data
      await seedDatabase({
        visits: [
          { endpoint: '/health', user_agent: 'bot', ip_address: '1.1.1.1', response_time: 10 },
          { endpoint: '/health', user_agent: 'chrome', ip_address: '2.2.2.2', response_time: 20 },
          { endpoint: '/info', user_agent: 'firefox', ip_address: '3.3.3.3', response_time: 30 },
          { endpoint: '/api/data', user_agent: 'curl', ip_address: '4.4.4.4', response_time: 40 },
        ],
      });

      // Get total visits
      const totalResult = await testPool.query('SELECT COUNT(*) FROM visits');
      expect(parseInt(totalResult.rows[0].count)).toBe(4);

      // Get unique endpoints
      const uniqueResult = await testPool.query('SELECT COUNT(DISTINCT endpoint) FROM visits');
      expect(parseInt(uniqueResult.rows[0].count)).toBe(3);

      // Get average response time
      const avgResult = await testPool.query('SELECT AVG(response_time) FROM visits');
      expect(parseFloat(avgResult.rows[0].avg)).toBe(25);

      // Get visits by endpoint
      const byEndpointResult = await testPool.query(`
        SELECT endpoint, COUNT(*) as count
        FROM visits
        GROUP BY endpoint
        ORDER BY count DESC
      `);
      expect(byEndpointResult.rows[0]).toMatchObject({ endpoint: '/health', count: '2' });
    });
  });

  describe('Feature Flags', () => {
    it('should insert and retrieve feature flags', async () => {
      await seedDatabase({
        featureFlags: [
          { name: 'darkMode', enabled: true, description: 'Enable dark mode UI' },
          { name: 'betaFeatures', enabled: false, description: 'Enable beta features' },
          { name: 'debugMode', enabled: true, description: 'Enable debug logging' },
        ],
      });

      const result = await testPool.query('SELECT name, enabled FROM feature_flags ORDER BY name');
      expect(result.rows).toEqual([
        { name: 'betaFeatures', enabled: false },
        { name: 'darkMode', enabled: true },
        { name: 'debugMode', enabled: true },
      ]);
    });

    it('should update feature flags on conflict', async () => {
      // Insert initial flag
      await testPool.query(
        `INSERT INTO feature_flags (name, enabled, description) VALUES ($1, $2, $3)`,
        ['testFlag', false, 'Test flag']
      );

      // Try to insert again with different value (should update)
      await testPool.query(
        `INSERT INTO feature_flags (name, enabled, description) 
         VALUES ($1, $2, $3)
         ON CONFLICT (name) DO UPDATE SET enabled = $2`,
        ['testFlag', true, 'Updated test flag']
      );

      const result = await testPool.query('SELECT * FROM feature_flags WHERE name = $1', ['testFlag']);
      expect(result.rows[0].enabled).toBe(true);
    });
  });

  describe('Feedback Management', () => {
    it('should create and retrieve feedback', async () => {
      const feedbackData = {
        feedback_type: 'bug',
        subject: 'Test Bug Report',
        message: 'Test bug report details',
        user_id: 'test-user-123',
        metadata: { browser: 'chrome', version: '120' },
      };

      const insertResult = await testPool.query(
        `INSERT INTO user_feedback (feedback_type, subject, message, user_id, status, metadata)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [feedbackData.feedback_type, feedbackData.subject, feedbackData.message, feedbackData.user_id, 'pending', JSON.stringify(feedbackData.metadata)]
      );

      const feedback = insertResult.rows[0];
      expect(feedback.feedback_type).toBe('bug');
      expect(feedback.subject).toBe('Test Bug Report');
      expect(feedback.message).toBe('Test bug report details');
      expect(feedback.status).toBe('pending');
      expect(feedback.metadata).toEqual(feedbackData.metadata);
    });

    it('should handle feedback responses', async () => {
      // Create feedback
      const feedbackResult = await testPool.query(
        `INSERT INTO user_feedback (feedback_type, subject, message, user_id, status)
         VALUES ('feature', 'Feature Request', 'Test feature request', 'test-user', 'pending')
         RETURNING id`
      );
      const feedbackId = feedbackResult.rows[0].id;

      // Add response
      await testPool.query(
        `INSERT INTO feedback_responses (feedback_id, responder_id, response, is_public)
         VALUES ($1, $2, $3, $4)`,
        [feedbackId, 'support-team', 'We will consider this feature', true]
      );

      // Get feedback with responses
      const result = await testPool.query(`
        SELECT f.*, 
               COALESCE(json_agg(
                 json_build_object(
                   'id', fr.id,
                   'responder_id', fr.responder_id,
                   'response', fr.response,
                   'is_public', fr.is_public
                 ) ORDER BY fr.created_at
               ) FILTER (WHERE fr.id IS NOT NULL), '[]') as responses
        FROM user_feedback f
        LEFT JOIN feedback_responses fr ON f.id = fr.feedback_id
        WHERE f.id = $1
        GROUP BY f.id
      `, [feedbackId]);

      const feedback = result.rows[0];
      expect(feedback.responses).toHaveLength(1);
      expect(feedback.responses[0].response).toBe('We will consider this feature');
    });

    it('should track feedback votes', async () => {
      // Create feedback
      const feedbackResult = await testPool.query(
        `INSERT INTO user_feedback (feedback_type, subject, message, user_id, status)
         VALUES ('bug', 'Bug Report', 'Test bug', 'test-user', 'pending')
         RETURNING id`
      );
      const feedbackId = feedbackResult.rows[0].id;

      // Add votes
      await testPool.query(
        `INSERT INTO feedback_votes (feedback_id, user_id, vote_type)
         VALUES ($1, 'user1', 'up'), ($1, 'user2', 'up'), ($1, 'user3', 'down')`,
        [feedbackId]
      );

      // Count votes
      const voteResult = await testPool.query(`
        SELECT 
          COUNT(*) FILTER (WHERE vote_type = 'up') as upvotes,
          COUNT(*) FILTER (WHERE vote_type = 'down') as downvotes
        FROM feedback_votes
        WHERE feedback_id = $1
      `, [feedbackId]);

      expect(parseInt(voteResult.rows[0].upvotes)).toBe(2);
      expect(parseInt(voteResult.rows[0].downvotes)).toBe(1);
    });
  });

  describe('Transaction Support', () => {
    it('should rollback transaction on error', async () => {
      const client = await testPool.connect();
      let hasError = false;
      
      try {
        await client.query('BEGIN');
        
        // Insert a valid visit
        await client.query(
          `INSERT INTO visits (endpoint, stage) VALUES ('/test', 'test')`
        );
        
        // This should fail - violate a constraint by inserting duplicate primary key
        // First get an existing ID
        const existingVisit = await testPool.query(
          `INSERT INTO visits (endpoint, stage) VALUES ('/existing', 'test') RETURNING id`
        );
        const existingId = existingVisit.rows[0].id;
        
        // Try to insert with same ID (will fail)
        await client.query(
          `INSERT INTO visits (id, endpoint, stage) VALUES ($1, '/fail', 'test')`,
          [existingId]
        );
        
        await client.query('COMMIT');
      } catch (error) {
        hasError = true;
        await client.query('ROLLBACK');
      } finally {
        client.release();
      }

      expect(hasError).toBe(true); // Ensure we actually hit an error
      
      // Check that only the setup visit was inserted, not the transaction visit
      const result = await testPool.query(`SELECT COUNT(*) FROM visits WHERE endpoint = '/test'`);
      expect(parseInt(result.rows[0].count)).toBe(0);
    });

    it('should commit successful transaction', async () => {
      const client = await testPool.connect();
      
      try {
        await client.query('BEGIN');
        
        await client.query(
          `INSERT INTO visits (endpoint, stage) VALUES ('/test1', 'test')`
        );
        await client.query(
          `INSERT INTO visits (endpoint, stage) VALUES ('/test2', 'test')`
        );
        
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }

      const result = await testPool.query('SELECT COUNT(*) FROM visits');
      expect(parseInt(result.rows[0].count)).toBe(2);
    });
  });

  describe('Database Module Integration', () => {
    let db;

    beforeEach(() => {
      // Clear module cache and reload db module
      jest.resetModules();
      process.env.DATABASE_URL = getTestDatabaseUrl();
      db = require('../../db');
    });

    it('should use test database connection', async () => {
      const isEnabled = await db.isEnabled();
      expect(isEnabled).toBe(true);
    });

    it('should record visits through db module', async () => {
      const result = await db.recordVisit('/api/test', 'test-agent', '127.0.0.1', 25);
      
      expect(result.visit).toBeDefined();
      expect(result.visit.endpoint).toBe('/api/test');
      expect(result.totalVisits).toBe(1);

      // Verify in database
      const dbResult = await testPool.query('SELECT * FROM visits WHERE endpoint = $1', ['/api/test']);
      expect(dbResult.rows).toHaveLength(1);
    });

    it('should get visit statistics through db module', async () => {
      // Seed some data
      await seedDatabase({
        visits: [
          { endpoint: '/api/v1', stage: 'test' },
          { endpoint: '/api/v2', stage: 'test' },
          { endpoint: '/api/v1', stage: 'test' },
        ],
      });

      const stats = await db.getVisitStats();
      
      expect(stats.totalVisits).toBe(3);
      expect(stats.uniquePaths).toBe(2);
      expect(stats.recentVisits).toHaveLength(3);
    });

    it('should check migrations through db module', async () => {
      const migrationStatus = await db.checkMigrations();
      
      expect(migrationStatus.migrated).toBe(true);
      expect(migrationStatus.latest).toBeDefined();
      expect(migrationStatus.runOn).toBeDefined();
    });

    it('should handle feature flags through db module', async () => {
      await seedDatabase({
        featureFlags: [
          { name: 'darkMode', enabled: true },
          { name: 'betaFeatures', enabled: false },
        ],
      });

      const flags = await db.getFeatureFlags();
      
      expect(flags.darkMode).toBe(true);
      expect(flags.betaFeatures).toBe(false);
    });
  });
});