# Docker Development Setup

This project uses Docker for both local development and CI/CD, with `direnv` for a seamless development experience.

## Quick Start

### Prerequisites
- Docker and Docker Compose
- direnv (`brew install direnv` on macOS)

### Setup

1. **Allow direnv for this project:**
   ```bash
   direnv allow
   ```

2. **Start the development environment:**
   ```bash
   dcup  # Starts both app and database containers
   ```

3. **Run tests:**
   ```bash
   test  # Runs all tests inside Docker automatically
   ```

## Available Commands

Once direnv is activated, all these commands work transparently with Docker:

### Node.js Commands
- `npm [command]` - Run npm commands in container
- `npx [command]` - Run npx commands in container  
- `node [script]` - Run Node.js scripts in container
- `jest [options]` - Run Jest tests directly

### Testing
- `test` - Run all tests
- `test:unit` - Run unit tests only
- `test:integration` - Run integration tests
- `test:watch` - Run tests in watch mode
- `run_tests()` - Run full test suite with migrations

### Database
- `migrate` - Run database migrations
- `migrate:test` - Run test database migrations
- `psql` - Connect to PostgreSQL database
- `db_console()` - Open database console

### Development
- `dev` - Start development server
- `start` - Start production server
- `lint` - Run linter
- `format` - Format code
- `shell` - Open shell in app container

### Docker Compose Shortcuts
- `dcup` - Start all services
- `dcdown` - Stop all services
- `dclogs` - Show logs (follow mode)
- `dcps` - Show running containers
- `dcrestart` - Restart services
- `dcrebuild` - Rebuild and restart

### Utility Functions
- `dx_start()` - Auto-start services if not running
- `clean_env()` - Clean up everything (containers, volumes)

## How It Works

The `.envrc` file sets up aliases that automatically run commands inside Docker containers:

```bash
# When you type:
npm test

# It actually runs:
docker exec -it webapp-app npm test

# Or if container isn't running:
docker compose run --rm app npm test
```

## Docker Compose Profiles

The `docker-compose.yml` uses profiles for different scenarios:

- `--profile db` - Just database
- `--profile app` - Just application
- `--profile test` - Both app and database (default for development)
- `--profile full` - Everything

## Environment Variables

Copy `.env.example` to `.env` to customize:

```bash
cp .env.example .env
```

Key variables:
- `BUILD_TARGET` - `development` or `production`
- `NODE_ENV` - Environment mode
- `DATABASE_URL` - Database connection string
- `APP_PORT` - Application port (default: 8080)

## Examples

### Run specific test file
```bash
jest test/integration/db.integration.test.js
```

### Run database query
```bash
psql -c "SELECT * FROM visits;"
```

### Install new package
```bash
npm install express
```

### Debug in container
```bash
shell  # Opens sh in container
# or
dx bash  # If bash is available
```

### Run any command in container
```bash
dx ls -la
dx cat package.json
```

## CI/CD Testing Locally

To run the exact same tests as CI/CD:

```bash
make test-ci
```

This mimics the Cloud Build pipeline exactly.

## Troubleshooting

### Containers not starting
```bash
# Check status
dcps

# View logs
dclogs

# Rebuild from scratch
dcrebuild
```

### Permission issues
```bash
# Fix ownership
dx chown -R node:node /app
```

### Clean slate
```bash
clean_env()  # Removes all containers and volumes
dcup         # Start fresh
```

## Architecture

```
┌─────────────────────────────────────┐
│         Host Machine                │
│                                     │
│  ┌─────────────────────────────┐   │
│  │     direnv (.envrc)         │   │
│  │  Provides aliases like:     │   │
│  │  - npm → dx npm             │   │
│  │  - test → dx npm test       │   │
│  └──────────┬──────────────────┘   │
│             │                       │
│  ┌──────────▼──────────────────┐   │
│  │   Docker Compose            │   │
│  │                             │   │
│  │  ┌──────────────────┐      │   │
│  │  │   app container   │      │   │
│  │  │  - Node.js 22     │      │   │
│  │  │  - All code       │      │   │
│  │  │  - Tests          │      │   │
│  │  └────────┬─────────┘      │   │
│  │           │                 │   │
│  │  ┌────────▼─────────┐      │   │
│  │  │ postgres container│      │   │
│  │  │  - PostgreSQL 16  │      │   │
│  │  │  - Test database  │      │   │
│  │  └──────────────────┘      │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

The beauty of this setup is that you work as if everything is local, but it all runs in Docker containers automatically!