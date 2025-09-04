// Mock database module for testing
const mockDb = {
  isEnabled: jest.fn().mockReturnValue(false), // Database disabled in tests
  initializeSchema: jest.fn().mockResolvedValue(true),
  query: jest.fn(),
  recordVisit: jest.fn().mockResolvedValue({ 
    visit: { 
      id: 1, 
      timestamp: new Date().toISOString(), 
      endpoint: '/test' 
    }, 
    totalVisits: 1 
  }),
  getVisitStats: jest.fn().mockResolvedValue({
    totalVisits: 100,
    uniquePaths: 5,
    recentVisits: []
  }),
  getFeatureFlags: jest.fn().mockResolvedValue({
    darkMode: false,
    betaFeatures: false,
    debugMode: false
  }),
  cleanup: jest.fn()
};

module.exports = mockDb;