# Authentication & Authorization

Backend Hiver uses **JWT (JSON Web Tokens)** with **Role-Based Access Control (RBAC)** for authentication and authorization.

## Overview

Authentication is handled by the **Users service** but validated by **all services** independently using a shared authentication library (`@app/auth`).

## Authentication Flow

### 1. Login

```
Client                Users Service              Database
  │                        │                        │
  ├─ POST /auth/login ────►│                        │
  │  email, password       │                        │
  │                        ├─ Query user ──────────►│
  │                        │◄─ User + hash ─────────┤
  │                        │                        │
  │                        ├─ Verify password       │
  │                        ├─ Generate JWT tokens   │
  │                        │                        │
  │◄─ Access + Refresh ────┤                        │
  │   tokens + user        │                        │
```

### 2. Authenticated Request

```
Client               Kong Gateway          Target Service
  │                       │                      │
  ├─ GET /tasks ─────────►│                      │
  │  Authorization: Bearer │                      │
  │                       ├─ Route to service ───►│
  │                       │                      │
  │                       │                      ├─ Extract JWT
  │                       │                      ├─ Validate signature
  │                       │                      ├─ Check expiration
  │                       │                      ├─ Verify roles
  │                       │                      ├─ Execute handler
  │                       │                      │
  │◄────── Response ───────┼──────────────────────┤
```

## JWT Structure

### Access Token (Short-lived: 1h)

```typescript
{
  // Standard claims
  sub: 1,                    // Subject (user ID)
  iat: 1701461234,          // Issued at
  exp: 1701464834,          // Expires at (1h later)
  
  // User identity
  email: "alice@acme.com",
  role: "ADMIN",
  name: "Alice",
  surname: "Admin",
  
  // Organization
  companyId: 1,
  teamIds: [1],
  teams: [{ id: 1, name: "Engineering" }],
  
  // Optional fields
  phone: "+1234567890",
  title: "CTO",
  bossId: null,
  accountStatus: "VERIFIED"
}
```

### Refresh Token (Long-lived: 7 days)
Same payload as access token but longer expiration.

## Token Management

### Generating Tokens

```typescript
// In Users service
const payload = {
  sub: user.id,
  email: user.email,
  role: user.role,
  // ... other fields
};

const accessToken = await this.jwtService.signAsync(payload, {
  expiresIn: process.env.JWT_EXPIRES_IN || '1h',
});

const refreshToken = await this.jwtService.signAsync(payload, {
  expiresIn: '7d',
});
```

### Refreshing Tokens

```http
POST /auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJhbGc..."
}
```

Response: New access token + new refresh token.

### Token Storage (Client-side)

**Recommended**:
- Access token: Memory (not localStorage)
- Refresh token: httpOnly cookie or secure storage
- Implement token rotation

## Authorization

### Role-Based Access Control (RBAC)

Three roles with hierarchical permissions:

```typescript
enum USER_ROLE {
  ADMIN,      // Full access to company data
  MANAGER,    // Team and subordinate management
  EMPLOYEE    // Own data only
}
```

**Permission Hierarchy**:
- ADMIN can do everything MANAGER can do
- MANAGER can do everything EMPLOYEE can do
- EMPLOYEE has base permissions

### Guards & Decorators

#### JwtAuthGuard
Validates JWT token on every request.

```typescript
@UseGuards(JwtAuthGuard)
@Get('profile')
getProfile(@CurrentUser() user: AuthenticatedUser) {
  return user;
}
```

#### RolesGuard
Enforces role-based access.

```typescript
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(USER_ROLE.ADMIN, USER_ROLE.MANAGER)
@Get('reports')
getReports() {
  // Only admins and managers can access
}
```

#### @CurrentUser() Decorator
Injects authenticated user into handler.

```typescript
@Get('my-tasks')
getMyTasks(@CurrentUser() user: AuthenticatedUser) {
  return this.tasksService.findByUserId(user.id);
}

// Or extract specific field
@Get('company-users')
getCompanyUsers(@CurrentUser('companyId') companyId: number) {
  return this.usersService.findByCompany(companyId);
}
```

### Resource Ownership

Services implement ownership checks:

```typescript
async updateTask(taskId: number, user: AuthenticatedUser, dto: UpdateTaskDto) {
  const task = await this.findOne(taskId);
  
  // Check ownership or admin/manager role
  if (
    task.assignedToId !== user.id &&
    user.role !== USER_ROLE.ADMIN &&
    user.role !== USER_ROLE.MANAGER
  ) {
    throw new ForbiddenException('Cannot modify task');
  }
  
  return this.update(taskId, dto);
}
```

## Security Best Practices

### Password Security

```typescript
// Hashing on creation/update (bcrypt, 12 rounds)
const hashedPassword = await bcrypt.hash(plainPassword, 12);

// Verification
const isValid = await bcrypt.compare(plainPassword, hashedPassword);
```

### Token Security

- **Short expiration**: Access tokens expire in 1h
- **Refresh rotation**: New refresh token on each use
- **Secret key**: Strong random string in production
- **HTTPS only**: Always use HTTPS in production
- **httpOnly cookies**: For refresh tokens when possible

### Request Validation

All inputs validated using class-validator:

```typescript
export class LoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @IsNotEmpty()
  password!: string;
}
```

### Rate Limiting (Recommended)

Add Kong rate limiting plugin:
```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 20
      hour: 500
```

## Authentication Library (@app/auth)

Centralized authentication logic shared across all services.

### Exports

```typescript
// Guards
export { JwtAuthGuard } from './guards/jwt-auth.guard';
export { RolesGuard } from './guards/roles.guard';

// Decorators
export { Roles } from './decorators/roles.decorator';
export { CurrentUser } from './decorators/current-user.decorator';

// Types
export type { AuthenticatedUser } from './interfaces/authenticated-user.type';

// Module
export { AuthModule } from './auth.module';
```

### Usage in Services

```typescript
// Import in module
import { AuthModule } from '@app/auth';

@Module({
  imports: [AuthModule, ...],
  ...
})
export class TasksModule {}

// Use in controller
import { JwtAuthGuard, RolesGuard, Roles, CurrentUser } from '@app/auth';

@Controller('tasks')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TasksController {
  @Get()
  @Roles(USER_ROLE.ADMIN)
  findAll(@CurrentUser() user: AuthenticatedUser) {
    // Implementation
  }
}
```

## Account States

```typescript
enum ACCOUNT_STATUS {
  PENDING,      // Registered but not verified
  VERIFIED,     // Active account
  SUSPENDED,    // Temporarily disabled
  DEACTIVATED   // Permanently disabled
}
```

Pending accounts cannot login until verified (future feature: email verification).

## Multi-Tenancy

Data isolation by company:

```typescript
// All queries filtered by companyId
const users = await this.prisma.user.findMany({
  where: {
    companyId: currentUser.companyId,
    // ... other filters
  },
});
```

**Rule**: Users can only access data within their company.

## Testing Authentication

### Getting a Token

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice.admin@acme.com",
    "password": "ChangeMe123!"
  }' | jq -r '.accessToken')
```

### Using the Token

```bash
curl http://localhost:8000/users \
  -H "Authorization: Bearer $TOKEN"
```

### Testing Different Roles

```bash
# Admin
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"alice.admin@acme.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')

# Manager
MANAGER_TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"martin.manager@acme.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')

# Employee
EMPLOYEE_TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"eve.employee@globex.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')
```

## Common Issues

### "Unauthorized" Error
- Token expired (refresh it)
- Token missing from header
- Invalid token signature

### "Forbidden" Error
- User doesn't have required role
- User doesn't own the resource
- Cross-company access attempt

### Token Not Refreshing
- Refresh token expired (7 days)
- User logged out (revocation feature needed)

## Environment Variables

```env
# Required
JWT_SECRET=your-long-random-secret-min-32-chars

# Optional (with defaults)
JWT_EXPIRES_IN=1h                    # Access token lifetime
JWT_REFRESH_EXPIRES_IN=7d            # Refresh token lifetime
```

**Production**: Use strong random secrets (64+ characters).

## Future Enhancements

- [ ] Email verification on signup
- [ ] Password reset flow
- [ ] Two-factor authentication (2FA)
- [ ] OAuth2 integration (Google, GitHub)
- [ ] Session management and revocation
- [ ] Audit logging
- [ ] API key authentication for M2M

## Related Documentation

- [Users Service](microservices/users.md)
- [API Reference](api-reference.md)
- [Security Best Practices](security.md)
