const express = require('express');
const db = require('./db');

const router = express.Router();

/**
 * Submit new feedback
 */
router.post('/submit', async (req, res) => {
  const enabled = await db.isEnabled();
  if (!enabled) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const {
    user_id,
    email,
    feedback_type = 'other',
    subject,
    message,
    environment = process.env.STAGE || 'unknown'
  } = req.body;

  // Validate required fields
  if (!subject || !message) {
    return res.status(400).json({ 
      error: 'Subject and message are required' 
    });
  }

  // Validate feedback type
  const validTypes = ['bug', 'feature', 'improvement', 'question', 'other'];
  if (!validTypes.includes(feedback_type)) {
    return res.status(400).json({ 
      error: 'Invalid feedback type' 
    });
  }

  try {
    const pool = await db.getPool();
    const userAgent = req.headers['user-agent'] || null;
    const metadata = {
      ip: req.headers['x-forwarded-for'] || req.socket.remoteAddress,
      timestamp: new Date().toISOString(),
      version: process.env.VERSION || 'unknown'
    };

    const result = await pool.query(
      `INSERT INTO user_feedback 
       (user_id, email, feedback_type, subject, message, environment, user_agent, metadata) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) 
       RETURNING id, created_at`,
      [user_id, email, feedback_type, subject, message, environment, userAgent, JSON.stringify(metadata)]
    );

    res.status(201).json({
      success: true,
      feedback_id: result.rows[0].id,
      created_at: result.rows[0].created_at,
      message: 'Thank you for your feedback!'
    });
  } catch (error) {
    console.error('Failed to submit feedback:', error);
    res.status(500).json({ error: 'Failed to submit feedback' });
  }
});

/**
 * Get feedback list (with optional filters)
 */
router.get('/list', async (req, res) => {
  const enabled = await db.isEnabled();
  if (!enabled) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const { 
    status, 
    feedback_type, 
    priority,
    user_id,
    limit = 20,
    offset = 0
  } = req.query;

  try {
    const pool = await db.getPool();
    let query = 'SELECT * FROM user_feedback WHERE 1=1';
    const params = [];
    let paramCount = 0;

    if (status) {
      params.push(status);
      query += ` AND status = $${++paramCount}`;
    }
    if (feedback_type) {
      params.push(feedback_type);
      query += ` AND feedback_type = $${++paramCount}`;
    }
    if (priority) {
      params.push(priority);
      query += ` AND priority = $${++paramCount}`;
    }
    if (user_id) {
      params.push(user_id);
      query += ` AND user_id = $${++paramCount}`;
    }

    query += ' ORDER BY created_at DESC';
    
    params.push(parseInt(limit));
    query += ` LIMIT $${++paramCount}`;
    
    params.push(parseInt(offset));
    query += ` OFFSET $${++paramCount}`;

    const result = await pool.query(query, params);

    // Get total count for pagination
    let countQuery = 'SELECT COUNT(*) FROM user_feedback WHERE 1=1';
    const countParams = [];
    paramCount = 0;

    if (status) {
      countParams.push(status);
      countQuery += ` AND status = $${++paramCount}`;
    }
    if (feedback_type) {
      countParams.push(feedback_type);
      countQuery += ` AND feedback_type = $${++paramCount}`;
    }
    if (priority) {
      countParams.push(priority);
      countQuery += ` AND priority = $${++paramCount}`;
    }
    if (user_id) {
      countParams.push(user_id);
      countQuery += ` AND user_id = $${++paramCount}`;
    }

    const countResult = await pool.query(countQuery, countParams);

    res.json({
      feedback: result.rows,
      total: parseInt(countResult.rows[0].count),
      limit: parseInt(limit),
      offset: parseInt(offset)
    });
  } catch (error) {
    console.error('Failed to fetch feedback:', error);
    res.status(500).json({ error: 'Failed to fetch feedback' });
  }
});

/**
 * Get specific feedback by ID
 */
router.get('/:id', async (req, res) => {
  const enabled = await db.isEnabled();
  if (!enabled) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const { id } = req.params;

  try {
    const pool = await db.getPool();
    
    // Get feedback with responses
    const feedbackResult = await pool.query(
      'SELECT * FROM user_feedback WHERE id = $1',
      [id]
    );

    if (feedbackResult.rows.length === 0) {
      return res.status(404).json({ error: 'Feedback not found' });
    }

    const responsesResult = await pool.query(
      'SELECT * FROM feedback_responses WHERE feedback_id = $1 ORDER BY created_at ASC',
      [id]
    );

    const votesResult = await pool.query(
      `SELECT vote_type, COUNT(*) as count 
       FROM feedback_votes 
       WHERE feedback_id = $1 
       GROUP BY vote_type`,
      [id]
    );

    const votes = {
      up: 0,
      down: 0
    };
    votesResult.rows.forEach(row => {
      votes[row.vote_type] = parseInt(row.count);
    });

    res.json({
      ...feedbackResult.rows[0],
      responses: responsesResult.rows,
      votes
    });
  } catch (error) {
    console.error('Failed to fetch feedback details:', error);
    res.status(500).json({ error: 'Failed to fetch feedback details' });
  }
});

/**
 * Vote on feedback
 */
router.post('/:id/vote', async (req, res) => {
  const enabled = await db.isEnabled();
  if (!enabled) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const { id } = req.params;
  const { user_id, vote_type } = req.body;

  if (!user_id || !['up', 'down'].includes(vote_type)) {
    return res.status(400).json({ 
      error: 'user_id and valid vote_type (up/down) are required' 
    });
  }

  try {
    const pool = await db.getPool();
    
    // Upsert vote (replace if exists)
    await pool.query(
      `INSERT INTO feedback_votes (feedback_id, user_id, vote_type) 
       VALUES ($1, $2, $3) 
       ON CONFLICT (feedback_id, user_id) 
       DO UPDATE SET vote_type = $3, created_at = CURRENT_TIMESTAMP`,
      [id, user_id, vote_type]
    );

    // Get updated vote counts
    const votesResult = await pool.query(
      `SELECT vote_type, COUNT(*) as count 
       FROM feedback_votes 
       WHERE feedback_id = $1 
       GROUP BY vote_type`,
      [id]
    );

    const votes = {
      up: 0,
      down: 0
    };
    votesResult.rows.forEach(row => {
      votes[row.vote_type] = parseInt(row.count);
    });

    res.json({
      success: true,
      votes
    });
  } catch (error) {
    console.error('Failed to vote on feedback:', error);
    res.status(500).json({ error: 'Failed to vote on feedback' });
  }
});

/**
 * Get feedback statistics
 */
router.get('/stats/summary', async (req, res) => {
  const enabled = await db.isEnabled();
  if (!enabled) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  try {
    const pool = await db.getPool();
    
    // Get counts by status
    const statusResult = await pool.query(
      `SELECT status, COUNT(*) as count 
       FROM user_feedback 
       GROUP BY status`
    );

    // Get counts by type
    const typeResult = await pool.query(
      `SELECT feedback_type, COUNT(*) as count 
       FROM user_feedback 
       GROUP BY feedback_type`
    );

    // Get counts by priority
    const priorityResult = await pool.query(
      `SELECT priority, COUNT(*) as count 
       FROM user_feedback 
       GROUP BY priority`
    );

    // Get recent feedback (last 7 days)
    const recentResult = await pool.query(
      `SELECT COUNT(*) as count 
       FROM user_feedback 
       WHERE created_at >= NOW() - INTERVAL '7 days'`
    );

    // Get top voted feedback
    const topVotedResult = await pool.query(
      `SELECT f.id, f.subject, f.feedback_type, 
              COALESCE(SUM(CASE WHEN v.vote_type = 'up' THEN 1 ELSE 0 END), 0) as upvotes,
              COALESCE(SUM(CASE WHEN v.vote_type = 'down' THEN 1 ELSE 0 END), 0) as downvotes
       FROM user_feedback f
       LEFT JOIN feedback_votes v ON f.id = v.feedback_id
       GROUP BY f.id, f.subject, f.feedback_type
       ORDER BY upvotes DESC
       LIMIT 5`
    );

    res.json({
      by_status: statusResult.rows,
      by_type: typeResult.rows,
      by_priority: priorityResult.rows,
      recent_count: parseInt(recentResult.rows[0].count),
      top_voted: topVotedResult.rows
    });
  } catch (error) {
    console.error('Failed to fetch feedback statistics:', error);
    res.status(500).json({ error: 'Failed to fetch feedback statistics' });
  }
});

module.exports = router;