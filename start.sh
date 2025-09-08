#!/bin/bash
set -e

echo "Starting webapp with migration support..."

# Check if we should run migrations (only for preview environments)
if [ "$STAGE" = "preview" ] && [ "$DATABASE_HOST" = "localhost" ]; then
    echo "Preview environment detected - running migrations first"
    node migrate.js
fi

# Start the main application
echo "Starting main application..."
exec node app.js