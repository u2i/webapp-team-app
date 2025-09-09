# Multi-stage Dockerfile with test stage
# Stage 1: Testing
FROM node:22-slim AS test

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy application code and test files
COPY app.js db.js migrate.js feedback.js start.sh middleware.js query-builder.js constants.js config.js health.js secret-manager-poc.js app.test.js feedback.test.js jest.config.js .node-pg-migrate ./
COPY __mocks__ ./__mocks__
COPY migrations ./migrations

# Run tests
RUN npm run test:ci

# Stage 2: Production build
FROM node:22-slim AS production

# Create app directory
WORKDIR /app

# Install production dependencies only
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy app source from test stage (ensures tested code)
COPY --from=test /app/app.js ./
COPY --from=test /app/db.js ./
COPY --from=test /app/migrate.js ./
COPY --from=test /app/feedback.js ./
COPY --from=test /app/start.sh ./
COPY --from=test /app/middleware.js ./
COPY --from=test /app/query-builder.js ./
COPY --from=test /app/constants.js ./
COPY --from=test /app/config.js ./
COPY --from=test /app/health.js ./
COPY --from=test /app/secret-manager-poc.js ./
COPY --from=test /app/.node-pg-migrate ./
COPY --from=test /app/migrations ./migrations

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
      tenant="webapp-team" \
      test-status="passed"