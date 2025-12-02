# AWS Services

HiveR integrates with AWS services for notifications and potentially other cloud capabilities.

## AWS SNS (Simple Notification Service)

AWS SNS handles email and push notification delivery for the HiveR system.

### Use Cases

**Email Notifications**:
- Task assignments
- Presence reminders
- System alerts
- Administrative notices

**Push Notifications**:
- Real-time task updates
- Check-in confirmations
- Urgent alerts
- Team messages

### Configuration

#### Topics
- `hiver-emails` - Email notifications
- `hiver-push` - Push notifications
- `hiver-admin` - Admin alerts

#### Subscriptions
- Email endpoints for users
- Mobile device endpoints (FCM/APNS)
- HTTP endpoints for webhooks

### Integration

**Backend → SNS Flow**:
1. Backend service creates notification event
2. Event published to Kafka
3. Notification service consumes event
4. Service calls SNS API
5. SNS delivers notification to endpoint

### IAM Configuration

Required permissions:
- `sns:Publish` - Publish messages
- `sns:CreateTopic` - Create topics
- `sns:Subscribe` - Add subscriptions
- `sns:ListTopics` - List available topics

## Future AWS Services

### Amazon S3
**Potential Use**: File storage for attachments, reports, and backups

**Planned Features**:
- Task attachments
- Profile photos
- Report storage
- Database backups

### Amazon CloudWatch
**Potential Use**: Monitoring and logging

**Planned Features**:
- Application logs
- Performance metrics
- Custom dashboards
- Alerts and alarms

### Amazon RDS
**Potential Use**: Managed PostgreSQL

**Benefits**:
- Automated backups
- High availability
- Read replicas
- Automated patching

### Amazon ECS/EKS
**Potential Use**: Container orchestration

**Benefits**:
- Scalable microservices
- Auto-scaling
- Load balancing
- Service discovery

## Cost Optimization

### SNS Costs
- Pay per request
- Free tier: 1,000 email notifications/month
- Optimize notification batching
- Monitor usage patterns

### General Strategies
- Use appropriate instance sizes
- Implement auto-scaling
- Monitor and optimize data transfer
- Use reserved instances for stable workloads

## Security Best Practices

- Use IAM roles (not access keys)
- Enable encryption in transit
- Implement least privilege access
- Regular security audits
- Enable CloudTrail logging

---

Related: [Infrastructure Overview](overview.md)
