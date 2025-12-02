# Backend Overview

The HiveR backend is built using a microservice architecture with NestJS framework, PostgreSQL databases, and Kafka for inter-service communication.

## Services

- [Main Service](main.md) - Core orchestration and user management
- [Presence Microservice](presence.md) - Employee presence tracking
- [Tasks Microservice](tasks.md) - Task management system
- [Message Bus](bus.md) - Event-driven communication with Kafka

## Architecture Patterns

### Microservices
Each service is independently deployable and scalable, with clear boundaries and responsibilities.

### Event-Driven
Services communicate asynchronously through Kafka, reducing coupling and improving resilience.

### Database Per Service
Each microservice manages its own PostgreSQL database, ensuring data isolation and service autonomy.

## Technology Stack

- **Framework**: NestJS (Node.js)
- **Language**: TypeScript
- **Databases**: PostgreSQL
- **Message Broker**: Apache Kafka
- **API Style**: REST/GraphQL (TBD)

## Development Practices

### Code Organization
Each service follows NestJS module structure:
- Controllers (API endpoints)
- Services (business logic)
- Repositories (data access)
- DTOs (data transfer objects)
- Events (Kafka events)

### Testing
- Unit tests for business logic
- Integration tests for database operations
- E2E tests for API endpoints
- Event-driven tests for Kafka consumers

## Getting Started

(Add setup instructions here once repositories are established)

---

Explore individual services for detailed documentation.
