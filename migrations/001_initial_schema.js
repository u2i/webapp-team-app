/* eslint-disable camelcase */

exports.shorthands = undefined;

exports.up = (pgm) => {
  // Create visits table
  pgm.createTable('visits', {
    id: 'id',
    timestamp: {
      type: 'timestamptz',
      default: pgm.func('current_timestamp'),
      notNull: true
    },
    endpoint: {
      type: 'varchar(255)'
    },
    user_agent: {
      type: 'text'
    },
    ip_address: {
      type: 'inet'
    },
    response_time: {
      type: 'integer'
    },
    stage: {
      type: 'varchar(50)'
    }
  });

  // Create index on timestamp for performance
  pgm.createIndex('visits', 'timestamp');

  // Create feature_flags table
  pgm.createTable('feature_flags', {
    id: 'id',
    name: {
      type: 'varchar(255)',
      unique: true,
      notNull: true
    },
    enabled: {
      type: 'boolean',
      default: false
    },
    description: {
      type: 'text'
    },
    created_at: {
      type: 'timestamptz',
      default: pgm.func('current_timestamp'),
      notNull: true
    },
    updated_at: {
      type: 'timestamptz',
      default: pgm.func('current_timestamp'),
      notNull: true
    }
  });

  // Create trigger to update updated_at
  pgm.sql(`
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
  `);

  pgm.sql(`
    CREATE TRIGGER update_feature_flags_updated_at
    BEFORE UPDATE ON feature_flags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  `);

  // Insert default feature flags
  pgm.sql(`
    INSERT INTO feature_flags (name, enabled, description)
    VALUES 
      ('darkMode', false, 'Enable dark mode UI'),
      ('betaFeatures', false, 'Enable beta features'),
      ('debugMode', false, 'Enable debug mode')
    ON CONFLICT (name) DO NOTHING;
  `);
};

exports.down = (pgm) => {
  // Drop trigger and function
  pgm.sql('DROP TRIGGER IF EXISTS update_feature_flags_updated_at ON feature_flags');
  pgm.sql('DROP FUNCTION IF EXISTS update_updated_at_column()');
  
  // Drop tables
  pgm.dropTable('feature_flags');
  pgm.dropTable('visits');
};