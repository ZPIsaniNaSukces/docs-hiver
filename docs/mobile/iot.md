# IoT Integration

The HiveR mobile app integrates with IoT devices to enable automated presence tracking and seamless office interactions.

## Supported IoT Devices

### Bluetooth Beacons
- Office entrance beacons
- Department-specific beacons
- Meeting room beacons

### NFC Tags
- Check-in terminals
- Door access points
- Desk stations

### QR Codes
- Quick check-in posters
- Visitor management
- Equipment check-out

## Communication Flow

### Device Discovery
1. App scans for nearby IoT devices
2. Matches device IDs with registered office devices
3. Establishes secure connection
4. Ready for interaction

### Check-In Process
1. IoT device detects employee's mobile app
2. Device sends check-in prompt to app
3. App displays confirmation request
4. Employee confirms (or auto-confirms)
5. App sends check-in event to backend
6. Presence recorded in system

### Device Response
1. Employee's action triggers device response
2. Visual/audio feedback from IoT device
3. Backend confirms action
4. Mobile app displays confirmation

## Security

### Authentication
- Device-to-app authentication via secure tokens
- Encrypted communication channels
- Regular security key rotation

### Privacy
- Location data handling
- Bluetooth permission management
- User consent for device tracking

## Device Management

### Pairing Devices
1. Admin registers IoT device in system
2. Device receives unique identifier
3. Employees can discover and pair with device
4. Permissions set based on employee role

### Trusted Devices
- Save frequently used devices
- Auto-connect to trusted devices
- Manage trusted device list

## Configuration

### App Settings
- Enable/disable IoT features
- Bluetooth/NFC permissions
- Auto check-in on device detection
- Preferred devices

### Backend Configuration
- Register office IoT devices
- Set device locations
- Configure check-in zones
- Device-specific rules

## Troubleshooting

**Device Not Detected**:
- Check Bluetooth/NFC is enabled
- Ensure device is in range
- Verify device is registered in system

**Failed Check-In**:
- Check network connectivity
- Verify device battery
- Ensure app has proper permissions

**Multiple Devices Detected**:
- App prioritizes closest/strongest signal
- User can manually select device
- Trusted device takes precedence

---

Return to: [Mobile Overview](overview.md)
