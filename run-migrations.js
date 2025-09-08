#!/usr/bin/env node

/**
 * Standalone migration runner for preview environments
 * Runs migrations before the main application starts
 */

const { spawn } = require('child_process');
const { Client } = require('pg');

// Wait for database to be ready (for sidecar containers)
async function waitForDatabase() {
  if (process.env.DATABASE_HOST === 'localhost') {
    console.log('Waiting for local database to be ready...');
    
    for (let i = 0; i < 30; i++) {
      try {
        const client = new Client({
          host: process.env.DATABASE_HOST,
          port: process.env.DATABASE_PORT || 5432,
          database: process.env.DATABASE_NAME,
          user: process.env.DATABASE_USER,
          password: process.env.DATABASE_PASSWORD,
          ssl: process.env.DATABASE_SSL_MODE === 'disable' ? false : undefined
        });
        await client.connect();
        await client.end();
        console.log('Database is ready!');
        return;
      } catch (error) {
        console.log(`Waiting for database... (${i+1}/30)`);
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }
    throw new Error('Database not ready after 60 seconds');
  }
}

// Run migrations using node-pg-migrate
async function runMigrations() {
  console.log('Running database migrations...');
  
  // For preview environments with local PostgreSQL, run migrations directly
  if (process.env.STAGE === 'preview' && process.env.DATABASE_HOST === 'localhost') {
    const databaseUrl = `postgresql://${process.env.DATABASE_USER}:${process.env.DATABASE_PASSWORD}@${process.env.DATABASE_HOST}:${process.env.DATABASE_PORT}/${process.env.DATABASE_NAME}`;
    
    return new Promise((resolve, reject) => {
      const migrate = spawn('npx', ['node-pg-migrate', 'up'], {
        env: { ...process.env, DATABASE_URL: databaseUrl },
        stdio: ['ignore', 'pipe', 'pipe']
      });
      
      let output = '';
      migrate.stdout.on('data', (data) => {
        output += data.toString();
        console.log(data.toString().trim());
      });
      
      migrate.stderr.on('data', (data) => {
        console.error('Migration error:', data.toString());
      });
      
      migrate.on('close', (code) => {
        if (code === 0) {
          console.log('Migrations completed successfully');
          if (output.includes('Migrations complete')) {
            console.log('All migrations applied');
          }
          resolve();
        } else {
          console.error('Migrations failed with code:', code);
          reject(new Error(`Migration failed with code ${code}`));
        }
      });
      
      // Timeout after 30 seconds
      setTimeout(() => {
        migrate.kill();
        reject(new Error('Migration timeout'));
      }, 30000);
    });
  }
  
  // For other environments, use the regular migrate script
  return new Promise((resolve, reject) => {
    const migrate = spawn('npm', ['run', 'migrate'], {
      stdio: 'inherit',
      env: process.env
    });
    
    migrate.on('close', (code) => {
      if (code === 0) {
        console.log('Migrations completed successfully');
        resolve();
      } else {
        console.error('Migrations failed with code:', code);
        reject(new Error(`Migration failed with code ${code}`));
      }
    });
  });
}

// Main function
async function main() {
  try {
    await waitForDatabase();
    await runMigrations();
    console.log('Migration runner completed successfully');
    process.exit(0);
  } catch (error) {
    console.error('Migration runner failed:', error.message);
    process.exit(1);
  }
}

// Run if this is the main module
if (require.main === module) {
  main();
}

module.exports = { waitForDatabase, runMigrations };