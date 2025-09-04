module.exports = {
  testEnvironment: 'node',
  collectCoverageFrom: [
    'app.js',
    '!node_modules/**',
    '!coverage/**',
    '!jest.config.js',
  ],
  coverageThreshold: {
    global: {
      branches: 45,
      functions: 45,
      lines: 50,
      statements: 50,
    },
  },
  testMatch: ['**/*.test.js'],
  verbose: true,
  testTimeout: 10000,
};
