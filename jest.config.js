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
      branches: 35,
      functions: 35,
      lines: 35,
      statements: 35,
    },
  },
  testMatch: ['**/*.test.js'],
  verbose: true,
  testTimeout: 10000,
};
