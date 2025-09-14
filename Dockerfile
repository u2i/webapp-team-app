# Production Dockerfile
# Optimized for production deployments with minimal size and security

FROM node:22-slim

# Install only essential runtime dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy package files and install production dependencies only
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy production source files
COPY app.js db.js migrate.js feedback.js start.sh middleware.js query-builder.js constants.js config.js health.js secret-manager-poc.js .node-pg-migrate ./
COPY migrations ./migrations

# Make start script executable
RUN chmod +x start.sh

# Create non-root user for security
RUN useradd -m -u 1000 -s /bin/false appuser && \
    chown -R appuser:appuser /app

USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Run the application using our startup script
CMD ["./start.sh"]

# Labels for compliance and traceability
LABEL maintainer="webapp-team@u2i.com" \
      version="1.0.0" \
      compliance="iso27001-soc2-gdpr" \
      data-residency="eu" \
      gdpr-compliant="true" \
      tenant="webapp-team"