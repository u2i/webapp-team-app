# Multi-stage Dockerfile for both production and development/testing
FROM node:22-slim AS base

# Install PostgreSQL client (needed for testing and migrations)
RUN apt-get update && apt-get install -y postgresql-client && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Development/test stage - includes all dependencies
FROM base AS development
RUN npm ci && npm cache clean --force

# Copy all source code and test files
COPY . .

# Make scripts executable
RUN chmod +x scripts/*.sh start.sh || true

# Use the built-in node user (UID 1000)
USER node

# Production stage - only production dependencies
FROM base AS production
RUN npm ci --only=production && npm cache clean --force

# Copy only production files
COPY app.js db.js migrate.js feedback.js start.sh middleware.js query-builder.js constants.js config.js health.js secret-manager-poc.js .node-pg-migrate ./
COPY migrations ./migrations

# Make start script executable
RUN chmod +x start.sh

# Use the built-in node user (UID 1000)
USER node

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