# FCM Token Refresh Implementation

## Summary

This implementation ensures that FCM tokens are automatically sent to the backend in multiple scenarios to ensure notifications work reliably, even when the app is closed or the device restarts.

## Changes Made

### 1. **Splash Screen (`lib/src/features/authentication/screens/splash_screen.dart`)**

**What was added:**
- Import of `NotificationProvider` to access FCM services
- New method `_sendFCMTokenIfNeeded()` that sends FCM token when app starts if user is already logged in
- Call to send FCM token before navigation in `_navigateAfterSplash()`

**Key behavior:**
```dart
// When app starts and detects user is logged in (persistent JWT)
if (userProvider.isLoggedIn && userProvider.user != null) {
  await _sendFCMTokenIfNeeded(userProvider);
}
```

This ensures FCM token is sent **every time the app starts** if the user is logged in, solving the problem where notifications wouldn't work after app restart.

### 2. **FCM Service (`lib/src/services/fcm_service.dart`)**

**What was added:**
- Token refresh callback mechanism
- `onTokenRefresh()` method that allows other services to register callbacks
- `_onTokenRefreshCallback` variable to store the callback function

**Key behavior:**
```dart
// When FCM SDK refreshes the token automatically
_firebaseMessaging.onTokenRefresh.listen((newToken) {
  _fcmToken = newToken;
  _onTokenRefresh(newToken); // Trigger registered callback
});
```

This ensures the refreshed token is automatically sent to the server.

### 3. **Notification Provider (`lib/src/services/notification_provider.dart`)**

**What was added:**
- `_userType` field to track user type (user, serviceProvider, etc.)
- `_setupTokenRefreshHandler()` method that registers a callback for token refresh
- Updated `initWebSocket()` to accept optional `userType` parameter
- Token refresh handler that automatically sends refreshed tokens to the server

**Key behavior:**
```dart
void _setupTokenRefreshHandler() {
  final fcmService = FCMService();
  fcmService.onTokenRefresh((newToken) {
    // Automatically send refreshed token to server
    if (_userType == 'serviceProvider') {
      sendServiceProviderFCMTokenToServer();
    } else if (_userId != null) {
      sendFCMTokenToServer(_userId!);
    }
  });
}
```

This ensures **FCM token refresh** is handled automatically throughout the app lifecycle.

### 4. **Main App (`lib/main.dart`)**

**What was updated:**
- All three calls to `initWebSocket()` now pass `userType: userProvider.user!.userType`
- This allows the NotificationProvider to store user type for token refresh handling

**Before:**
```dart
notificationProvider.initWebSocket(token, userId);
```

**After:**
```dart
notificationProvider.initWebSocket(token, userId, userType: userProvider.user!.userType);
```

## How It Works

### Scenario 1: App Starts (User Already Logged In)
```
1. User opens app
2. Splash screen detects JWT token in storage
3. User is considered logged in
4. FCM token is automatically sent to backend
5. Notifications now work even when app is closed
```

### Scenario 2: User Logs In
```
1. User enters credentials and logs in
2. Login page sends FCM token (already implemented)
3. WebSocket is initialized with user type
4. Notifications start working immediately
```

### Scenario 3: FCM Token Refreshes
```
1. Firebase SDK automatically refreshes FCM token (happens periodically)
2. Token refresh listener in FCM service fires
3. NotificationProvider callback is triggered
4. Refreshed token is automatically sent to backend
5. Notifications continue working without interruption
```

## API Endpoints Used

### For Service Providers:
```http
POST https://barrim.online/api/service-provider/fcm-token
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "fcmToken": "YOUR_FCM_TOKEN_HERE"
}
```

### For Regular Users:
```http
POST https://barrim.online/api/users/fcm-token
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "fcmToken": "YOUR_FCM_TOKEN_HERE"
}
```

## Testing

### 1. Test App Restart
```
1. Log in to app
2. Close app completely
3. Restart app
4. Check logs for "Sending FCM token on app start"
5. Verify FCM token is sent to backend
```

### 2. Test Token Refresh
```
1. Log in to app
2. Monitor logs for token refresh messages
3. When Firebase SDK refreshes token, you should see:
   - "FCM Token refreshed"
   - "Sending refreshed FCM token to server"
```

### 3. Test Notifications When App Is Closed
```
1. Log in to app
2. Close app completely
3. Send a test notification from backend
4. Notification should appear in device notification tray
```

## Troubleshooting

### Problem: FCM token not sent on app start
**Solution:** Check that splash screen has access to UserProvider and NotificationProvider

### Problem: Token refresh not working
**Solution:** Verify that `_setupTokenRefreshHandler()` is called in NotificationProvider constructor

### Problem: Notifications not received when app is closed
**Solution:** Check that:
1. FCM token is stored in database (query MongoDB)
2. Token was sent on app start (check logs)
3. Firebase Admin SDK is configured on backend
4. Device has internet connection

## Files Modified

1. `lib/src/features/authentication/screens/splash_screen.dart`
2. `lib/src/services/fcm_service.dart`
3. `lib/src/services/notification_provider.dart`
4. `lib/main.dart`
5. `lib/src/examples/fcm_usage_example.dart`

## Benefits

✅ **Notifications work when app is closed** - FCM token is sent every app start
✅ **Automatic token refresh** - No manual intervention needed
✅ **Seamless user experience** - Users don't need to log in again for notifications to work
✅ **Reliable notification delivery** - Token is always up-to-date on backend
✅ **Supports multiple scenarios** - Handles app start, login, and token refresh

## Important Notes

1. **The system does NOT automatically detect if a device belongs to a service provider** - The app MUST send the FCM token to the backend when the service provider logs in.

2. **FCM tokens can expire** - The implementation automatically handles token refresh and resends to the server.

3. **Multiple devices** - Currently, the system stores one token per user (last device wins).

4. **JWT tokens don't expire** - This is why we send FCM tokens on app start, not just on login.

## Next Steps for Multi-Device Support

If you want service providers to receive notifications on multiple devices, modify the backend to:
1. Store FCM tokens as an array: `fcmTokens: [string]`
2. Send notifications to all tokens in the array
3. Handle token refresh and cleanup of invalid tokens

