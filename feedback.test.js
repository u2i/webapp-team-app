const request = require('supertest');
const express = require('express');

// Mock the database module
jest.mock('./db');
const db = require('./db');

describe('Feedback API Tests', () => {
  let app;
  let mockPool;

  beforeEach(() => {
    // Clear all mocks
    jest.clearAllMocks();

    // Setup mock pool
    mockPool = {
      query: jest.fn(),
    };

    // Setup default db mocks
    db.isEnabled.mockResolvedValue(true);
    db.getPool.mockResolvedValue(mockPool);

    // Create fresh express app with feedback router
    app = express();
    app.use(express.json());
    const feedbackRouter = require('./feedback');
    app.use('/feedback', feedbackRouter);
  });

  describe('POST /feedback/submit', () => {
    it('should submit feedback successfully', async () => {
      mockPool.query.mockResolvedValue({
        rows: [{ id: 1, created_at: '2024-01-01T00:00:00Z' }],
      });

      const response = await request(app)
        .post('/feedback/submit')
        .send({
          user_id: 'user123',
          email: 'test@example.com',
          feedback_type: 'feature',
          subject: 'New feature request',
          message: 'Please add dark mode',
        })
        .expect('Content-Type', /json/)
        .expect(201);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('feedback_id', 1);
      expect(response.body).toHaveProperty(
        'message',
        'Thank you for your feedback!'
      );
      expect(mockPool.query).toHaveBeenCalledTimes(1);
    });

    it('should reject feedback without required fields', async () => {
      const response = await request(app)
        .post('/feedback/submit')
        .send({
          user_id: 'user123',
          feedback_type: 'feature',
        })
        .expect(400);

      expect(response.body).toHaveProperty(
        'error',
        'Subject and message are required'
      );
      expect(mockPool.query).not.toHaveBeenCalled();
    });

    it('should reject invalid feedback type', async () => {
      const response = await request(app)
        .post('/feedback/submit')
        .send({
          subject: 'Test',
          message: 'Test message',
          feedback_type: 'invalid',
        })
        .expect(400);

      expect(response.body).toHaveProperty('error', 'Invalid feedback type');
    });

    it('should handle database errors', async () => {
      mockPool.query.mockRejectedValue(new Error('Database error'));

      const response = await request(app)
        .post('/feedback/submit')
        .send({
          subject: 'Test',
          message: 'Test message',
        })
        .expect(500);

      expect(response.body).toHaveProperty(
        'error',
        'Failed to submit feedback'
      );
    });

    it('should return 503 when database is disabled', async () => {
      db.isEnabled.mockResolvedValue(false);

      const response = await request(app)
        .post('/feedback/submit')
        .send({
          subject: 'Test',
          message: 'Test message',
        })
        .expect(503);

      expect(response.body).toHaveProperty('error', 'Database not configured');
    });
  });

  describe('GET /feedback/list', () => {
    it('should return feedback list', async () => {
      const mockFeedback = [
        { id: 1, subject: 'Test 1', status: 'pending' },
        { id: 2, subject: 'Test 2', status: 'resolved' },
      ];

      mockPool.query
        .mockResolvedValueOnce({ rows: mockFeedback })
        .mockResolvedValueOnce({ rows: [{ count: '2' }] });

      const response = await request(app)
        .get('/feedback/list')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('feedback');
      expect(response.body.feedback).toHaveLength(2);
      expect(response.body).toHaveProperty('total', 2);
      expect(mockPool.query).toHaveBeenCalledTimes(2);
    });

    it('should filter by status', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ count: '0' }] });

      await request(app).get('/feedback/list?status=resolved').expect(200);

      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('status = $'),
        expect.arrayContaining(['resolved'])
      );
    });

    it('should support pagination', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ count: '100' }] });

      const response = await request(app)
        .get('/feedback/list?limit=10&offset=20')
        .expect(200);

      expect(response.body).toHaveProperty('limit', 10);
      expect(response.body).toHaveProperty('offset', 20);
      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('LIMIT'),
        expect.arrayContaining([10, 20])
      );
    });
  });

  describe('GET /feedback/:id', () => {
    it('should return feedback details with responses and votes', async () => {
      mockPool.query
        .mockResolvedValueOnce({
          rows: [{ id: 1, subject: 'Test feedback', status: 'pending' }],
        })
        .mockResolvedValueOnce({
          rows: [{ id: 1, response: 'Thank you for your feedback' }],
        })
        .mockResolvedValueOnce({
          rows: [
            { vote_type: 'up', count: '5' },
            { vote_type: 'down', count: '2' },
          ],
        });

      const response = await request(app)
        .get('/feedback/1')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('id', 1);
      expect(response.body).toHaveProperty('responses');
      expect(response.body).toHaveProperty('votes');
      expect(response.body.votes).toEqual({ up: 5, down: 2 });
    });

    it('should return 404 for non-existent feedback', async () => {
      mockPool.query.mockResolvedValueOnce({ rows: [] });

      const response = await request(app).get('/feedback/999').expect(404);

      expect(response.body).toHaveProperty('error', 'Feedback not found');
    });
  });

  describe('POST /feedback/:id/vote', () => {
    it('should record vote successfully', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [] }) // upsert
        .mockResolvedValueOnce({
          rows: [{ vote_type: 'up', count: '1' }],
        });

      const response = await request(app)
        .post('/feedback/1/vote')
        .send({
          user_id: 'user123',
          vote_type: 'up',
        })
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('votes');
      expect(response.body.votes).toEqual({ up: 1, down: 0 });
    });

    it('should reject invalid vote type', async () => {
      const response = await request(app)
        .post('/feedback/1/vote')
        .send({
          user_id: 'user123',
          vote_type: 'invalid',
        })
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('GET /feedback/stats/summary', () => {
    it('should return feedback statistics', async () => {
      mockPool.query
        .mockResolvedValueOnce({
          rows: [
            { status: 'pending', count: '10' },
            { status: 'resolved', count: '5' },
          ],
        })
        .mockResolvedValueOnce({
          rows: [
            { feedback_type: 'bug', count: '8' },
            { feedback_type: 'feature', count: '7' },
          ],
        })
        .mockResolvedValueOnce({
          rows: [
            { priority: 'high', count: '3' },
            { priority: 'medium', count: '12' },
          ],
        })
        .mockResolvedValueOnce({
          rows: [{ count: '15' }],
        })
        .mockResolvedValueOnce({
          rows: [{ id: 1, subject: 'Popular', upvotes: '10', downvotes: '1' }],
        });

      const response = await request(app)
        .get('/feedback/stats/summary')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('by_status');
      expect(response.body).toHaveProperty('by_type');
      expect(response.body).toHaveProperty('by_priority');
      expect(response.body).toHaveProperty('recent_count', 15);
      expect(response.body).toHaveProperty('top_voted');
      expect(mockPool.query).toHaveBeenCalledTimes(5);
    });
  });
});
