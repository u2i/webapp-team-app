# Production Dockerfile
# Tests are run separately in CI/CD using Docker Compose
FROM node:22-slim AS production

# Create app directory
WORKDIR /app

# Install production dependencies only
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy app source
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