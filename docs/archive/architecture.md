# Architecture Overview

Backend Hiver follows a **microservices architecture** with event-driven communication, enabling scalability, maintainability, and independent deployment.

## High-Level Architecture

```
┌─────────────┐
│   Client    │
│ (Mobile/Web)│
└──────┬──────┘
       │ HTTP/HTTPS
       ▼
┌─────────────────────┐
│   Kong API Gateway  │◄─── Single entry point
│   (Port 8000)       │     CORS, routing, load balancing
└──────┬──────────────┘
       │
       ├──────────────┬──────────────┬───────────────┬──────────────┐
       │              │              │               │              │
       ▼              ▼              ▼               ▼              ▼
┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌──────────────┐
│   Users   │  │ Presence  │  │   Tasks   │  │  Leave    │  │Notifications │
│  Service  │  │  Service  │  │  Service  │  │ Requests  │  │   Service    │
│ (Port 3000)│ │(Port 3001)│ │(Port 3003)│ │(Port 3002)│ │ (Port 3005)  │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └──────┬───────┘
      │              │              │              │                │
      └──────────────┴──────────────┴──────────────┴────────────────┘
                                    │
                                    ▼
                          ┌──────────────────┐
                          │  Apache Kafka    │◄─── Event Bus
                          │  (Port 9092)     │     Async communication
                          └──────────────────┘
                                    │
      ┌─────────────────────────────┼─────────────────────────────┐
      │                             │                             │
      ▼                             ▼                             ▼
┌──────────┐              ┌──────────────┐              ┌──────────────┐
│PostgreSQL│              │ Firebase FCM │              │   MailHog    │
│(Port 5432)│             │(Push Notifs) │              │ (Port 1025)  │
└──────────┘              └──────────────┘              └──────────────┘
5 separate DBs             Cloud service                Dev email server
```

## Core Architectural Principles

### 1. Microservices Pattern

Each service is:
- **Autonomous**: Can be developed, deployed, and scaled independently
- **Bounded**: Owns a specific business domain
- **Isolated**: Has its own database (no shared DB)
- **Resilient**: Failure in one service doesn't cascade to others

### 2. Database Per Service

Each microservice has its own PostgreSQL database:

- `hiver_users` - User accounts, companies, teams
- `hiver_presence` - Check-ins, NFC tags, location data
- `hiver_tasks` - Tasks, assignments, statuses
- `hiver_leave_requests` - Leave requests, approvals
- `hiver_notifications` - Notification logs, push tokens

**Benefits**:
- Data encapsulation
- Independent schema evolution
- Technology flexibility (can use different DB types per service)
- Fault isolation

**Trade-off**: No database joins across services - use event-driven data replication instead.

### 3. Event-Driven Communication

Services communicate asynchronously via **Apache Kafka**:

```
User Created Event Flow:
┌─────────┐      users.create      ┌──────────────┐
│ Users   ├─────────────────────►  │   Kafka      │
│ Service │                        │   Topic      │
└─────────┘                        └───────┬──────┘
                                           │
                     ┌─────────────────────┼─────────────┐
                     │                     │             │
                     ▼                     ▼             ▼
              ┌──────────┐         ┌──────────┐  ┌──────────┐
              │Presence  │         │  Tasks   │  │ Notifs   │
              │Service   │         │ Service  │  │ Service  │
              └──────────┘         └──────────┘  └──────────┘
               Syncs user          Syncs user     Sends welcome
               info locally        info locally   email
```

**Kafka Topics**:
- `users.create`, `users.update`, `users.remove`
- `notifications.send`
- Future: `tasks.assigned`, `leave.approved`, etc.

**Benefits**:
- Loose coupling between services
- Asynchronous processing (non-blocking)
- Event replay capability
- Natural audit log

### 4. API Gateway Pattern

**Kong API Gateway** provides:

- **Single entry point**: All client requests go through Kong
- **Routing**: Maps URLs to backend services
- **CORS handling**: Cross-origin resource sharing
- **Rate limiting**: Prevent abuse (can be enabled)
- **SSL termination**: HTTPS in production
- **Authentication**: Can validate JWT at gateway level (currently done per-service)

Routes defined in `kong.yml`:
```yaml
/users → users:3000
/presence → presence:3001
/tasks → tasks:3003
/leave-requests → leave-requests:3002
/notifications → notifications:3005
```

### 5. Shared Libraries Pattern

Common functionality is extracted into reusable libraries (`libs/`):

- **@app/auth** - JWT authentication, guards, decorators
- **@app/contracts** - Shared DTOs and interfaces
- **@app/firebase** - Firebase Cloud Messaging
- **@app/mail** - Email service wrapper
- **@app/prisma** - Database utilities
- **@app/pagination** - Pagination helpers
- **@app/search** - Search utilities

**Benefits**:
- Code reuse across services
- Consistent patterns
- Single source of truth for shared logic
- Easier refactoring

## Data Flow Examples

### 1. User Login (Synchronous)

```
1. POST /auth/login
   Client ──────► Kong ──────► Users Service
                               ├── Validate credentials
                               ├── Generate JWT
                               └── Return token
   Client ◄────── Kong ◄────── Users Service
```

### 2. User Creation (Event-Driven)

```
1. POST /users
   Client ──► Kong ──► Users Service
                       ├── Create user in DB
                       └── Publish "users.create" event

2. Kafka distributes event
   Users Service ──► Kafka ──┬──► Presence Service (creates user info)
                             ├──► Tasks Service (creates user info)
                             └──► Notifications Service (sends welcome email)

3. Response (synchronous part)
   Client ◄── Kong ◄── Users Service (returns created user)
```

### 3. Push Notification (Hybrid)

```
1. Task assigned in Tasks Service
   Tasks Service ──► Kafka (topic: notifications.send)

2. Notifications Service consumes event
   Kafka ──► Notifications Service
             ├── Look up user's push tokens
             ├── Send via Firebase FCM
             └── Log notification in DB

3. FCM delivers to device
   Notifications Service ──► Firebase ──► Mobile Device
```

## Deployment Architecture

### Development (Docker Compose)

All services run as Docker containers on a single machine:
- Fast iteration
- Consistent environment
- Easy setup for new developers

### Production (AWS ECS Recommended)

```
┌─────────────────────────────────────────────────────────┐
│                      AWS Cloud                          │
│                                                          │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Application Load Balancer + AWS WAF               │ │
│  └───────────────┬───────────────────────────────────┘ │
│                  │                                      │
│  ┌───────────────▼───────────────────────────────────┐ │
│  │  ECS Cluster (Fargate)                            │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐        │ │
│  │  │ Users    │  │ Presence │  │ Tasks    │        │ │
│  │  │ Service  │  │ Service  │  │ Service  │  ...   │ │
│  │  └──────────┘  └──────────┘  └──────────┘        │ │
│  └───────────────────────────────────────────────────┘ │
│                  │                                      │
│  ┌───────────────▼───────────────────────────────────┐ │
│  │  Amazon MSK (Managed Kafka)                       │ │
│  └───────────────────────────────────────────────────┘ │
│                  │                                      │
│  ┌───────────────▼───────────────────────────────────┐ │
│  │  Amazon RDS (PostgreSQL) - Multi-AZ               │ │
│  │  5 separate databases                             │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

Each service auto-scales based on CPU/memory metrics.

See [Deployment Guide](deployment.md) for detailed instructions.

## Security Architecture

### Authentication Flow

```
1. User logs in
   Client ──► /auth/login ──► Users Service
                               └── Returns JWT

2. Subsequent requests
   Client ──► /tasks (+ JWT header) ──► Kong ──► Tasks Service
                                                  ├── JwtAuthGuard validates token
                                                  ├── Extracts user info
                                                  └── Processes request
```

### Authorization Layers

1. **JWT Validation**: All services validate JWT signatures
2. **Role-Based Access Control (RBAC)**: `@Roles()` decorator enforces roles
3. **Resource Ownership**: Services check if user owns/can access resource

Example:
```typescript
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(USER_ROLE.ADMIN, USER_ROLE.MANAGER)
@Get('reports')
getReports(@CurrentUser() user: AuthenticatedUser) {
  // Only admins and managers can access
}
```

## Scalability Considerations

### Horizontal Scaling

Each microservice can scale independently:
- High user traffic? Scale users service
- Heavy task processing? Scale tasks service
- Notification spikes? Scale notifications service

### Stateless Services

All services are stateless:
- No in-memory session storage
- JWT carries authentication state
- Can add/remove instances freely

### Database Scaling

Each database can scale independently:
- Read replicas for read-heavy services
- Vertical scaling (larger instances)
- Connection pooling via Prisma

### Message Queue

Kafka handles high throughput:
- Partitioned topics for parallelism
- Consumer groups for load distribution
- Message persistence for reliability

## Technology Choices

| Component | Technology | Why? |
|-----------|------------|------|
| **Framework** | NestJS | TypeScript, dependency injection, modularity |
| **Database** | PostgreSQL | ACID compliance, JSON support, mature |
| **ORM** | Prisma | Type-safety, migrations, great DX |
| **Message Queue** | Kafka | High throughput, persistence, replay |
| **API Gateway** | Kong | Production-ready, extensible, performant |
| **Auth** | JWT + Passport | Stateless, standard, flexible |
| **Notifications** | Firebase FCM | Reliable, multi-platform, free tier |
| **Email** | Nodemailer | Flexible, supports all SMTP servers |

## Next Steps

- Explore [Microservices Documentation](microservices/README.md)
- Understand [Database Design](database.md)
- Learn about [Authentication](authentication.md)
- See [API Reference](api-reference.md)
