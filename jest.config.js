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
      branches: 30,
      functions: 35,
      lines: 29,
      statements: 29,
    },
  },
  testMatch: ['**/*.test.js'],
  verbose: true,
  testTimeout: 10000,
};
