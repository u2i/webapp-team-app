const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');

/**
 * POC: Two approaches to accessing Google Secret Manager
 * 
 * Approach 1: JavaScript Client Library
 * - Direct API calls to Secret Manager
 * - Runtime secret fetching
 * - More flexible, can fetch secrets on-demand
 * 
 * Approach 2: Kubernetes Environment Variable Injection
 * - Secrets injected as environment variables
 * - Available at startup time
 * - More secure for static secrets
 */

class SecretManagerPOC {
  constructor() {
    this.projectId = process.env.PROJECT_ID || process.env.GCP_PROJECT;
    this.secretClient = null;
  }

  /**
   * APPROACH 1: JavaScript Client Library
   * Fetch secret directly using Google Cloud Secret Manager client
   */
  async fetchSecretViaClient(secretName) {
    try {
      // Initialize client if not already done
      if (!this.secretClient) {
        console.log('Initializing Secret Manager client...');
        this.secretClient = new SecretManagerServiceClient();
      }

      const name = `projects/${this.projectId}/secrets/${secretName}/versions/latest`;
      
      console.log(`[CLIENT APPROACH] Fetching secret: ${secretName}`);
      console.log(`[CLIENT APPROACH] Full resource name: ${name}`);
      
      const startTime = Date.now();
      const [version] = await this.secretClient.accessSecretVersion({ name });
      const fetchTime = Date.now() - startTime;
      
      const payload = version.payload.data.toString('utf8');
      
      return {
        approach: 'javascript-client',
        secretName,
        value: payload,
        fetchTimeMs: fetchTime,
        timestamp: new Date().toISOString(),
        metadata: {
          projectId: this.projectId,
          resourceName: name,
          versionName: version.name
        }
      };
    } catch (error) {
      console.error(`[CLIENT APPROACH] Error fetching secret ${secretName}:`, error.message);
      throw new Error(`Failed to fetch secret via client: ${error.message}`);
    }
  }

  /**
   * APPROACH 2: Kubernetes Environment Variable
   * Read secret value from environment variable (injected by K8s)
   */
  getSecretViaEnvVar(envVarName, originalSecretName) {
    try {
      console.log(`[ENV VAR APPROACH] Reading from environment variable: ${envVarName}`);
      
      const value = process.env[envVarName];
      
      if (!value) {
        throw new Error(`Environment variable ${envVarName} not found`);
      }

      return {
        approach: 'kubernetes-env-var',
        secretName: originalSecretName,
        envVarName,
        value,
        fetchTimeMs: 0, // Already loaded at startup
        timestamp: new Date().toISOString(),
        metadata: {
          projectId: this.projectId,
          injectedAtStartup: true,
          availableEnvVars: Object.keys(process.env).filter(key => 
            key.startsWith('SECRET_') || key.includes('WEBAPP_DEMO')
          )
        }
      };
    } catch (error) {
      console.error(`[ENV VAR APPROACH] Error reading env var ${envVarName}:`, error.message);
      throw new Error(`Failed to get secret via env var: ${error.message}`);
    }
  }

  /**
   * Compare both approaches for the demo secret
   */
  async compareApproaches() {
    const results = {
      comparison: {
        timestamp: new Date().toISOString(),
        projectId: this.projectId,
        secretName: 'webapp-demo-secret'
      },
      approaches: {}
    };

    try {
      // Approach 1: JavaScript Client
      console.log('\n=== Testing JavaScript Client Approach ===');
      const clientResult = await this.fetchSecretViaClient('webapp-demo-secret');
      results.approaches.client = clientResult;
      console.log(`✅ Client approach succeeded in ${clientResult.fetchTimeMs}ms`);
    } catch (error) {
      results.approaches.client = {
        approach: 'javascript-client',
        error: error.message,
        timestamp: new Date().toISOString()
      };
      console.log(`❌ Client approach failed: ${error.message}`);
    }

    try {
      // Approach 2: Environment Variable
      console.log('\n=== Testing Environment Variable Approach ===');
      const envResult = this.getSecretViaEnvVar('WEBAPP_DEMO_SECRET', 'webapp-demo-secret');
      results.approaches.envVar = envResult;
      console.log(`✅ Environment variable approach succeeded`);
    } catch (error) {
      results.approaches.envVar = {
        approach: 'kubernetes-env-var',
        error: error.message,
        timestamp: new Date().toISOString()
      };
      console.log(`❌ Environment variable approach failed: ${error.message}`);
    }

    // Add analysis
    results.analysis = this.analyzeApproaches(results.approaches);

    return results;
  }

  /**
   * Analyze the trade-offs between approaches
   */
  analyzeApproaches(approaches) {
    const analysis = {
      summary: {},
      tradeoffs: {
        client: {
          pros: [
            'Flexible - can fetch any secret at runtime',
            'Can fetch secrets on-demand',
            'Can handle dynamic secret names',
            'Full control over retry logic and error handling'
          ],
          cons: [
            'Requires network calls (latency)',
            'Requires proper IAM permissions at runtime',
            'More complex error handling',
            'Potential for API rate limiting'
          ]
        },
        envVar: {
          pros: [
            'Immediate availability (no network calls)',
            'Kubernetes-native approach',
            'Secrets loaded once at startup',
            'Better for static configuration'
          ],
          cons: [
            'Secrets visible in pod environment',
            'Less flexible - must be defined in deployment',
            'Requires pod restart to update secrets',
            'Limited to predefined secrets'
          ]
        }
      }
    };

    // Performance comparison
    if (approaches.client && approaches.envVar && !approaches.client.error && !approaches.envVar.error) {
      analysis.summary.performance = {
        clientFetchTime: approaches.client.fetchTimeMs,
        envVarFetchTime: approaches.envVar.fetchTimeMs,
        winner: approaches.client.fetchTimeMs < 100 ? 'Similar performance' : 'Environment Variable (instant)'
      };
    }

    // Success comparison
    const clientSuccess = approaches.client && !approaches.client.error;
    const envVarSuccess = approaches.envVar && !approaches.envVar.error;

    analysis.summary.reliability = {
      clientSuccess,
      envVarSuccess,
      recommendation: envVarSuccess && clientSuccess 
        ? 'Both approaches working - use env vars for static config, client for dynamic secrets'
        : envVarSuccess 
        ? 'Use environment variables - more reliable in this setup'
        : clientSuccess
        ? 'Use client approach - environment variables not configured'
        : 'Neither approach working - check configuration'
    };

    return analysis;
  }
}

module.exports = SecretManagerPOC;