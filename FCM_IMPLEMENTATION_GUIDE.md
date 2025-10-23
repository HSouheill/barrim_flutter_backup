# Firebase Cloud Messaging (FCM) Implementation Guide

This guide explains how Firebase Cloud Messaging has been implemented in your Barrim Flutter app for push notifications.

## Overview

The FCM implementation includes:
- **FCM Service**: Core service for handling Firebase Cloud Messaging
- **Notification Service**: Enhanced to integrate with FCM
- **Notification Provider**: Updated to work with FCM tokens
- **Platform Configuration**: iOS and Android setup for FCM

## Files Added/Modified

### New Files
- `lib/src/services/fcm_service.dart` - Core FCM service
- `lib/src/examples/fcm_usage_example.dart` - Usage examples
- `FCM_IMPLEMENTATION_GUIDE.md` - This guide

### Modified Files
- `lib/main.dart` - Enabled Firebase initialization
- `lib/src/services/notification_service.dart` - Added FCM integration
- `lib/src/services/notification_provider.dart` - Added FCM token management
- `ios/Runner/AppDelegate.swift` - Added FCM configuration
- `android/app/build.gradle` - Added Firebase dependencies

## Features Implemented

### 1. FCM Token Management
- Automatic token generation and refresh
- Token storage and retrieval
- Server-side token registration

### 2. Notification Handling
- **Foreground notifications**: Displayed as local notifications
- **Background notifications**: Stored for later processing
- **Notification taps**: Handled with custom navigation logic

### 3. Topic Subscription
- Subscribe/unsubscribe to topics
- User-specific topic management
- General topic subscriptions

### 4. Platform Support
- **iOS**: Full FCM support with proper delegates
- **Android**: Firebase BOM integration with messaging

## Usage

### Basic Setup

The FCM service is automatically initialized when the app starts. No additional setup is required.

### Getting FCM Token

```dart
final notificationService = NotificationService();
String? fcmToken = notificationService.fcmToken;
print('FCM Token: $fcmToken');
```

### Sending Token to Server

```dart
await notificationService.sendTokenToServer(userId);
```

### Topic Subscription

```dart
// Subscribe to a topic
await notificationService.subscribeToTopic('general');

// Unsubscribe from a topic
await notificationService.unsubscribeFromTopic('general');
```

### Handling Background Notifications

```dart
// Get background notifications
final notifications = await notificationService.getBackgroundNotifications();

// Clear background notifications
await notificationService.clearBackgroundNotifications();
```

### Sending Local Notifications

```dart
await notificationService.showNotification(
  title: 'Test Notification',
  body: 'This is a test notification',
  payload: '{"type": "test"}',
);
```

## Integration with Existing Code

### User Authentication Integration

When a user logs in, the FCM token is automatically sent to the server:

```dart
// In your login logic
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
notificationProvider.initWebSocket(token, userId); // This also sends FCM token
```

### WebSocket Integration

The existing WebSocket implementation now includes FCM token management. When `initWebSocket` is called, it automatically:
1. Sends the FCM token to the server
2. Establishes the WebSocket connection
3. Handles both WebSocket and FCM notifications

## Notification Types

The implementation handles different notification types:

### 1. WebSocket Notifications
- Real-time notifications via WebSocket
- Displayed as local notifications
- Handled by existing `NotificationProvider`

### 2. FCM Push Notifications
- Background/foreground push notifications
- Stored when app is in background
- Displayed when app is in foreground

### 3. Local Notifications
- Programmatically generated notifications
- Used for testing and internal app notifications

## Server-Side Integration

To complete the FCM implementation, you need to:

### 1. Store FCM Tokens
When a user logs in, store their FCM token in your database:

```javascript
// Example API endpoint
app.post('/api/users/:userId/fcm-token', (req, res) => {
  const { userId } = req.params;
  const { fcmToken } = req.body;
  
  // Store token in database
  User.findByIdAndUpdate(userId, { fcmToken }, (err, user) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true });
  });
});
```

### 2. Send Push Notifications
Use Firebase Admin SDK to send notifications:

```javascript
const admin = require('firebase-admin');

// Send to specific user
async function sendToUser(userId, title, body, data = {}) {
  const user = await User.findById(userId);
  if (!user.fcmToken) return;
  
  const message = {
    token: user.fcmToken,
    notification: { title, body },
    data: data
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
  } catch (error) {
    console.log('Error sending message:', error);
  }
}

// Send to topic
async function sendToTopic(topic, title, body, data = {}) {
  const message = {
    topic: topic,
    notification: { title, body },
    data: data
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
  } catch (error) {
    console.log('Error sending message:', error);
  }
}
```

## Testing

### 1. Test Local Notifications
Use the example widget to test local notifications:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => FCMUsageExample()),
);
```

### 2. Test FCM Tokens
Check the console logs for FCM token generation and refresh.

### 3. Test Background Notifications
1. Send a notification while app is in background
2. Open the app and check background notifications

## Troubleshooting

### Common Issues

1. **FCM Token Not Generated**
   - Check Firebase configuration
   - Verify Google Services files are properly configured
   - Check console logs for errors

2. **Notifications Not Received**
   - Verify FCM token is sent to server
   - Check notification permissions
   - Verify server-side FCM implementation

3. **iOS Notifications Not Working**
   - Check APNs certificates
   - Verify iOS notification permissions
   - Check AppDelegate configuration

4. **Android Notifications Not Working**
   - Verify google-services.json is in android/app/
   - Check Android notification permissions
   - Verify Firebase dependencies

### Debug Logs

Enable debug logging by checking console output for:
- FCM token generation
- Notification reception
- Token refresh events
- Error messages

## Security Considerations

1. **Token Storage**: FCM tokens are stored securely and refreshed automatically
2. **Server Validation**: Always validate FCM tokens on the server side
3. **Permission Handling**: Request notification permissions appropriately
4. **Data Privacy**: Handle notification data according to privacy regulations

## Next Steps

1. **Server Integration**: Implement server-side FCM token storage and notification sending
2. **Notification Categories**: Add support for different notification categories
3. **Rich Notifications**: Implement rich notification layouts
4. **Analytics**: Add notification analytics and tracking
5. **A/B Testing**: Implement notification A/B testing

## Support

For issues or questions regarding the FCM implementation:
1. Check the console logs for error messages
2. Verify Firebase configuration
3. Test with the provided example widget
4. Review this documentation for troubleshooting steps
