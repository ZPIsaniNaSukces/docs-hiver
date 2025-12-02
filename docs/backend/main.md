# Main Service

The main service is the core orchestrator of the HiveR system, handling user management, authentication, and event coordination.

## Responsibilities

- User authentication and authorization
- Company management
- API gateway functionality
- Event orchestration and publishing
- Integration with external services (AWS SNS)

## Database Schema

### Main Database (PostgreSQL)

Key tables:
- `users` - User accounts and profiles
- `companies` - Company information
- `roles` - User roles and permissions
- `sessions` - Active user sessions

## API Endpoints

(To be documented once API is finalized)

## Event Publishing

The main service publishes events to Kafka:

- `user.created` - New user registered
- `user.updated` - User profile updated
- `presence.checkin.requested` - Check-in initiated
- `task.created` - New task created
- `notification.send` - Notification requested

## Configuration

Environment variables:
- Database connection strings
- Kafka broker URLs
- AWS SNS credentials
- JWT secrets

## Dependencies

- PostgreSQL database
- Kafka message bus
- AWS SNS

---

Related: [Architecture Components](../architecture/components.md)
