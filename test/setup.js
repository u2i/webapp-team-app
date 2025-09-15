// Test setup file
// Increase test timeout for database operations
jest.setTimeout(30000);

// Set test environment
process.env.NODE_ENV = 'test';
process.env.STAGE = 'test';
process.env.BOUNDARY = 'test';

// Suppress console logs during tests unless DEBUG is set
if (!process.env.DEBUG) {
  global.console = {
    ...console,
    log: jest.fn(),
    debug: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    // Keep error for debugging test failures
    error: console.error,
  };
}