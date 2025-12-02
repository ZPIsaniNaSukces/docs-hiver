# Message Bus (Kafka)

Apache Kafka serves as the central message bus for asynchronous communication between HiveR microservices.

## Purpose

The message bus provides:
- Decoupled service communication
- Event persistence and replay
- Scalable message distribution
- Reliable event delivery

## Topics

### Core Topics

**`user-events`**
- User lifecycle events
- Authentication events
- Profile updates

**`presence-events`**
- Check-in/check-out events
- Presence calculations
- Schedule updates

**`task-events`**
- Task lifecycle events
- Assignment changes
- Status updates

**`notification-events`**
- Email notifications
- Push notifications
- System alerts

## Event Schema

Events follow a standardized format:

```json
{
  "eventId": "uuid",
  "eventType": "presence.checkin",
  "timestamp": "ISO 8601 timestamp",
  "userId": "user identifier",
  "companyId": "company identifier",
  "payload": {
    // Event-specific data
  },
  "metadata": {
    "source": "service name",
    "version": "schema version"
  }
}
```

## Consumer Groups

Each microservice has its own consumer group:
- `presence-service-group`
- `tasks-service-group`
- `notification-service-group`

## Configuration

### Producers
- Acknowledgment: `all` (strongest guarantee)
- Compression: `snappy`
- Retries: 3

### Consumers
- Auto-commit: `false` (manual commit)
- Offset reset: `earliest`
- Session timeout: 30s

## Best Practices

1. **Idempotency**: Consumers should handle duplicate events
2. **Event Versioning**: Include schema version in metadata
3. **Dead Letter Queue**: Failed events go to DLQ for analysis
4. **Monitoring**: Track lag, throughput, and error rates

## Infrastructure

- Kafka cluster configuration
- Zookeeper ensemble
- Partitioning strategy
- Retention policies

---

Related: [Architecture Overview](../architecture/overview.md)
