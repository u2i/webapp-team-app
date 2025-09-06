/**
 * User Feedback System Migration
 * Adds tables for collecting and managing user feedback
 */

exports.up = (pgm) => {
  // Create feedback table
  pgm.createTable('user_feedback', {
    id: 'id',
    user_id: { type: 'varchar(255)' },
    email: { type: 'varchar(255)' },
    feedback_type: { 
      type: 'varchar(50)', 
      notNull: true,
      check: "feedback_type IN ('bug', 'feature', 'improvement', 'question', 'other')"
    },
    subject: { type: 'varchar(500)', notNull: true },
    message: { type: 'text', notNull: true },
    status: { 
      type: 'varchar(50)', 
      notNull: true, 
      default: 'pending',
      check: "status IN ('pending', 'reviewed', 'in_progress', 'resolved', 'closed')"
    },
    priority: { 
      type: 'varchar(20)', 
      default: 'medium',
      check: "priority IN ('low', 'medium', 'high', 'urgent')"
    },
    environment: { type: 'varchar(50)' },
    user_agent: { type: 'text' },
    metadata: { type: 'jsonb' },
    created_at: {
      type: 'timestamp',
      notNull: true,
      default: pgm.func('current_timestamp')
    },
    updated_at: {
      type: 'timestamp',
      notNull: true,
      default: pgm.func('current_timestamp')
    },
    resolved_at: { type: 'timestamp' }
  });

  // Create feedback responses table for admin responses
  pgm.createTable('feedback_responses', {
    id: 'id',
    feedback_id: {
      type: 'integer',
      notNull: true,
      references: '"user_feedback"',
      onDelete: 'CASCADE'
    },
    responder_id: { type: 'varchar(255)', notNull: true },
    response: { type: 'text', notNull: true },
    is_public: { type: 'boolean', default: false },
    created_at: {
      type: 'timestamp',
      notNull: true,
      default: pgm.func('current_timestamp')
    }
  });

  // Create feedback votes table for prioritization
  pgm.createTable('feedback_votes', {
    id: 'id',
    feedback_id: {
      type: 'integer',
      notNull: true,
      references: '"user_feedback"',
      onDelete: 'CASCADE'
    },
    user_id: { type: 'varchar(255)', notNull: true },
    vote_type: { 
      type: 'varchar(10)', 
      notNull: true,
      check: "vote_type IN ('up', 'down')"
    },
    created_at: {
      type: 'timestamp',
      notNull: true,
      default: pgm.func('current_timestamp')
    }
  });

  // Create indexes for better performance
  pgm.createIndex('user_feedback', 'user_id');
  pgm.createIndex('user_feedback', 'status');
  pgm.createIndex('user_feedback', 'feedback_type');
  pgm.createIndex('user_feedback', 'priority');
  pgm.createIndex('user_feedback', 'created_at');
  pgm.createIndex('feedback_responses', 'feedback_id');
  pgm.createIndex('feedback_votes', ['feedback_id', 'user_id'], { unique: true });

  // Create trigger to update updated_at timestamp
  pgm.sql(`
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ language 'plpgsql';
  `);

  pgm.sql(`
    CREATE TRIGGER update_user_feedback_updated_at BEFORE UPDATE
    ON user_feedback FOR EACH ROW EXECUTE PROCEDURE 
    update_updated_at_column();
  `);
};

exports.down = (pgm) => {
  // Drop triggers first
  pgm.sql('DROP TRIGGER IF EXISTS update_user_feedback_updated_at ON user_feedback');
  pgm.sql('DROP FUNCTION IF EXISTS update_updated_at_column');

  // Drop tables in reverse order due to foreign key constraints
  pgm.dropTable('feedback_votes');
  pgm.dropTable('feedback_responses');
  pgm.dropTable('user_feedback');
};