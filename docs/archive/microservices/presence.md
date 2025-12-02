# Presence Service

The Presence service manages **employee attendance tracking** through check-ins, check-outs, and NFC tag-based location verification.

## Responsibilities

- Physical presence tracking (check-in/out)
- NFC tag management for location verification
- User check-in history
- Location-based attendance validation

## Port & Database

- **HTTP Port**: 3001
- **Database**: `hiver_presence` (PostgreSQL)
- **Health Endpoint**: `/presence-app/health`

## Key Entities

### CheckinUserInfo
Local copy of user data for check-ins.

**Fields**:
- id (synced from Users service)
- email, phone, companyId

### Checkin
Attendance record for a user.

**Fields**:
- userId, userEmail, companyId
- checkinTime (when user checked in)
- checkoutTime (when user checked out, nullable)
- nfcTagId (if checked in via NFC)
- status (CHECKED_IN/CHECKED_OUT)

### NfcTag
Physical NFC tags placed at office locations.

**Fields**:
- tagId (unique identifier)
- location (e.g., "Main Office", "Warehouse")
- companyId

## API Endpoints

### Check-in/out

```
POST   /checkin                      # Check in (with optional NFC)
POST   /checkin/checkout             # Check out
GET    /checkin/status               # Get current check-in status
GET    /checkin                      # Get check-in history
```

### NFC Tags

```
GET    /nfc-tags                     # List company's NFC tags
POST   /nfc-tags                     # Create NFC tag
GET    /nfc-tags/:id                 # Get tag details
PATCH  /nfc-tags/:id                 # Update tag
DELETE /nfc-tags/:id                 # Delete tag
```

### User Info (Internal)

```
GET    /checkin-user-info            # List synced users
GET    /checkin-user-info/:id        # Get user info
```

## Business Logic

### Check-in Flow

```
1. User initiates check-in
   ├── Optional: Scans NFC tag
   └── Submits check-in request

2. Service validates
   ├── User not already checked in
   ├── NFC tag exists (if provided)
   └── NFC tag belongs to user's company

3. Create check-in record
   ├── Save checkinTime
   ├── Save nfcTagId (if used)
   └── Set status: CHECKED_IN

4. Return confirmation
```

### Check-out Flow

```
1. User initiates check-out

2. Service validates
   ├── User is currently checked in
   └── Checkout time > checkin time

3. Update check-in record
   ├── Save checkoutTime
   └── Set status: CHECKED_OUT

4. Calculate duration worked
```

### NFC Tag Verification

NFC tags enable location-based attendance:
- **Admin** registers NFC tags with locations
- **Employee** scans tag during check-in
- **System** verifies employee is at registered location
- **Record** includes location in check-in data

## Kafka Events

### Consumed Events

**Topic: `users.create`**
Creates `CheckinUserInfo` record for new users.

**Topic: `users.update`**
Updates `CheckinUserInfo` with new email/phone.

**Topic: `users.remove`**
Deletes `CheckinUserInfo` record.

### Published Events (Future)

Potential events for other services:
- `presence.checkin` - When employee checks in
- `presence.checkout` - When employee checks out

## Use Cases

### 1. Office Check-in
Employee arrives at office:
1. Scans NFC tag at entrance
2. App captures tag ID
3. Submits check-in with tag ID
4. System validates and records

### 2. Remote Check-in
Employee works remotely:
1. Opens app
2. Clicks "Check In"
3. System records without NFC tag

### 3. Multi-location Check-in
Company has multiple offices:
1. Admin creates NFC tags per location
2. Employee checks in at correct location
3. System tracks which office employee used

## Database Schema

**CheckinUserInfo**:
- Synced from Users service via Kafka
- Used to join check-ins with user data
- Prevents cross-service database queries

**Checkin**:
- Many-to-1 with CheckinUserInfo
- Optional many-to-1 with NfcTag
- Indexed by userId, checkinTime, status

**NfcTag**:
- Many-to-1 with Company
- Unique constraint on tagId

## Data Synchronization

User data flows from Users service:

```
Users Service                Presence Service
      │                            │
      ├─ CREATE user              │
      ├─ Publish Kafka event ────►│
      │                           ├─ Consume event
      │                           ├─ CREATE CheckinUserInfo
      │                           └─ Ready for check-ins
```

This ensures Presence service can operate independently without querying Users service.

## Testing

Seed data includes:
- 1 NFC tag per company
- Sample check-in records

Test check-in:
```bash
# Login
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"alice.admin@acme.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')

# Check in
curl -X POST http://localhost:8000/checkin \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"nfcTagId":"acme-nfc-001"}'

# Get status
curl http://localhost:8000/checkin/status \
  -H "Authorization: Bearer $TOKEN"

# Check out
curl -X POST http://localhost:8000/checkin/checkout \
  -H "Authorization: Bearer $TOKEN"
```

## Authorization

- **Check-in/out**: Any authenticated user
- **NFC Tag Management**: Admin only
- **View History**: Own history or Admin/Manager for team

## Common Operations

### Register NFC Tag

```bash
curl -X POST http://localhost:8000/nfc-tags \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "tagId": "nfc-entrance-01",
    "location": "Main Entrance"
  }'
```

### Check-in with NFC

```bash
curl -X POST http://localhost:8000/checkin \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nfcTagId": "nfc-entrance-01"
  }'
```

### Get Check-in History

```bash
# My history
curl "http://localhost:8000/checkin?page=1&limit=10" \
  -H "Authorization: Bearer $TOKEN"

# Specific date range (future feature)
curl "http://localhost:8000/checkin?startDate=2024-01-01&endDate=2024-01-31" \
  -H "Authorization: Bearer $TOKEN"
```

## Error Scenarios

### Already Checked In
```
POST /checkin
→ 400 Bad Request: "User is already checked in"
```

### Not Checked In
```
POST /checkin/checkout
→ 400 Bad Request: "User is not checked in"
```

### Invalid NFC Tag
```
POST /checkin {"nfcTagId": "unknown"}
→ 404 Not Found: "NFC tag not found"
```

### Cross-Company NFC Tag
```
POST /checkin {"nfcTagId": "other-company-tag"}
→ 403 Forbidden: "NFC tag does not belong to your company"
```

## Dependencies

- **@nestjs/common**: Core framework
- **@prisma/client**: Database access
- **kafkajs**: Event consumption

## Future Enhancements

- [ ] Geolocation verification
- [ ] Photo capture during check-in
- [ ] Shift scheduling integration
- [ ] Automatic check-out (end of day)
- [ ] Break time tracking
- [ ] Attendance reports
- [ ] Overtime calculation
- [ ] Leave integration (skip check-in on leave days)

## Related Documentation

- [Database Schema](../database.md)
- [API Reference](../api-reference.md)
- [Microservices Overview](README.md)
