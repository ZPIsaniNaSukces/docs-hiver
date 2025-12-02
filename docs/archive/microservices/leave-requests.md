# Leave Requests Service

The Leave Requests service manages **employee leave** including requests, approvals, balance tracking, and leave types.

## Responsibilities

- Leave request creation and management
- Approval workflows
- Leave balance tracking
- Leave type management (vacation, sick, etc.)
- Leave calendar and history

## Port & Database

- **HTTP Port**: 3002
- **Database**: `hiver_leave_requests` (PostgreSQL)
- **Health Endpoint**: `/leave-requests-app/health`

## Key Entities

### LeaveRequestUser
Local copy of user data for leave requests.

**Fields**:
- id (synced from Users service)
- email, phone, companyId

### LeaveRequest
Request for time off.

**Fields**:
- userId, userEmail, companyId
- startDate, endDate, numberOfDays
- leaveType (VACATION, SICK, PERSONAL, etc.)
- status (PENDING, APPROVED, REJECTED)
- reason (employee's reason for leave)
- approverComment (manager/admin comment)
- approvedById (who approved/rejected)
- createdAt, updatedAt

### LeaveBalance
Tracks remaining leave days per user.

**Fields**:
- userId
- leaveType
- totalDays (annual allocation)
- usedDays (approved leave taken)
- remainingDays (calculated)

### LeaveType
Configurable leave categories.

**Fields**:
- name (VACATION, SICK, PERSONAL, MATERNITY, etc.)
- description
- isPaid (whether leave is paid)
- requiresApproval (whether approval needed)

## API Endpoints

### Leave Requests

```
GET    /leave-requests              # List leave requests (filtered)
POST   /leave-requests              # Create leave request
GET    /leave-requests/:id          # Get request details
PATCH  /leave-requests/:id          # Update request (employee)
DELETE /leave-requests/:id          # Delete request
```

### Approvals

```
PATCH  /leave-requests/:id/approve  # Approve request (Admin/Manager)
PATCH  /leave-requests/:id/reject   # Reject request (Admin/Manager)
```

### Leave Balance

```
GET    /leave-balances              # Get user's leave balances
GET    /leave-balances/:userId      # Get specific user balance (Admin/Manager)
```

### Leave Types (Admin)

```
GET    /leave-types                 # List leave types
POST   /leave-types                 # Create leave type
PATCH  /leave-types/:id             # Update leave type
DELETE /leave-types/:id             # Delete leave type
```

## Request/Response Examples

### Create Leave Request

```http
POST /leave-requests
Authorization: Bearer {token}
Content-Type: application/json

{
  "leaveType": "VACATION",
  "startDate": "2024-07-01",
  "endDate": "2024-07-05",
  "reason": "Family vacation"
}
```

Response:
```json
{
  "id": 1,
  "userId": 5,
  "userEmail": "eve.employee@globex.com",
  "companyId": 2,
  "leaveType": "VACATION",
  "startDate": "2024-07-01T00:00:00.000Z",
  "endDate": "2024-07-05T00:00:00.000Z",
  "numberOfDays": 5,
  "status": "PENDING",
  "reason": "Family vacation",
  "approverComment": null,
  "approvedById": null,
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

### Approve Leave Request

```http
PATCH /leave-requests/1/approve
Authorization: Bearer {manager_token}
Content-Type: application/json

{
  "comment": "Approved. Enjoy your vacation!"
}
```

Response:
```json
{
  "id": 1,
  "status": "APPROVED",
  "approverComment": "Approved. Enjoy your vacation!",
  "approvedById": 2,
  ...
}
```

### Get Leave Balance

```http
GET /leave-balances
Authorization: Bearer {token}
```

Response:
```json
[
  {
    "leaveType": "VACATION",
    "totalDays": 20,
    "usedDays": 5,
    "remainingDays": 15
  },
  {
    "leaveType": "SICK",
    "totalDays": 10,
    "usedDays": 2,
    "remainingDays": 8
  }
]
```

## Business Logic

### Leave Request Creation
1. Validate date range (endDate >= startDate)
2. Calculate numberOfDays (business days)
3. Check if user has sufficient balance
4. Set status to PENDING
5. Send notification to manager

### Date Calculation
- **Business Days**: Excludes weekends (future: holidays)
- **Overlap Detection**: Prevents overlapping leave requests
- **Balance Check**: Ensures user has enough days

### Approval Workflow

```
PENDING ──(approve)──► APPROVED ──► Balance updated
   │
   └──(reject)───────► REJECTED
```

**Rules**:
- Only Admin or user's Manager can approve
- Cannot approve own request
- Approval updates leave balance (usedDays)
- Rejection does not affect balance

### Leave Balance Management

**Initialization**:
- New user gets default balances (e.g., 20 vacation, 10 sick)
- Admin can adjust balances

**Updates**:
- Approved leave deducts from remainingDays
- Rejected/cancelled leave does not affect balance
- Annual reset (future feature)

### Authorization Rules

**Create request**: Any employee
**View requests**:
- Own requests (any user)
- Team requests (Manager)
- All company requests (Admin)

**Approve/Reject**:
- Manager can approve team member requests
- Admin can approve any company request
- Cannot approve own request

**Modify request**: Only if status is PENDING

## Kafka Events

### Consumed Events

**Topic: `users.create`**
Creates `LeaveRequestUser` record and initializes leave balances.

**Topic: `users.update`**
Updates `LeaveRequestUser` with new email/phone.

**Topic: `users.remove`**
Deletes `LeaveRequestUser` record and associated leave data.

### Published Events (Future)

Potential events:
- `leave.requested` - Notify manager
- `leave.approved` - Notify employee
- `leave.rejected` - Notify employee

## Data Filtering

List endpoint supports:

```typescript
interface LeaveRequestFilters {
  status?: LEAVE_STATUS;        // PENDING, APPROVED, REJECTED
  leaveType?: LEAVE_TYPE;       // VACATION, SICK, etc.
  userId?: number;              // Filter by user
  startDate?: Date;             // Filter by date range
  endDate?: Date;
  page?: number;
  limit?: number;
}
```

Examples:
```http
# Pending requests
GET /leave-requests?status=PENDING

# Vacation requests in July
GET /leave-requests?leaveType=VACATION&startDate=2024-07-01&endDate=2024-07-31

# My requests
GET /leave-requests?userId=5
```

## Database Schema

**LeaveRequestUser**:
- Synced from Users service
- Used for leave request ownership

**LeaveRequest**:
- Many-to-1 with LeaveRequestUser
- Optional many-to-1 with LeaveRequestUser (approver)
- Indexed by userId, status, leaveType, dates

**LeaveBalance**:
- One-to-one with User + LeaveType
- Composite unique key (userId, leaveType)

**LeaveType**:
- Configurable by admin
- Seeded with common types (VACATION, SICK, etc.)

## Testing

### Create and Approve Leave Request

```bash
# Login as employee
EMPLOYEE_TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"eve.employee@globex.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')

# Create leave request
LEAVE=$(curl -s -X POST http://localhost:8000/leave-requests \
  -H "Authorization: Bearer $EMPLOYEE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "leaveType": "VACATION",
    "startDate": "2024-07-01",
    "endDate": "2024-07-05",
    "reason": "Summer vacation"
  }')

LEAVE_ID=$(echo $LEAVE | jq -r '.id')

# Login as manager
MANAGER_TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"martin.manager@acme.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')

# Approve request
curl -X PATCH http://localhost:8000/leave-requests/$LEAVE_ID/approve \
  -H "Authorization: Bearer $MANAGER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"comment": "Approved!"}'

# Check balance
curl http://localhost:8000/leave-balances \
  -H "Authorization: Bearer $EMPLOYEE_TOKEN"
```

## Validation Rules

- **startDate**: Required, ISO date format
- **endDate**: Required, must be >= startDate
- **leaveType**: Required, must be valid LEAVE_TYPE
- **reason**: Optional, max 500 characters
- **numberOfDays**: Auto-calculated, must be > 0
- **Balance**: Must have sufficient remaining days

## Error Scenarios

### Insufficient Balance
```
POST /leave-requests {"leaveType": "VACATION", "numberOfDays": 25}
→ 400 Bad Request: "Insufficient leave balance"
```

### Overlapping Dates
```
POST /leave-requests (dates overlap with existing request)
→ 409 Conflict: "Leave request overlaps with existing request"
```

### Unauthorized Approval
```
PATCH /leave-requests/1/approve (not manager/admin)
→ 403 Forbidden: "Not authorized to approve"
```

### Self-approval
```
PATCH /leave-requests/1/approve (own request)
→ 403 Forbidden: "Cannot approve own request"
```

## Dependencies

- **@nestjs/common**: Core framework
- **@prisma/client**: Database access
- **kafkajs**: Event consumption
- **class-validator**: DTO validation

## Common Workflows

### 1. Employee Requests Leave
1. Employee submits request
2. System validates dates and balance
3. Request set to PENDING
4. Manager receives notification (future)

### 2. Manager Reviews Requests
1. Manager views pending team requests
2. Reviews reason and dates
3. Approves or rejects with comment
4. Employee receives notification (future)

### 3. Admin Monitors Leave
1. Admin views all company requests
2. Sees leave calendar/statistics
3. Adjusts balances if needed

## Future Enhancements

- [ ] Holiday calendar integration
- [ ] Half-day leave support
- [ ] Leave request cancellation
- [ ] Annual balance reset (rollover)
- [ ] Leave accrual (monthly accumulation)
- [ ] Delegation during leave
- [ ] Leave reports and analytics
- [ ] Public holidays configuration
- [ ] Leave calendar view
- [ ] Email notifications on status change
- [ ] Manager out-of-office auto-approval escalation

## Related Documentation

- [Database Schema](../database.md)
- [API Reference](../api-reference.md)
- [Microservices Overview](README.md)
