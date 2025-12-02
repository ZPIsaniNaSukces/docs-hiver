# Tasks Microservice

The tasks microservice handles all task-related operations, including creation, assignment, tracking, and completion.

## Responsibilities

- Task creation and management
- Task assignment to employees
- Task status tracking
- Task dependencies
- Task notifications

## Database Schema

### Tasks Database (PostgreSQL)

Key tables:
- `tasks` - Task definitions and details
- `task_assignments` - Employee task assignments
- `task_dependencies` - Task relationships
- `task_history` - Status change history

## Event Subscriptions

Subscribes to Kafka events:

- `task.create` - New task to be created
- `task.assign` - Task assignment requested
- `task.update` - Task update requested
- `user.created` - Initialize task tracking for new user

## Event Publishing

Publishes events:

- `task.created` - Task successfully created
- `task.assigned` - Task assigned to employee
- `task.completed` - Task marked as complete
- `task.overdue` - Task passed deadline

## Business Logic

### Task Lifecycle
1. **Created** - Initial state
2. **Assigned** - Assigned to employee(s)
3. **In Progress** - Work started
4. **Completed** - Finished
5. **Archived** - Historical record

### Task Features
- Priority levels
- Due dates and reminders
- Subtasks and checklists
- Comments and attachments
- Time tracking

## Configuration

Environment variables:
- Database connection
- Kafka broker
- Task deadline thresholds

---

Related: [Architecture Components](../architecture/components.md)
