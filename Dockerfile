# Example Dockerfile for the webapp
FROM node:18-alpine

# Create app directory
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install --only=production

# Copy app source
COPY app.js ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S webapp -u 1001

# Change ownership
RUN chown -R webapp:nodejs /app
USER webapp

# Expose port
EXPOSE 8080

# Run the application
CMD ["npm", "start"]

# Labels for compliance and traceability
LABEL maintainer="webapp-team@u2i.com" \
      version="1.0.0" \
      compliance="iso27001-soc2-gdpr" \
      data-residency="eu" \
      gdpr-compliant="true" \
      tenant="webapp-team"