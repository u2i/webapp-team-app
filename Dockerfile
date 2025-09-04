# Multi-stage Dockerfile with test stage
# Stage 1: Testing
FROM node:18-alpine AS test

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy application code and test files
COPY app.js db.js migrate.js app.test.js jest.config.js .node-pg-migrate ./
COPY __mocks__ ./__mocks__
COPY migrations ./migrations

# Run tests
RUN npm run test:ci

# Stage 2: Production build
FROM node:18-alpine AS production

# Create app directory
WORKDIR /app

# Install production dependencies only
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy app source from test stage (ensures tested code)
COPY --from=test /app/app.js ./
COPY --from=test /app/db.js ./
COPY --from=test /app/migrate.js ./
COPY --from=test /app/.node-pg-migrate ./
COPY --from=test /app/migrations ./migrations

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S webapp -u 1001

# Change ownership
RUN chown -R webapp:nodejs /app
USER webapp

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Run the application
CMD ["npm", "start"]

# Labels for compliance and traceability
LABEL maintainer="webapp-team@u2i.com" \
      version="1.0.0" \
      compliance="iso27001-soc2-gdpr" \
      data-residency="eu" \
      gdpr-compliant="true" \
      tenant="webapp-team" \
      test-status="passed"