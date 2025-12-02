# Database Architecture

Backend Hiver uses the **database-per-service** pattern with PostgreSQL databases for each microservice.

## Overview

Each microservice has its own isolated database:

```
┌─────────────────┐     ┌─────────────────┐
│  Users Service  │────►│  hiver_users    │
└─────────────────┘     └─────────────────┘

┌─────────────────┐     ┌─────────────────┐
│ Presence Service│────►│ hiver_presence  │
└─────────────────┘     └─────────────────┘

┌─────────────────┐     ┌─────────────────┐
│  Tasks Service  │────►│  hiver_tasks    │
└─────────────────┘     └─────────────────┘

┌─────────────────┐     ┌─────────────────┐
│Leave Req Service│────►│hiver_leave_reqs │
└─────────────────┘     └─────────────────┘

┌─────────────────┐     ┌─────────────────┐
│Notifications Svc│────►│hiver_notif...   │
└─────────────────┘     └─────────────────┘
```

## Why Database-per-Service?

### Benefits

**Service Independence**:
- Deploy services independently
- Scale databases based on service load
- No shared database bottleneck

**Technology Flexibility**:
- Choose optimal database per service
- Currently all PostgreSQL, but could use MongoDB, Redis, etc.

**Fault Isolation**:
- Database failure affects one service only
- No cascading database failures

**Data Ownership**:
- Clear service boundaries
- Single source of truth per domain

### Tradeoffs

**Data Duplication**:
- User data replicated across services
- Mitigated: Only essential fields replicated

**No Foreign Keys Across Services**:
- Cannot enforce referential integrity across databases
- Mitigated: Application-level validation + event sourcing

**Eventual Consistency**:
- Changes propagate via Kafka events
- Mitigated: Use idempotent event handlers

**Complex Queries**:
- Cannot JOIN across services
- Mitigated: API composition or CQRS (future)

## Database Connection

All services connect via Prisma ORM:

```typescript
// Service-specific Prisma client
import { PrismaClient } from '@generated/prisma/{service}-client';

const prisma = new PrismaClient({
  datasourceUrl: process.env.DATABASE_URL
});
```

Connection strings:
```env
# Users service
DATABASE_URL="postgresql://postgres:postgres@postgres:5432/hiver_users"

# Presence service
DATABASE_URL="postgresql://postgres:postgres@postgres:5432/hiver_presence"

# ... etc
```

## Schema Management

### Prisma Schemas

Each service has a schema file:
```
prisma/
├── users/
│   ├── schema.prisma        # User, Company, Team models
│   ├── seed.ts              # Test data
│   └── migrations/          # Version history
├── presence/
│   ├── schema.prisma        # Checkin, NfcTag models
│   ├── seed.ts
│   └── migrations/
└── ... (other services)
```

### Schema Structure

Common pattern in all schemas:

```prisma
generator client {
  provider = "prisma-client-js"
  output   = "../../generated/prisma/{service}-client"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// Models...
```

### Migrations

Each service manages its own migrations:

```bash
# Generate migration
npm run prisma:migrate:dev:users

# Apply migrations
npm run prisma:migrate:deploy:users

# Reset database
npm run prisma:reset:users
```

## Data Synchronization

Services sync data via Kafka events:

### Example: User Creation

```
1. Users Service
   ├── Create user in hiver_users
   └── Publish users.create event

2. Kafka Topic: users.create
   {
     id: 5,
     email: "new@example.com",
     phone: "+1234567890",
     companyId: 1
   }

3. Consuming Services
   ├── Presence: Create CheckinUserInfo
   ├── Tasks: Create TaskUser
   ├── Leave Requests: Create LeaveRequestUser
   └── Notifications: Create NotificationUserInfo
```

### Sync Models

Each service maintains a local copy:

**Users Service** (source of truth):
```prisma
model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  phone     String?
  name      String
  surname   String
  role      USER_ROLE
  companyId Int
  // ... many more fields
}
```

**Tasks Service** (minimal copy):
```prisma
model TaskUser {
  id        Int      @id
  email     String
  phone     String?
  companyId Int
  
  // Relations to tasks
  createdTasks   Task[] @relation("CreatedTasks")
  assignedTasks  Task[] @relation("AssignedTasks")
}
```

Only essential fields are replicated.

## Schema Details

### Users Database (hiver_users)

**Entities**:
- User (15+ fields)
- Company
- Team
- UserTeam (join table)

**Key Relationships**:
- User belongsTo Company
- User belongsToMany Team
- User hasMany User (boss/subordinate)
- Team belongsTo Company

### Presence Database (hiver_presence)

**Entities**:
- CheckinUserInfo (replicated user)
- Checkin
- NfcTag

**Key Relationships**:
- Checkin belongsTo CheckinUserInfo
- Checkin belongsTo NfcTag (optional)
- NfcTag belongsTo Company (via companyId)

### Tasks Database (hiver_tasks)

**Entities**:
- TaskUser (replicated user)
- Task

**Key Relationships**:
- Task belongsTo TaskUser (creator)
- Task belongsTo TaskUser (assignee)

### Leave Requests Database (hiver_leave_requests)

**Entities**:
- LeaveRequestUser (replicated user)
- LeaveRequest
- LeaveBalance
- LeaveType

**Key Relationships**:
- LeaveRequest belongsTo LeaveRequestUser
- LeaveRequest belongsTo LeaveRequestUser (approver)
- LeaveBalance belongsTo LeaveRequestUser

### Notifications Database (hiver_notifications)

**Entities**:
- NotificationUserInfo (replicated user)
- Notification
- NotificationTemplate (future)

**Key Relationships**:
- Notification belongsTo NotificationUserInfo

## Indexing Strategy

Common indexes across services:

- **Primary Keys**: Auto-indexed
- **Foreign Keys**: Indexed for joins
- **Unique Constraints**: Auto-indexed
- **Query Filters**: Indexed (status, companyId, userId)

Example from Tasks:
```prisma
model Task {
  // ... fields
  
  @@index([status])
  @@index([assignedToId])
  @@index([companyId])
  @@index([createdAt])
}
```

## Data Isolation

Multi-tenancy via `companyId`:

```typescript
// All queries filtered by company
const tasks = await prisma.task.findMany({
  where: {
    companyId: currentUser.companyId,
    status: 'TODO'
  }
});
```

**Rule**: Never expose cross-company data.

## Seeding

Each schema has seed data:

```bash
# Seed all databases
npm run prisma:seed

# Seed specific service
npm run prisma:seed:users
```

Seed data includes:
- 2 companies
- 4 teams  
- Test users (admin, manager, employee)
- Sample records per service

## Backup & Recovery

### Development

Docker Compose volumes persist data:
```yaml
volumes:
  postgres-data:
```

Destroy and recreate:
```bash
docker-compose down -v  # Destroys volumes
docker-compose up -d    # Fresh databases
npm run prisma:migrate:deploy  # Apply migrations
npm run prisma:seed            # Restore seed data
```

### Production

**Backup**:
```bash
# Backup all databases
for db in hiver_users hiver_presence hiver_tasks hiver_leave_requests hiver_notifications; do
  pg_dump -h localhost -U postgres $db > backup_$db.sql
done
```

**Restore**:
```bash
psql -h localhost -U postgres hiver_users < backup_hiver_users.sql
```

## Performance Considerations

### Connection Pooling

Prisma manages connection pools:
```typescript
const prisma = new PrismaClient({
  datasourceUrl: process.env.DATABASE_URL,
  log: ['query', 'error', 'warn'],
});
```

Default pool size: 10 connections per service.

### Query Optimization

- Use `select` to fetch only needed fields
- Avoid N+1 queries with `include`
- Use pagination for large datasets
- Index frequently queried fields

### Database Sizing

Development (Docker):
```yaml
environment:
  POSTGRES_SHARED_BUFFERS: 256MB
  POSTGRES_MAX_CONNECTIONS: 100
```

Production (AWS RDS):
- db.t3.medium (2 vCPU, 4GB RAM) minimum
- Autoscaling based on load
- Read replicas for reporting

## Troubleshooting

### "Database does not exist"
```bash
# Create missing databases
docker-compose exec postgres psql -U postgres -c "CREATE DATABASE hiver_users;"
npm run prisma:migrate:deploy:users
```

### "Migration failed"
```bash
# Reset and reapply
npm run prisma:reset:users
npm run prisma:migrate:deploy:users
npm run prisma:seed:users
```

### "Too many connections"
- Check connection pool settings
- Ensure services close connections properly
- Increase `POSTGRES_MAX_CONNECTIONS`

### Schema drift
```bash
# Generate Prisma client from schema
npm run prisma:generate:users
```

## Environment Variables

```env
# PostgreSQL Connection
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Service-specific DATABASE_URL
DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/hiver_users"
```

## Future Enhancements

- [ ] Read replicas for reporting
- [ ] Database sharding by company
- [ ] CQRS pattern for complex queries
- [ ] Event sourcing for audit trail
- [ ] TimescaleDB for time-series data (presence)
- [ ] Redis cache layer
- [ ] GraphQL federation (cross-service queries)

## Related Documentation

- [Microservices Overview](microservices/README.md)
- [Data Synchronization](architecture.md#data-synchronization)
- [Prisma Documentation](https://www.prisma.io/docs)
