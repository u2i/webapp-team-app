const SecretManagerPOC = require('./secret-manager-poc');

// Mock the Secret Manager client
jest.mock('@google-cloud/secret-manager', () => ({
  SecretManagerServiceClient: jest.fn().mockImplementation(() => ({
    accessSecretVersion: jest.fn()
  }))
}));

describe('Secret Manager POC Tests', () => {
  let poc;
  const mockProjectId = 'test-project';
  
  beforeEach(() => {
    process.env.PROJECT_ID = mockProjectId;
    process.env.GCP_PROJECT = mockProjectId;
    poc = new SecretManagerPOC();
  });

  afterEach(() => {
    jest.clearAllMocks();
    delete process.env.PROJECT_ID;
    delete process.env.GCP_PROJECT;
    delete process.env.WEBAPP_DEMO_SECRET;
    delete process.env.DEMO_SECRET_NAME;
    delete process.env.DEMO_ENV_VAR;
  });

  describe('Constructor', () => {
    it('should initialize with PROJECT_ID', () => {
      expect(poc.projectId).toBe(mockProjectId);
    });

    it('should fall back to GCP_PROJECT if PROJECT_ID not set', () => {
      delete process.env.PROJECT_ID;
      process.env.GCP_PROJECT = 'fallback-project';
      const newPoc = new SecretManagerPOC();
      expect(newPoc.projectId).toBe('fallback-project');
    });
  });

  describe('Environment Variable Approach', () => {
    it('should get secret from environment variable', () => {
      const testValue = 'test-secret-value';
      const envVarName = 'TEST_SECRET';
      const originalSecretName = 'test-secret';
      
      process.env[envVarName] = testValue;
      
      const result = poc.getSecretViaEnvVar(envVarName, originalSecretName);
      
      expect(result.approach).toBe('kubernetes-env-var');
      expect(result.secretName).toBe(originalSecretName);
      expect(result.envVarName).toBe(envVarName);
      expect(result.value).toBe(testValue);
      expect(result.fetchTimeMs).toBe(0);
      expect(result.metadata.injectedAtStartup).toBe(true);
    });

    it('should throw error when environment variable not found', () => {
      const envVarName = 'NONEXISTENT_SECRET';
      const originalSecretName = 'nonexistent-secret';
      
      expect(() => {
        poc.getSecretViaEnvVar(envVarName, originalSecretName);
      }).toThrow('Failed to get secret via env var: Environment variable NONEXISTENT_SECRET not found');
    });

    it('should filter available environment variables', () => {
      process.env.SECRET_TEST = 'value1';
      process.env.WEBAPP_DEMO_SECRET = 'value2';
      process.env.OTHER_VAR = 'value3';
      
      const result = poc.getSecretViaEnvVar('SECRET_TEST', 'test-secret');
      
      expect(result.metadata.availableEnvVars).toContain('SECRET_TEST');
      expect(result.metadata.availableEnvVars).toContain('WEBAPP_DEMO_SECRET');
      expect(result.metadata.availableEnvVars).not.toContain('OTHER_VAR');
    });
  });

  describe('JavaScript Client Approach', () => {
    it('should fetch secret via client successfully', async () => {
      const mockSecretValue = 'test-secret-value';
      const secretName = 'test-secret';
      
      // Mock the client method directly on the poc instance
      const mockClient = {
        accessSecretVersion: jest.fn().mockResolvedValue([{
          name: `projects/${mockProjectId}/secrets/${secretName}/versions/latest`,
          payload: {
            data: Buffer.from(mockSecretValue)
          }
        }])
      };
      
      poc.secretClient = mockClient;
      
      const result = await poc.fetchSecretViaClient(secretName);
      
      expect(result.approach).toBe('javascript-client');
      expect(result.secretName).toBe(secretName);
      expect(result.value).toBe(mockSecretValue);
      expect(result.fetchTimeMs).toBeGreaterThanOrEqual(0);
      expect(result.metadata.projectId).toBe(mockProjectId);
      expect(result.metadata.resourceName).toBe(`projects/${mockProjectId}/secrets/${secretName}/versions/latest`);
      
      expect(mockClient.accessSecretVersion).toHaveBeenCalledWith({
        name: `projects/${mockProjectId}/secrets/${secretName}/versions/latest`
      });
    });

    it('should throw error when client fails', async () => {
      const secretName = 'failing-secret';
      const errorMessage = 'Access denied';
      
      // Mock the client method to reject
      const mockClient = {
        accessSecretVersion: jest.fn().mockRejectedValue(new Error(errorMessage))
      };
      
      poc.secretClient = mockClient;
      
      await expect(poc.fetchSecretViaClient(secretName))
        .rejects.toThrow(`Failed to fetch secret via client: ${errorMessage}`);
    });

    it('should initialize client on first call', async () => {
      const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');
      const mockClient = new SecretManagerServiceClient();
      mockClient.accessSecretVersion.mockRejectedValue(new Error('Test error'));
      
      // Reset client to null
      poc.secretClient = null;
      
      try {
        await poc.fetchSecretViaClient('test-secret');
      } catch (error) {
        // Expected to fail, just checking client initialization
      }
      
      expect(poc.secretClient).toBeTruthy();
    });
  });

  describe('Compare Approaches', () => {
    it('should compare both approaches successfully', async () => {
      // Setup environment variables
      const testSecretName = 'test-demo-secret';
      const testEnvVarName = 'TEST_DEMO_SECRET';
      const testSecretValue = 'demo-value';
      
      process.env.DEMO_SECRET_NAME = testSecretName;
      process.env.DEMO_ENV_VAR = testEnvVarName;
      process.env[testEnvVarName] = testSecretValue;
      
      // Mock client approach directly on instance
      const mockClient = {
        accessSecretVersion: jest.fn().mockResolvedValue([{
          name: `projects/${mockProjectId}/secrets/${testSecretName}/versions/latest`,
          payload: {
            data: Buffer.from(testSecretValue)
          }
        }])
      };
      
      poc.secretClient = mockClient;
      
      const result = await poc.compareApproaches();
      
      expect(result.comparison.projectId).toBe(mockProjectId);
      expect(result.comparison.secretName).toBe(testSecretName);
      
      // Check client approach result
      expect(result.approaches.client.approach).toBe('javascript-client');
      expect(result.approaches.client.value).toBe(testSecretValue);
      
      // Check env var approach result
      expect(result.approaches.envVar.approach).toBe('kubernetes-env-var');
      expect(result.approaches.envVar.value).toBe(testSecretValue);
      
      // Check analysis
      expect(result.analysis.summary.reliability.clientSuccess).toBe(true);
      expect(result.analysis.summary.reliability.envVarSuccess).toBe(true);
      expect(result.analysis.summary.reliability.recommendation).toContain('Both approaches working');
    });

    it('should handle client approach failure gracefully', async () => {
      // Setup environment variables
      const testSecretName = 'test-demo-secret';
      const testEnvVarName = 'TEST_DEMO_SECRET';
      const testSecretValue = 'demo-value';
      
      process.env.DEMO_SECRET_NAME = testSecretName;
      process.env.DEMO_ENV_VAR = testEnvVarName;
      process.env[testEnvVarName] = testSecretValue;
      
      // Mock client approach failure directly on instance
      const mockClient = {
        accessSecretVersion: jest.fn().mockRejectedValue(new Error('Access denied'))
      };
      
      poc.secretClient = mockClient;
      
      const result = await poc.compareApproaches();
      
      // Check client approach failed
      expect(result.approaches.client.approach).toBe('javascript-client');
      expect(result.approaches.client.error).toContain('Access denied');
      
      // Check env var approach succeeded
      expect(result.approaches.envVar.approach).toBe('kubernetes-env-var');
      expect(result.approaches.envVar.value).toBe(testSecretValue);
      
      // Check analysis
      expect(result.analysis.summary.reliability.clientSuccess).toBe(false);
      expect(result.analysis.summary.reliability.envVarSuccess).toBe(true);
      expect(result.analysis.summary.reliability.recommendation).toContain('Use environment variables');
    });

    it('should use default secret names when env vars not set', async () => {
      // Mock client to avoid actual calls
      poc.secretClient = {
        accessSecretVersion: jest.fn().mockRejectedValue(new Error('Test'))
      };
      
      const result = await poc.compareApproaches();
      
      expect(result.comparison.secretName).toBe('webapp-demo-secret');
    });
  });

  describe('Analysis Methods', () => {
    it('should provide comprehensive trade-off analysis', () => {
      const mockApproaches = {
        client: { fetchTimeMs: 150, approach: 'javascript-client' },
        envVar: { fetchTimeMs: 0, approach: 'kubernetes-env-var' }
      };
      
      const analysis = poc.analyzeApproaches(mockApproaches);
      
      expect(analysis.tradeoffs.client.pros).toContain('Flexible - can fetch any secret at runtime');
      expect(analysis.tradeoffs.client.cons).toContain('Requires network calls (latency)');
      expect(analysis.tradeoffs.envVar.pros).toContain('Immediate availability (no network calls)');
      expect(analysis.tradeoffs.envVar.cons).toContain('Less flexible - must be defined in deployment');
      
      expect(analysis.summary.performance.clientFetchTime).toBe(150);
      expect(analysis.summary.performance.envVarFetchTime).toBe(0);
      expect(analysis.summary.performance.winner).toBe('Environment Variable (instant)');
    });

    it('should handle missing approaches in analysis', () => {
      const mockApproaches = {
        client: { error: 'Failed', approach: 'javascript-client' },
        envVar: { error: 'Not found', approach: 'kubernetes-env-var' }
      };
      
      const analysis = poc.analyzeApproaches(mockApproaches);
      
      expect(analysis.summary.reliability.clientSuccess).toBe(false);
      expect(analysis.summary.reliability.envVarSuccess).toBe(false);
      expect(analysis.summary.reliability.recommendation).toContain('Neither approach working');
    });
  });
});