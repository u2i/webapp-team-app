module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/test/integration/**/*.test.js'],
  testTimeout: 30000, // 30 seconds for database operations
  setupFilesAfterEnv: ['<rootDir>/test/setup.js'],
  collectCoverage: true,
  collectCoverageFrom: [
    'db.js',
    'feedback.js',
    'app.js',
    '!node_modules/**',
    '!test/**',
  ],
  coverageDirectory: 'coverage/integration',
  coverageReporters: ['text', 'lcov', 'html'],
  verbose: true,
};