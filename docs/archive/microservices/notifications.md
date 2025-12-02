# Notifications Service

The Notifications service provides **multi-channel notification delivery** including push notifications (Firebase FCM), email, and SMS.

## Responsibilities

- Multi-channel notification delivery (Push, Email, SMS)
- Push notification token management
- Notification history and tracking
- User notification preferences
- Event-driven notification triggering

## Port & Database

- **HTTP Port**: 3005
- **Database**: `hiver_notifications` (PostgreSQL)
- **Health Endpoint**: `/notifications`

## Key Features

### Push Notifications
- Firebase Cloud Messaging (FCM) integration
- Multi-device support (multiple tokens per user)
- Platform-specific configurations (Android, iOS, Web)
- Automatic invalid token cleanup
- Rich notifications (title, body, image, custom data)

### Email Notifications
- SMTP integration via Nodemailer
- HTML email templates
- Development mode (MailHog)
- Production mode (any SMTP server)

### SMS Notifications
- Placeholder for SMS provider integration
- Ready for AWS SNS or Twilio

## Key Entities

### NotificationUserInfo
Local copy of user data needed for notifications.

**Fields**:
- id (synced from Users service)
- email, phone, companyId
- pushTokens[] (FCM device tokens)

### Notification
Record of sent notifications.

**Fields**:
- userId, type (EMAIL/SMS/PUSH)
- status (PENDING/SENT/FAILED/DELIVERED)
- subject, message, metadata (JSON)
- sentAt, deliveredAt, errorMessage

### NotificationTemplate
Reusable notification templates (future feature).

## API Endpoints

### Push Token Management

```
POST   /notifications/push-tokens              # Register device token
GET    /notifications/push-tokens              # List user's tokens
DELETE /notifications/push-tokens/:token       # Unregister token
```

### Notification History

```
GET    /notifications/notifications            # Get user's notifications
GET    /notifications/notifications/:id        # Get specific notification
```

### Health Check

```
GET    /notifications                          # Service health check
```

## Kafka Events

### Consumed Events

**Topic: `users.create`**
Creates `NotificationUserInfo` record and sends welcome email.

**Topic: `users.update`**
Updates `NotificationUserInfo` with new email/phone.

**Topic: `users.remove`**
Deletes `NotificationUserInfo` record.

**Topic: `notifications.send`**
```typescript
{
  userId: number;
  type: 'EMAIL' | 'SMS' | 'PUSH';
  subject?: string;
  message: string;
  metadata?: Record<string, any>;
}
```
Triggers notification delivery.

## Firebase Integration

### Setup

Requires environment variables:
```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@...
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

### Initialization
Firebase Admin SDK initializes on module startup:
- Validates credentials
- Creates app instance
- Warns if credentials missing (graceful degradation)

### Token Management

**Adding Tokens**:
- Mobile app gets FCM token from Firebase SDK
- App registers token via API
- Token stored in user's `pushTokens` array
- Supports multiple devices per user

**Invalid Token Handling**:
- Automatic detection during send
- Invalid tokens removed from database
- User not blocked from receiving future notifications

### Message Structure

```typescript
{
  notification: {
    title: "New Task",
    body: "You've been assigned a task",
    imageUrl: "https://..."
  },
  data: {
    taskId: "123",
    type: "TASK_ASSIGNED"
  },
  android: {
    priority: "high",
    notification: {
      sound: "default",
      clickAction: "FLUTTER_NOTIFICATION_CLICK"
    }
  },
  apns: {
    payload: {
      aps: {
        alert: { title: "...", body: "..." },
        badge: 1,
        sound: "default"
      }
    }
  }
}
```

## Email Integration

### Development (MailHog)
- SMTP server: `localhost:1025`
- Web UI: `http://localhost:8025`
- All emails caught, no real sending

### Production
Configure any SMTP server:
```env
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_SECURE=false
MAIL_USER=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_FROM="Hiver <noreply@hiver.com>"
```

### Email Templates
Located in `libs/mail/src/templates/`:
- Welcome email
- Password reset
- Leave approval
- Generic notifications

## Notification Flow

### Push Notification Flow
```
1. Event triggers (e.g., task assigned)
   Tasks Service → Kafka (notifications.send)

2. Notifications service consumes event
   Kafka → Notifications Service
   ├── Lookup user's push tokens
   ├── Build FCM message
   └── Send to Firebase

3. Firebase delivers to devices
   Firebase → User's device(s)

4. Log result
   Notifications Service → Database (status: SENT/FAILED)
```

### Email Flow
```
1. Event triggers (e.g., user created)
   Users Service → Kafka (users.create)

2. Notifications service consumes
   Kafka → Notifications Service
   ├── Get user email
   ├── Render email template
   └── Send via SMTP

3. Log result
   Notifications Service → Database
```

## Testing Push Notifications

### Without Firebase (API Only)
Test token management endpoints:
```bash
# Login
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -d '{"email":"alice.admin@acme.com","password":"ChangeMe123!"}' \
  -H "Content-Type: application/json" | jq -r '.accessToken')

# Register token
curl -X POST http://localhost:8000/notifications/push-tokens \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"token":"test-token","platform":"android"}'

# List tokens
curl http://localhost:8000/notifications/push-tokens \
  -H "Authorization: Bearer $TOKEN"
```

### With Firebase Configured
Send test notification via Kafka:
```bash
echo '{"userId":1,"type":"PUSH","subject":"Test","message":"Hello!"}' | \
  kcat -P -b localhost:9092 -t notifications.send
```

See [TESTING_PUSH_NOTIFICATIONS.md](../../TESTING_PUSH_NOTIFICATIONS.md) for detailed guide.

## Error Handling

### Firebase Not Initialized
Returns error: "Firebase is not initialized"
- Check environment variables
- Restart service after adding credentials

### No Push Tokens
Returns error: "User does not have any push notification tokens"
- User must register token first via API

### Invalid Tokens
- Automatically detected during send
- Removed from database
- User receives notification on valid devices only

## Mobile App Integration

### Flutter Example
```dart
// Get FCM token
final fcmToken = await FirebaseMessaging.instance.getToken();

// Register with backend
await http.post(
  Uri.parse('$apiUrl/notifications/push-tokens'),
  headers: {'Authorization': 'Bearer $token'},
  body: json.encode({'token': fcmToken, 'platform': 'android'}),
);

// Handle incoming notifications
FirebaseMessaging.onMessage.listen((message) {
  print('Notification: ${message.notification?.title}');
});
```

## Database Schema

### NotificationUserInfo
- 1-to-1 with User (id is user ID)
- Stores contact info and push tokens
- Auto-synced via Kafka events

### Notification
- Many-to-1 with NotificationUserInfo
- Records all sent notifications
- Indexed by userId, type, status

## Dependencies

- **firebase-admin**: Firebase Cloud Messaging SDK
- **@nestjs-modules/mailer**: Email service wrapper
- **nodemailer**: SMTP email sending
- **kafkajs**: Kafka client

## Related Documentation

- [Firebase Setup Guide](../../docs/FIREBASE_SETUP.md)
- [Testing Guide](../../TESTING_PUSH_NOTIFICATIONS.md)
- [API Reference](../../docs/NOTIFICATIONS_API.md)
