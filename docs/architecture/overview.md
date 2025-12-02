# Architecture Overview

HiveR follows a microservice architecture pattern with event-driven communication between services. The system is designed to be scalable, maintainable, and resilient.

## Architecture Diagrams

The architecture is documented using C4 diagrams created with Structurizr. These diagrams provide different levels of detail about the system structure.

### Viewing the Diagrams

Interactive C4 diagrams are embedded directly in the documentation pages below. To view them:

1. Ensure Docker is installed
2. Start Structurizr Lite:
   ```bash
   docker run -d --name structurizr -p 8080:8080 -v $(pwd):/usr/local/structurizr structurizr/lite
   ```
3. The diagrams will load automatically in the pages below

View the diagram pages:

- [System Context Diagram](system-context.md) - High-level view showing HiveR and external systems
- [Container Diagram](containers.md) - Major containers (applications and databases)
- [Component Diagram](components.md) - Internal structure of the backend

## Architecture Principles

### Event-Driven Communication

Services communicate asynchronously through Kafka message bus, ensuring loose coupling and high scalability.

### Database Per Service

Each microservice has its own PostgreSQL database, following the database-per-service pattern for data isolation and independence.

### Separation of Concerns

- **Main Service**: User management, authentication, and orchestration
- **Presence Service**: Specialized in tracking employee presence
- **Tasks Service**: Dedicated to task management workflows

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Backend Framework | NestJS |
| Message Bus | Apache Kafka |
| Databases | PostgreSQL |
| Notifications | AWS SNS |
| Mobile App | (TBD) |
| Web App | (TBD) |

## System Characteristics

**Scalability**: Microservices can be scaled independently based on load

**Resilience**: Asynchronous communication and service isolation prevent cascading failures

**Maintainability**: Clear service boundaries and focused responsibilities

**Extensibility**: New services can be added without modifying existing ones

---

Next: [System Context Diagram](system-context.md)
