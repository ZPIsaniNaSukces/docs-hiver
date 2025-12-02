# Getting Started

This guide will help you set up your local development environment for Backend Hiver.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** 20+ ([Download](https://nodejs.org/))
- **Docker** & Docker Compose ([Download](https://www.docker.com/))
- **Git** ([Download](https://git-scm.com/))

Optional but recommended:
- **kcat** (formerly kafkacat) - For Kafka debugging
- **VS Code** with REST Client extension - For API testing

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/ZPIsaniNaSukces/backend-hiver.git
cd backend-hiver
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Environment Configuration

Copy the example environment file:

```bash
cp .env.example .env
```

The default values work for local development. Key variables:

```env
# Database URLs (auto-created by Docker)
DATABASE_URL="postgresql://postgres:password@localhost:5432/hiver_users"
PRESENCE_DATABASE_URL="postgresql://postgres:password@localhost:5432/hiver_presence"
TASKS_DATABASE_URL="postgresql://postgres:password@localhost:5432/hiver_tasks"
LEAVE_REQUESTS_DATABASE_URL="postgresql://postgres:password@localhost:5432/hiver_leave_requests"
NOTIFICATIONS_DATABASE_URL="postgresql://postgres:password@localhost:5432/hiver_notifications"

# Security
JWT_SECRET=your-secret-key-change-in-production
JWT_EXPIRES_IN=1h

# Kafka
KAFKA_BROKER=localhost:9092

# Email (MailHog for development)
MAIL_HOST=localhost
MAIL_PORT=1025
```

### 4. Start Infrastructure Services

Start PostgreSQL, Kafka, Zookeeper, and MailHog:

```bash
docker-compose up -d postgres kafka zookeeper mailhog
```

Wait ~10 seconds for services to be ready.

### 5. Generate Prisma Clients

Generate database clients for all microservices:

```bash
npm run prisma:generate
```

### 6. Run Database Migrations

Create database schemas:

```bash
npm run prisma:migrate:users
npm run prisma:migrate:presence
npm run prisma:migrate:tasks
npm run prisma:migrate:leave-requests
npm run prisma:migrate:notifications
```

### 7. Seed Development Data

Populate databases with test data:

```bash
npm run prisma:seed
```

This creates:
- 2 companies (Acme Corp, Globex)
- 4 teams across companies
- 3 users with different roles (Admin, Manager, Employee)

Default test accounts:
- **Admin**: `alice.admin@acme.com` / `ChangeMe123!`
- **Manager**: `martin.manager@acme.com` / `ChangeMe123!`
- **Employee**: `eve.employee@globex.com` / `ChangeMe123!`

## Running the Application

### Option A: All Services via Docker (Recommended)

Build and start all services:

```bash
docker-compose up -d --build
```

This starts:
- All microservices (users, presence, tasks, leave-requests, notifications)
- Kong API Gateway (port 8000)
- Infrastructure services

Check service health:

```bash
docker-compose ps
```

### Option B: Individual Services for Development

Run specific services locally for faster development:

```bash
# Terminal 1 - Users service
npm run start:dev users

# Terminal 2 - Presence service
npm run start:dev presence

# Terminal 3 - Tasks service
npm run start:dev tasks

# Terminal 4 - Notifications service
npm run start:dev notifications
```

You'll still need Kong and infrastructure via Docker:

```bash
docker-compose up -d postgres kafka zookeeper mailhog kong-dbless
```

## Verifying the Setup

### 1. Check API Gateway

```bash
curl http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice.admin@acme.com","password":"ChangeMe123!"}'
```

Expected: JWT token response.

### 2. Check MailHog UI

Open [http://localhost:8025](http://localhost:8025) - You should see the MailHog web interface (email catcher for development).

### 3. Check Kafka

```bash
# List topics (requires kcat)
kcat -L -b localhost:9092
```

Expected: List of Kafka topics including `users.create`, `notifications.send`, etc.

### 4. Check Prisma Studio

View database contents:

```bash
npm run prisma:studio:users
```

Opens Prisma Studio at [http://localhost:5555](http://localhost:5555).

## Development Workflow

### Making Changes

1. **Edit code** in `apps/` or `libs/`
2. **TypeScript compilation** happens automatically in watch mode
3. **Hot reload** restarts the service
4. **Test changes** via API or Kafka

### Database Changes

1. **Modify schema** in `prisma/{service}/schema.prisma`
2. **Create migration**:
   ```bash
   npm run prisma:migrate:users  # or other service
   ```
3. **Generate client**:
   ```bash
   npm run prisma:generate:users
   ```

### Testing

Run tests:

```bash
npm test                    # All tests
npm run test:watch          # Watch mode
npm run test:cov           # With coverage
```

### Code Quality

```bash
npm run lint               # Check linting
npm run typecheck          # TypeScript validation
npm run format             # Format with Prettier
```

## Common Commands

```bash
# Development
npm run start:dev {service}        # Start service in dev mode
npm run build                       # Build all services

# Database
npm run prisma:studio:{service}    # Open Prisma Studio
npm run prisma:generate            # Generate all clients
npm run prisma:seed                # Seed all databases

# Docker
docker-compose up -d               # Start all services
docker-compose logs -f {service}   # View logs
docker-compose restart {service}   # Restart service
docker-compose down                # Stop all services

# Testing
./test-push-notifications.sh       # Test push notifications
```

## Next Steps

- Review [Architecture Overview](architecture.md) to understand the system
- Explore [API Reference](api-reference.md) for available endpoints
- Check [Microservices Documentation](microservices/README.md) for service details
- Read [Authentication Guide](authentication.md) for auth implementation

## Troubleshooting

If you encounter issues:

1. **Check service logs**: `docker-compose logs {service}`
2. **Verify environment**: Ensure all variables in `.env` are set
3. **Restart services**: `docker-compose restart`
4. **Clean rebuild**: `docker-compose down && docker-compose up -d --build`
5. **Check port conflicts**: Ensure ports 8000, 5432, 9092 are available

See [Troubleshooting Guide](troubleshooting.md) for detailed solutions.
