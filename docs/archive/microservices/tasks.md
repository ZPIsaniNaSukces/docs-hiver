# Tasks Service

The Tasks service provides **task management** functionality for assigning, tracking, and completing work items.

## Responsibilities

- Task CRUD operations
- Task assignment to users
- Status tracking (TODO, IN_PROGRESS, DONE)
- Priority management
- Due date tracking

## Port & Database

- **HTTP Port**: 3003
- **Database**: `hiver_tasks` (PostgreSQL)
- **Health Endpoint**: `/tasks`

## Key Entities

### TaskUser
Local copy of user data for task assignments.

**Fields**:
- id (synced from Users service)
- email, phone, companyId

### Task
Work item that can be assigned to users.

**Fields**:
- title, description
- status (TODO, IN_PROGRESS, DONE)
- priority (LOW, MEDIUM, HIGH, URGENT)
- dueDate (optional)
- createdById, assignedToId
- companyId (for multi-tenancy)

## API Endpoints

### Tasks

```
GET    /tasks                       # List tasks (filtered, paginated)
POST   /tasks                       # Create task
GET    /tasks/:id                   # Get task details
PATCH  /tasks/:id                   # Update task
DELETE /tasks/:id                   # Delete task
```

### Task Users (Internal)

```
GET    /task-users                  # List synced users
GET    /task-users/:id              # Get user info
```

## Request/Response Examples

### Create Task

```http
POST /tasks
Authorization: Bearer {token}
Content-Type: application/json

{
  "title": "Implement user authentication",
  "description": "Add JWT-based authentication to API",
  "status": "TODO",
  "priority": "HIGH",
  "assignedToId": 5,
  "dueDate": "2024-12-31"
}
```

Response:
```json
{
  "id": 1,
  "title": "Implement user authentication",
  "description": "Add JWT-based authentication to API",
  "status": "TODO",
  "priority": "HIGH",
  "dueDate": "2024-12-31T00:00:00.000Z",
  "createdById": 1,
  "assignedToId": 5,
  "companyId": 1,
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

### List Tasks (Filtered)

```http
GET /tasks?status=TODO&assignedToId=5&page=1&limit=10
Authorization: Bearer {token}
```

Response:
```json
{
  "data": [
    {
      "id": 1,
      "title": "Implement user authentication",
      "status": "TODO",
      "priority": "HIGH",
      ...
    }
  ],
  "meta": {
    "total": 15,
    "page": 1,
    "limit": 10,
    "totalPages": 2
  }
}
```

### Update Task Status

```http
PATCH /tasks/1
Authorization: Bearer {token}
Content-Type: application/json

{
  "status": "IN_PROGRESS"
}
```

## Business Logic

### Task Creation
1. Validate required fields (title)
2. Set createdById to current user
3. Validate assignedToId exists in same company
4. Set default status (TODO if not provided)
5. Save to database

### Task Assignment
- Only users in same company can be assigned
- Task creator automatically tracked
- Notifications sent to assignee (future)

### Status Transitions
Valid flow:
```
TODO → IN_PROGRESS → DONE
  ↑                    ↓
  └────────────────────┘
```

All transitions allowed (can reopen tasks).

### Priority Levels

```typescript
enum TASK_PRIORITY {
  LOW,      // Nice to have
  MEDIUM,   // Standard priority
  HIGH,     // Important
  URGENT    // Critical, immediate attention
}
```

### Authorization Rules

**View tasks**:
- Admin: All tasks in company
- Manager: Team tasks + own tasks
- Employee: Only own tasks (created by or assigned to)

**Create tasks**:
- Any user can create tasks
- Can assign to any user in same company

**Update tasks**:
- Task creator
- Task assignee  
- Admin/Manager

**Delete tasks**:
- Admin only (future: creator can delete if no assignee)

## Kafka Events

### Consumed Events

**Topic: `users.create`**
Creates `TaskUser` record for new users.

**Topic: `users.update`**
Updates `TaskUser` with new email/phone.

**Topic: `users.remove`**
Deletes `TaskUser` record.

### Published Events (Future)

Potential events for other services:
- `tasks.create` - Notify assignee via Notifications service
- `tasks.assign` - Send push notification
- `tasks.complete` - Notify creator

## Data Filtering

List endpoint supports multiple filters:

```typescript
interface TaskFilters {
  status?: TASK_STATUS;       // Filter by status
  priority?: TASK_PRIORITY;   // Filter by priority
  assignedToId?: number;      // Filter by assignee
  createdById?: number;       // Filter by creator
  companyId?: number;         // Always filtered by user's company
  page?: number;              // Pagination
  limit?: number;
}
```

Combined example:
```http
GET /tasks?status=IN_PROGRESS&priority=HIGH&assignedToId=5
```

## Database Schema

**TaskUser**:
- Synced from Users service
- Prevents cross-service database queries
- Many tasks reference one user

**Task**:
- Many-to-1 with TaskUser (creator)
- Many-to-1 with TaskUser (assignee)
- Indexed by status, priority, assignedToId, companyId

## Testing

Seed data includes sample tasks.

### Create and Assign Task

```bash
# Login as admin
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"alice.admin@acme.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')

# Create task
TASK=$(curl -s -X POST http://localhost:8000/tasks \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Deploy to production",
    "description": "Deploy new features to prod environment",
    "priority": "URGENT",
    "assignedToId": 2,
    "dueDate": "2024-12-31"
  }')

TASK_ID=$(echo $TASK | jq -r '.id')

# Update status
curl -X PATCH http://localhost:8000/tasks/$TASK_ID \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "IN_PROGRESS"}'

# Get task
curl http://localhost:8000/tasks/$TASK_ID \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### List My Tasks

```bash
# Login as employee
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"eve.employee@globex.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')

# Get my tasks
curl "http://localhost:8000/tasks?assignedToId=3" \
  -H "Authorization: Bearer $TOKEN"
```

## Common Workflows

### 1. Daily Task List
Employee views tasks assigned to them:
```
GET /tasks?assignedToId={userId}&status=TODO&status=IN_PROGRESS
```

### 2. Manager Oversight
Manager views team's tasks:
```
GET /tasks?status=IN_PROGRESS
```
(Filtered by manager's teams on backend)

### 3. Urgent Tasks Dashboard
Admin sees all urgent tasks:
```
GET /tasks?priority=URGENT
```

### 4. Overdue Tasks
Tasks past due date (frontend filters):
```
GET /tasks?dueDate=lt:2024-01-15
```

## Validation Rules

- **title**: Required, 1-200 characters
- **description**: Optional, max 2000 characters
- **status**: Must be valid TASK_STATUS enum
- **priority**: Must be valid TASK_PRIORITY enum
- **assignedToId**: Must exist and be in same company
- **dueDate**: Must be valid ISO date, future date preferred

## Error Scenarios

### Assign to Non-existent User
```
POST /tasks {"assignedToId": 999}
→ 404 Not Found: "User not found"
```

### Cross-Company Assignment
```
POST /tasks {"assignedToId": 10} (different company)
→ 403 Forbidden: "Cannot assign task to user from different company"
```

### Unauthorized Update
```
PATCH /tasks/5 (not your task, not admin)
→ 403 Forbidden: "Cannot modify this task"
```

## Dependencies

- **@nestjs/common**: Core framework
- **@prisma/client**: Database access
- **kafkajs**: Event consumption
- **class-validator**: DTO validation

## Performance Considerations

- Indexed queries on status, assignedToId, companyId
- Pagination prevents large result sets
- Eager loading avoided (N+1 problem)

## Future Enhancements

- [ ] Task comments/activity feed
- [ ] File attachments
- [ ] Task dependencies (blockers)
- [ ] Recurring tasks
- [ ] Task templates
- [ ] Time tracking integration
- [ ] Notifications on assignment/completion
- [ ] Task categories/tags
- [ ] Kanban board support
- [ ] Subtasks

## Related Documentation

- [Database Schema](../database.md)
- [API Reference](../api-reference.md)
- [Microservices Overview](README.md)
