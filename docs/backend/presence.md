# Presence Microservice

The presence microservice is responsible for tracking and managing employee presence, including check-ins, check-outs, and presence history.

## Responsibilities

- Process check-in/check-out events
- Maintain presence history
- Calculate presence statistics
- Generate presence reports
- Manage presence schedules

## Database Schema

### Presence Database (PostgreSQL)

Key tables:
- `presence_records` - Individual check-in/out records
- `presence_schedules` - Expected presence schedules
- `presence_exceptions` - Holidays, sick days, etc.

## Event Subscriptions

Subscribes to Kafka events:

- `presence.checkin` - Employee checked in
- `presence.checkout` - Employee checked out
- `user.created` - Initialize presence tracking for new user

## Event Publishing

Publishes events:

- `presence.recorded` - Presence record created
- `presence.anomaly` - Unusual presence pattern detected

## Business Logic

### Check-In Process
1. Receive check-in event
2. Validate against schedule
3. Create presence record
4. Publish confirmation event

### Presence Calculation
- Daily presence duration
- Weekly/monthly summaries
- Overtime calculation
- Absence tracking

## Configuration

Environment variables:
- Database connection
- Kafka broker
- Business hours configuration

---

Related: [Architecture Components](../architecture/components.md)
