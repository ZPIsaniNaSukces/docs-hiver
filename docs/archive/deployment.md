# Deployment Guide

This guide covers deploying Backend Hiver in different environments.

## Overview

Backend Hiver can be deployed using:
- **Docker Compose** (local development, staging)
- **AWS ECS** (production)
- **Kubernetes** (future)

## Prerequisites

### Development
- Docker 20+ and Docker Compose 2+
- Node.js 18+
- npm or yarn

### Production
- AWS account with ECS access
- Docker registry (ECR or Docker Hub)
- PostgreSQL instance (RDS)
- Kafka cluster (MSK or self-hosted)

## Docker Compose Deployment

### Local Development

1. **Clone repository**:
```bash
git clone <repository-url>
cd backend-hiver
```

2. **Set environment variables**:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Start services**:
```bash
docker-compose up -d
```

This starts:
- 5 microservices (users, presence, tasks, leave-requests, notifications)
- Kong API Gateway
- PostgreSQL
- Kafka + Zookeeper
- MailHog (email testing)

4. **Initialize databases**:
```bash
# Apply migrations
npm run prisma:migrate:deploy

# Seed test data
npm run prisma:seed
```

5. **Verify deployment**:
```bash
# Check all services running
docker-compose ps

# Test API
curl http://localhost:8000/users-app/health
```

### Staging Environment

Use the same process but with production-like configuration:

```yaml
# docker-compose.staging.yml
services:
  users:
    image: your-registry/backend-hiver-users:staging
    environment:
      NODE_ENV: staging
      DATABASE_URL: ${STAGING_DATABASE_URL}
```

Deploy:
```bash
docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d
```

## AWS ECS Deployment

### Architecture

```
Internet
   │
   ├─► ALB (Load Balancer)
   │    └─► Kong Gateway (ECS Service)
   │         ├─► Users Service (ECS Service)
   │         ├─► Presence Service (ECS Service)
   │         ├─► Tasks Service (ECS Service)
   │         ├─► Leave Requests Service (ECS Service)
   │         └─► Notifications Service (ECS Service)
   │
   ├─► RDS PostgreSQL (5 databases)
   └─► MSK Kafka Cluster
```

### Prerequisites

1. **Create ECR repositories**:
```bash
aws ecr create-repository --repository-name backend-hiver-users
aws ecr create-repository --repository-name backend-hiver-presence
aws ecr create-repository --repository-name backend-hiver-tasks
aws ecr create-repository --repository-name backend-hiver-leave-requests
aws ecr create-repository --repository-name backend-hiver-notifications
aws ecr create-repository --repository-name backend-hiver-kong
```

2. **Create RDS instance**:
```bash
aws rds create-db-instance \
  --db-instance-identifier backend-hiver-postgres \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --master-username postgres \
  --master-user-password <password> \
  --allocated-storage 100
```

3. **Create databases**:
```bash
psql -h <rds-endpoint> -U postgres -c "CREATE DATABASE hiver_users;"
psql -h <rds-endpoint> -U postgres -c "CREATE DATABASE hiver_presence;"
psql -h <rds-endpoint> -U postgres -c "CREATE DATABASE hiver_tasks;"
psql -h <rds-endpoint> -U postgres -c "CREATE DATABASE hiver_leave_requests;"
psql -h <rds-endpoint> -U postgres -c "CREATE DATABASE hiver_notifications;"
```

4. **Create MSK cluster**:
```bash
aws kafka create-cluster \
  --cluster-name backend-hiver-kafka \
  --broker-node-group-info file://kafka-broker-config.json \
  --kafka-version 2.8.0
```

### Build and Push Images

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build images
docker build -f Dockerfile --target users -t backend-hiver-users .
docker build -f Dockerfile --target presence -t backend-hiver-presence .
docker build -f Dockerfile --target tasks -t backend-hiver-tasks .
docker build -f Dockerfile --target leave-requests -t backend-hiver-leave-requests .
docker build -f Dockerfile --target notifications -t backend-hiver-notifications .
docker build -f Dockerfile.kong -t backend-hiver-kong .

# Tag images
docker tag backend-hiver-users:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/backend-hiver-users:latest
# ... repeat for other services

# Push images
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/backend-hiver-users:latest
# ... repeat for other services
```

### Create ECS Task Definitions

Example for Users service:

```json
{
  "family": "backend-hiver-users",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "users",
      "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/backend-hiver-users:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "3000"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:<account>:secret:backend-hiver/database-url"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:<account>:secret:backend-hiver/jwt-secret"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/backend-hiver-users",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

Create task definitions:
```bash
aws ecs register-task-definition --cli-input-json file://task-def-users.json
aws ecs register-task-definition --cli-input-json file://task-def-presence.json
# ... repeat for other services
```

### Create ECS Services

```bash
aws ecs create-service \
  --cluster backend-hiver \
  --service-name users \
  --task-definition backend-hiver-users \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=users,containerPort=3000"
```

Repeat for all services.

### Configure Kong Gateway

Kong routing configuration is in `kong.ecs.yml`:

```yaml
services:
  - name: users
    url: http://users.backend-hiver.local:3000
    routes:
      - name: users-route
        paths:
          - /users
          - /auth
          - /companies
          - /teams
```

Apply configuration:
```bash
# Via Kong Admin API or deck sync
deck sync --kong-addr http://<kong-admin>:8001
```

### Apply Database Migrations

Run migrations from a one-off ECS task:

```bash
aws ecs run-task \
  --cluster backend-hiver \
  --task-definition backend-hiver-migrations \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx]}"
```

Migration task runs:
```bash
npm run prisma:migrate:deploy
```

## Environment Variables

### Required Variables

```env
# Application
NODE_ENV=production
PORT=3000

# Database (service-specific)
DATABASE_URL=postgresql://user:pass@rds-endpoint:5432/hiver_users

# JWT
JWT_SECRET=long-random-secret-min-32-chars
JWT_EXPIRES_IN=1h

# Kafka
KAFKA_BROKERS=broker1:9092,broker2:9092,broker3:9092
KAFKA_CLIENT_ID=users-service

# Mail (Notifications service only)
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USER=your-email@gmail.com
MAIL_PASSWORD=app-password
MAIL_FROM="Hiver <noreply@hiver.com>"

# Firebase (Notifications service only)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@...
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

### Secrets Management

**Local**: `.env` file (not committed)

**AWS**: Secrets Manager or Parameter Store
```bash
aws secretsmanager create-secret \
  --name backend-hiver/database-url \
  --secret-string "postgresql://..."

aws secretsmanager create-secret \
  --name backend-hiver/jwt-secret \
  --secret-string "<random-secret>"
```

## Health Checks

Each service exposes a health endpoint:

```
GET /users-app/health         → Users
GET /presence-app/health      → Presence
GET /tasks                    → Tasks
GET /leave-requests-app/health → Leave Requests
GET /notifications            → Notifications
```

Configure ALB health checks:
```json
{
  "HealthCheckPath": "/users-app/health",
  "HealthCheckIntervalSeconds": 30,
  "HealthCheckTimeoutSeconds": 5,
  "HealthyThresholdCount": 2,
  "UnhealthyThresholdCount": 3,
  "Matcher": {
    "HttpCode": "200"
  }
}
```

## Monitoring

### Logs

**Local**: Docker logs
```bash
docker-compose logs -f users
```

**AWS**: CloudWatch Logs
```bash
aws logs tail /ecs/backend-hiver-users --follow
```

### Metrics

**Recommended CloudWatch Metrics**:
- CPU utilization
- Memory utilization
- Request count
- Response time
- Error rate

**Custom Metrics**:
- Active users
- Task completion rate
- Leave request approval time

### Alerting

Set up CloudWatch Alarms:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name backend-hiver-high-cpu \
  --alarm-description "High CPU usage" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## Scaling

### Horizontal Scaling

**Auto-scaling based on CPU**:
```bash
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/backend-hiver/users \
  --min-capacity 2 \
  --max-capacity 10

aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/backend-hiver/users \
  --policy-name cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration \
    "TargetValue=70.0,PredefinedMetricSpecification={PredefinedMetricType=ECSServiceAverageCPUUtilization}"
```

### Database Scaling

- **Read Replicas**: For reporting/analytics
- **Vertical Scaling**: Upgrade RDS instance class
- **Connection Pooling**: Configure Prisma pool size

## CI/CD Pipeline

### GitHub Actions Example

```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to ECR
        run: |
          aws ecr get-login-password | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
      
      - name: Build and push
        run: |
          docker build -f Dockerfile --target users -t backend-hiver-users .
          docker tag backend-hiver-users:latest <account>.dkr.ecr.us-east-1.amazonaws.com/backend-hiver-users:latest
          docker push <account>.dkr.ecr.us-east-1.amazonaws.com/backend-hiver-users:latest
      
      - name: Update ECS service
        run: |
          aws ecs update-service --cluster backend-hiver --service users --force-new-deployment
```

## Rollback

### ECS Rollback

```bash
# List task definition revisions
aws ecs list-task-definitions --family-prefix backend-hiver-users

# Update service to previous revision
aws ecs update-service \
  --cluster backend-hiver \
  --service users \
  --task-definition backend-hiver-users:5
```

### Database Rollback

```bash
# Rollback Prisma migration
npm run prisma:migrate:resolve -- --rolled-back <migration-name>
```

## Disaster Recovery

### Backup Strategy

**Databases**:
- RDS automated backups (7-day retention)
- Manual snapshots before major changes

**Configuration**:
- Version control for task definitions
- Store Kong configuration in Git

### Recovery Steps

1. Restore RDS from snapshot
2. Deploy services from last known good images
3. Apply migrations if needed
4. Update DNS/load balancer

## Security

### Network Isolation

- Services in private subnets
- Only ALB/Kong in public subnet
- Security groups restrict traffic

### Secrets

- Never commit secrets to Git
- Use AWS Secrets Manager
- Rotate secrets regularly

### SSL/TLS

- ALB terminates SSL
- Use ACM certificates
- Enforce HTTPS

## Cost Optimization

- Use Fargate Spot for non-critical workloads
- Right-size ECS tasks (CPU/memory)
- Use Aurora Serverless for variable load
- Enable RDS auto-scaling storage

## Related Documentation

- [Getting Started](getting-started.md)
- [Architecture Overview](architecture.md)
- [Environment Variables](.env.example)
