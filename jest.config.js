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
      branches: 25,
      functions: 35,
      lines: 25,
      statements: 25,
    },
  },
  testMatch: ['**/*.test.js'],
  verbose: true,
  testTimeout: 10000,
};
