#!/usr/bin/env node

const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');
const { spawn, execSync } = require('child_process');

// Configuration
const PROJECT_ID = process.env.PROJECT_ID || process.env.GCP_PROJECT;
const BOUNDARY = process.env.BOUNDARY || 'nonprod';
const STAGE = process.env.STAGE || 'dev';

async function fetchDatabaseUrl() {
  // First check if DATABASE_URL is already provided via environment
  if (process.env.DATABASE_URL) {
    console.log('Using DATABASE_URL from environment variable');
    return process.env.DATABASE_URL;
  }

  // Check if we have individual database parameters
  if (process.env.DATABASE_HOST) {
    console.log('Using individual database parameters from environment');
    const host = process.env.DATABASE_HOST;
    const port = process.env.DATABASE_PORT || 5432;
    const database = process.env.DATABASE_NAME;
    const user = process.env.DATABASE_USER;
    const password = process.env.DATABASE_PASSWORD;
    return `postgresql://${user}:${password}@${host}:${port}/${database}`;
  }

  // Skip Secret Manager for preview environments
  if (STAGE === 'preview') {
    console.log('Preview environment: skipping Secret Manager (use ConfigMap instead)');
    return null;
  }

  // Try to fetch from Secret Manager
  if (!PROJECT_ID) {
    throw new Error('No PROJECT_ID found, cannot fetch database credentials');
  }

  // Construct the secret name based on boundary
  const secretName = `webapp-${BOUNDARY}-neon-db-connection`;
  
  try {
    // Create Secret Manager client when needed
    const secretClient = new SecretManagerServiceClient();
    
    const name = `projects/${PROJECT_ID}/secrets/${secretName}/versions/latest`;
    
    console.log(`Fetching database credentials from Secret Manager: ${secretName}`);
    console.log(`Project: ${PROJECT_ID}`);
    
    // Direct call without timeout to see actual error
    const [version] = await secretClient.accessSecretVersion({ name });
    const payload = version.payload.data.toString('utf8');
    
    console.log('Successfully retrieved database credentials from Secret Manager');
    return payload;
  } catch (error) {
    console.error('Secret Manager error details:', error);
    console.error('Error code:', error.code);
    console.error('Error details:', error.details);
    // If it's a permission issue, try to provide more context
    if (error.code === 7 || error.code === 403) {
      console.error('This might be a workload identity issue. Check that:');
      console.error(`1. Service account webapp-k8s@${PROJECT_ID}.iam.gserviceaccount.com exists`);
      console.error(`2. It has secretmanager.secretAccessor role for secret ${secretName}`);
      console.error(`3. Workload identity binding exists for namespace ${process.env.NAMESPACE || 'unknown'}`);
    }
    throw new Error(`Failed to fetch database credentials from Secret Manager: ${error.message}`);
  }
}

async function runMigrations() {
  console.log('Starting database migrations...');
  console.log(`Environment: ${STAGE} (${BOUNDARY} boundary)`);
  
  try {
    // Fetch database URL
    const databaseUrl = await fetchDatabaseUrl();
    
    if (!databaseUrl) {
      if (STAGE === 'preview') {
        console.log('No database configured for preview environment, skipping migrations');
        console.log('To enable database: create webapp-neon-db-config ConfigMap');
        process.exit(0);
      }
      throw new Error('No database configuration available');
    }

    // Get command line arguments (default to 'up')
    const args = process.argv.slice(2);
    const command = args[0] || 'up';
    
    console.log(`Running migrations: ${command}`);
    
    // Run node-pg-migrate using npx to ensure it's found
    const migrate = spawn('npx', ['node-pg-migrate', command, ...args.slice(1)], {
      env: {
        ...process.env,
        DATABASE_URL: databaseUrl
      },
      stdio: 'inherit',
      cwd: process.cwd()
    });

    migrate.on('error', (error) => {
      console.error('Failed to start migration process:', error);
      process.exit(1);
    });

    migrate.on('close', (code) => {
      if (code !== 0) {
        console.error(`Migration process exited with code ${code}`);
        process.exit(code);
      }
      console.log('Migrations completed successfully');
      process.exit(0);
    });

  } catch (error) {
    console.error('Migration failed:', error.message);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down...');
  process.exit(0);
});

// Run migrations
runMigrations().catch((error) => {
  console.error('Unexpected error:', error);
  process.exit(1);
});