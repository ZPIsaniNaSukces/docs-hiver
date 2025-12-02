# Users Service

The Users service is the **foundation** of the platform, handling user accounts, companies, teams, and authentication.

## Responsibilities

- User account management (CRUD)
- Company management
- Team management and hierarchy
- JWT authentication and authorization
- User lifecycle event publishing

## Port & Database

- **HTTP Port**: 3000
- **Database**: `hiver_users` (PostgreSQL)
- **Health Endpoint**: `/users-app/health`

## Key Entities

### User
Core entity representing a person in the system.

**Fields**:
- Personal: name, surname, email, phone, dateOfBirth
- Work: title, role (ADMIN/MANAGER/EMPLOYEE)
- Organization: companyId, teams[], bossId
- Auth: password (hashed), accountStatus

**Roles**:
- `ADMIN`: Full system access, can manage all users
- `MANAGER`: Team management, can manage subordinates  
- `EMPLOYEE`: Basic access, can manage own data

### Company
Organizations using the platform.

**Fields**:
- name, domain (optional)
- users[], teams[]

### Team
Work units within a company.

**Fields**:
- name, companyId, leaderId
- members[] (many-to-many with users)

## API Endpoints

### Authentication

```
POST   /auth/login          # Login with credentials
POST   /auth/refresh        # Refresh access token
GET    /auth/me             # Get current user profile
```

### Users

```
GET    /users               # List users (paginated, searchable)
POST   /users               # Create user (Admin only)
GET    /users/:id           # Get user by ID
PATCH  /users/:id           # Update user
DELETE /users/:id           # Delete user

POST   /users/register      # Register new user (Admin only)
PATCH  /users/:id/complete-registration  # Complete first-time setup
```

### Companies

```
GET    /companies           # List companies
POST   /companies           # Create company
GET    /companies/:id       # Get company
PATCH  /companies/:id       # Update company
DELETE /companies/:id       # Delete company
```

### Teams

```
GET    /teams               # List teams
POST   /teams               # Create team
GET    /teams/:id           # Get team
PATCH  /teams/:id           # Update team
DELETE /teams/:id           # Delete team
```

## Kafka Events

### Published Events

**Topic: `users.create`**
```typescript
{
  id: number;
  email: string;
  phone?: string;
  companyId: number;
}
```
Triggered when a new user is created.

**Topic: `users.update`**
```typescript
{
  id: number;
  email?: string;
  phone?: string;
  companyId?: number;
}
```
Triggered when user info changes (email, phone, company).

**Topic: `users.remove`**
```typescript
{
  id: number;
}
```
Triggered when a user is deleted.

## Authentication Flow

### Login
1. Client sends email + password
2. Service validates credentials
3. Generates JWT access token (1h expiry)
4. Generates refresh token (7d expiry)
5. Returns both tokens + user profile

### JWT Structure
```typescript
{
  sub: userId,          // Subject (user ID)
  email: string,
  role: USER_ROLE,
  name: string,
  surname: string,
  phone: string | null,
  title: string | null,
  bossId: number | null,
  companyId: number,
  teamIds: number[],
  teams: { id: number; name: string }[],
  accountStatus: ACCOUNT_STATUS,
  iat: timestamp,       // Issued at
  exp: timestamp        // Expires at
}
```

### Token Validation
Every protected endpoint:
1. Extracts JWT from `Authorization: Bearer {token}` header
2. Validates signature using `JWT_SECRET`
3. Checks expiration
4. Injects user info into request context

## Business Logic

### User Registration Flow
1. Admin creates user via `/users/register`
2. Service generates temporary password
3. Sends welcome email with temp password
4. User logs in with temp password
5. User completes registration (sets real password, name, etc.)
6. Account becomes fully active

### Authorization Checks
- **Resource Ownership**: Users can only modify their own data
- **Role-Based**: Admins can modify any user in their company
- **Team-Based**: Managers can view/modify team members

### Data Isolation
- Users can only see/manage users in their company
- Cross-company data access is prevented at query level

## Database Schema

Key relationships:
- User `belongsTo` Company
- User `belongsToMany` Team (through UserTeam join table)
- User `hasMany` User (boss/subordinate relationship)
- Team `belongsTo` Company
- Team `hasOne` User (leader)

## Common Operations

### Search Users
Supports searching by:
- Name (case-insensitive)
- Surname (case-insensitive)
- Email (case-insensitive)

Combined with pagination:
```
GET /users?search=john&page=1&limit=10
```

### Pagination
All list endpoints support:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 10, max: 100)

Returns:
```typescript
{
  data: T[],
  meta: {
    total: number,
    page: number,
    limit: number,
    totalPages: number
  }
}
```

## Testing

Seed data includes:
- 2 companies (Acme Corp, Globex)
- 4 teams (2 per company)
- 3 users with different roles

Test accounts:
```
Admin:    alice.admin@acme.com     / ChangeMe123!
Manager:  martin.manager@acme.com  / ChangeMe123!
Employee: eve.employee@globex.com  / ChangeMe123!
```

## Dependencies

- **@nestjs/jwt**: JWT token generation
- **@nestjs/passport**: Authentication strategies
- **bcrypt**: Password hashing
- **passport-jwt**: JWT validation strategy

## Related Documentation

- [Authentication Guide](../authentication.md)
- [Database Schema](../database.md)
- [API Reference](../api-reference.md)
