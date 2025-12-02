# Backend Hiver Documentation

Welcome to the Backend Hiver documentation! This is a microservices-based backend system built with NestJS.

## What is Backend Hiver?

Backend Hiver is an employee management platform backend that handles user management, presence tracking, leave requests, task management, and notifications through a distributed microservices architecture.

## Quick Links

- [Getting Started](getting-started.md) - Set up your development environment
- [Architecture Overview](architecture.md) - Understand the system design
- [Microservices](microservices/README.md) - Learn about each service
- [Database Design](database.md) - Database schemas and relationships
- [Authentication](authentication.md) - How auth works across services
- [Deployment](deployment.md) - Production deployment guide

## Core Concepts

### Microservices Architecture
Each business domain has its own isolated service with dedicated database, enabling independent development and deployment.

### Event-Driven Communication
Services communicate via Apache Kafka for asynchronous event processing, ensuring loose coupling and reliability.

### API Gateway Pattern
Kong API Gateway serves as the single entry point, routing requests to appropriate microservices.

### Database Per Service
Each microservice maintains its own PostgreSQL database, following microservices best practices for data isolation.

## Technology Stack

- **Runtime**: Node.js 20
- **Framework**: NestJS 11
- **Database**: PostgreSQL 15
- **ORM**: Prisma 6
- **Message Queue**: Apache Kafka
- **API Gateway**: Kong
- **Authentication**: JWT with Passport
- **Notifications**: Firebase Cloud Messaging
- **Email**: Nodemailer with MailHog (dev)
- **Containerization**: Docker & Docker Compose

## Project Structure

```
backend-hiver/
├── apps/              # Microservices
│   ├── users/         # User & company management
│   ├── presence/      # Check-in/out tracking
│   ├── tasks/         # Task management
│   ├── leave-requests/# Leave request handling
│   └── notifications/ # Multi-channel notifications
├── libs/              # Shared libraries
│   ├── auth/          # Authentication & authorization
│   ├── contracts/     # DTOs & interfaces
│   ├── firebase/      # FCM push notifications
│   ├── mail/          # Email service
│   └── prisma/        # Database utilities
├── prisma/            # Database schemas (per service)
├── documentation/     # This documentation
└── docker-compose.yml # Local development setup
```

## Getting Help

- Check the [FAQ](faq.md) for common questions
- Review [Troubleshooting Guide](troubleshooting.md) for common issues
- See [API Reference](api-reference.md) for endpoint documentation
