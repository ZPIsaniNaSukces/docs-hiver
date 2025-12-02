# Microservices

Backend Hiver consists of five independent microservices, each handling a specific business domain.

## Services Overview

| Service | Port | Database | Purpose |
|---------|------|----------|---------|
| [Users](users.md) | 3000 | `hiver_users` | User accounts, companies, teams, authentication |
| [Presence](presence.md) | 3001 | `hiver_presence` | Check-in/out, NFC tags, location tracking |
| [Tasks](tasks.md) | 3003 | `hiver_tasks` | Task management, assignments, status tracking |
| [Leave Requests](leave-requests.md) | 3002 | `hiver_leave_requests` | Leave requests, approvals, balances |
| [Notifications](notifications.md) | 3005 | `hiver_notifications` | Push, email, SMS notifications |

## Communication Patterns

### HTTP (Synchronous)
- Client-facing APIs
- Direct service-to-service calls (rare, avoided when possible)
- Gateway routing

### Kafka Events (Asynchronous)
- Cross-service data synchronization
- Event notifications
- Audit logging

## Common Service Structure

Each microservice follows this structure:

```
apps/{service}/
├── src/
│   ├── main.ts                    # Entry point, bootstrap
│   ├── {service}.module.ts        # Root module
│   ├── {service}.controller.ts    # HTTP endpoints
│   ├── {service}.service.ts       # Business logic
│   ├── {service}-events.controller.ts  # Kafka event handlers
│   ├── {domain}/                  # Domain-specific modules
│   │   ├── {domain}.controller.ts
│   │   ├── {domain}.service.ts
│   │   └── dto/                   # Data transfer objects
│   └── prisma/                    # Prisma client config
└── tsconfig.app.json              # TypeScript config

prisma/{service}/
├── schema.prisma                  # Database schema
├── seed.ts                        # Test data seeding
└── migrations/                    # Database migrations
```

## Service Independence

Each service is independent:

- **Deployable**: Can deploy without affecting others
- **Scalable**: Scale based on individual load
- **Testable**: Test in isolation
- **Maintainable**: Team can own entire service

## Data Synchronization

Services maintain local copies of data they need:

**Example**: When a user is created in Users service:
1. Users service creates user in `hiver_users` database
2. Publishes `users.create` event to Kafka
3. Other services consume the event:
   - Presence service creates `CheckinUserInfo` record
   - Tasks service creates `TaskUser` record  
   - Notifications service creates `NotificationUserInfo` record

**Why?** Each service can operate independently without cross-database queries.

## Service Responsibilities

### Users Service
- **Core Domain**: User management, companies, teams
- **Provides**: Authentication, authorization
- **Publishes**: User lifecycle events
- **Consumes**: None (it's the source of truth)

### Presence Service
- **Core Domain**: Physical presence tracking
- **Provides**: Check-in/out APIs, NFC tag management
- **Publishes**: Presence events (future)
- **Consumes**: User events (to sync user data)

### Tasks Service
- **Core Domain**: Task management
- **Provides**: CRUD for tasks, assignments
- **Publishes**: Task events (future)
- **Consumes**: User events (to sync user data)

### Leave Requests Service
- **Core Domain**: Leave management
- **Provides**: Leave request workflows, approvals
- **Publishes**: Leave events (future)
- **Consumes**: User events (to sync user data)

### Notifications Service
- **Core Domain**: Multi-channel notifications
- **Provides**: Push, email, SMS notifications
- **Publishes**: None
- **Consumes**: User events, notification requests

## Shared Libraries

Services share common functionality via libraries:

- **@app/auth**: JWT guards, decorators, authentication logic
- **@app/contracts**: DTOs, interfaces, event schemas
- **@app/firebase**: Firebase Cloud Messaging wrapper
- **@app/mail**: Email sending service
- **@app/prisma**: Database connection utilities
- **@app/pagination**: Pagination helpers
- **@app/search**: Search functionality

## Service Communication Example

**Scenario**: Admin creates a new employee

```
1. POST /users (HTTP)
   ↓
2. Users Service
   ├── Validates input
   ├── Creates user in DB
   ├── Hashes password
   └── Publishes Kafka event
       ↓
3. Kafka Topic: users.create
   ├──→ Presence Service: Creates CheckinUserInfo
   ├──→ Tasks Service: Creates TaskUser  
   ├──→ Notifications Service: Sends welcome email
   └──→ (Any future services)
       ↓
4. HTTP Response
   ← Returns created user to client
```

## Development Guidelines

### Adding a New Service

1. Create service directory in `apps/`
2. Create Prisma schema in `prisma/`
3. Add service to `docker-compose.yml`
4. Add routes to `kong.yml`
5. Update documentation

### Service Best Practices

- **Single Responsibility**: One service = one business domain
- **API Contracts**: Use DTOs from `@app/contracts`
- **Event Publishing**: Publish events for state changes
- **Error Handling**: Use Prisma exception filters
- **Validation**: Use class-validator decorators
- **Authentication**: Use `JwtAuthGuard` and `RolesGuard`

## Service Details

Click on each service to learn more:

- [Users Service](users.md) - User management and authentication
- [Presence Service](presence.md) - Attendance tracking
- [Tasks Service](tasks.md) - Task management
- [Leave Requests Service](leave-requests.md) - Leave workflows
- [Notifications Service](notifications.md) - Multi-channel messaging
