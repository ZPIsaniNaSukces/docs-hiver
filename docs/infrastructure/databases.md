# Databases

HiveR uses PostgreSQL databases following the database-per-service pattern for data isolation and service independence.

## Database Architecture

Each microservice has its own PostgreSQL database:
- **Main Database**: User and company data
- **Presence Database**: Presence records
- **Tasks Database**: Task management

## Main Database

### Schema Overview

**Users Table**
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    company_id UUID REFERENCES companies(id),
    role VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Companies Table**
```sql
CREATE TABLE companies (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    contact_email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Presence Database

### Schema Overview

**Presence Records Table**
```sql
CREATE TABLE presence_records (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    company_id UUID NOT NULL,
    check_in_time TIMESTAMP NOT NULL,
    check_out_time TIMESTAMP,
    location VARCHAR(255),
    device_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Presence Schedules Table**
```sql
CREATE TABLE presence_schedules (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    day_of_week INTEGER NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Tasks Database

### Schema Overview

**Tasks Table**
```sql
CREATE TABLE tasks (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    company_id UUID NOT NULL,
    creator_id UUID NOT NULL,
    priority VARCHAR(50),
    status VARCHAR(50) DEFAULT 'pending',
    due_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Task Assignments Table**
```sql
CREATE TABLE task_assignments (
    id UUID PRIMARY KEY,
    task_id UUID REFERENCES tasks(id),
    user_id UUID NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);
```

## Database Management

### Migrations
- Schema versioning
- Migration scripts
- Rollback procedures

### Backups
- Automated daily backups
- Point-in-time recovery
- Backup retention policy
- Disaster recovery procedures

### Performance
- Index optimization
- Query performance monitoring
- Connection pooling
- Read replicas (if needed)

## Configuration

### Connection Settings
- Connection pooling parameters
- Timeout configurations
- SSL/TLS settings
- Authentication methods

### Monitoring
- Slow query logging
- Connection monitoring
- Storage usage tracking
- Performance metrics

---

Related: [Infrastructure Overview](overview.md)
