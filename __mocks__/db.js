// Mock database module for testing
const mockDb = {
  isEnabled: jest.fn().mockResolvedValue(false), // Database disabled in tests - now async
  isEnabledSync: jest.fn().mockReturnValue(false), // Sync version for backward compatibility
  getPool: jest.fn().mockResolvedValue(null),
  initializeSchema: jest.fn().mockResolvedValue(true),
  query: jest.fn().mockResolvedValue({ rows: [] }),
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
  cleanup: jest.fn().mockResolvedValue(null)
};

module.exports = mockDb;