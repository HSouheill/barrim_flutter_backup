# Session Management Integration Guide

This guide explains how to use the updated session management features that integrate with your new backend endpoints.

## Backend Endpoints

The session management now integrates with these backend endpoints:

- `GET /api/auth/validate-token` - Validates JWT tokens
- `POST /api/auth/refresh-token` - Refreshes JWT tokens

## Key Features

### 1. Automatic Session Validation
The `SessionManager` automatically validates tokens with the server and handles session expiration.

### 2. Session Refresh
When a session is about to expire, the system can automatically refresh it using the refresh token.

### 3. Comprehensive Session Status
Get detailed information about the current session status including:
- Token validity
- Time until expiry
- User data
- Session warnings

## Usage Examples

### Basic Session Management

```dart
// Check if session is valid
bool isValid = await SessionManager.isSessionValid();

// Get session status
Map<String, dynamic> status = await SessionManager.getSessionStatus();

// Refresh session
SessionRefreshResult result = await SessionManager.refreshSession();
```

### UserProvider Integration

```dart
// Get user provider
final userProvider = Provider.of<UserProvider>(context, listen: false);

// Check and handle session (recommended)
bool sessionValid = await userProvider.checkAndHandleSession();

// Auto-refresh if needed
bool refreshed = await userProvider.autoRefreshSessionIfNeeded();

// Get detailed session info from server
Map<String, dynamic>? sessionInfo = await userProvider.getSessionInfo();
```

### App Lifecycle Management

The session management automatically handles:
- App resume: Validates and refreshes sessions
- Background/foreground transitions: Updates activity timestamps
- Session expiration: Clears invalid sessions

## Session Events

The system provides session events that you can listen to:

```dart
SessionManager.sessionEvents.listen((event) {
  switch (event) {
    case SessionEvent.sessionStarted:
      print('Session started');
      break;
    case SessionEvent.sessionRefreshed:
      print('Session refreshed');
      break;
    case SessionEvent.sessionWarning:
      print('Session expiring soon');
      break;
    case SessionEvent.sessionExpired:
      print('Session expired');
      break;
    case SessionEvent.sessionEnded:
      print('Session ended');
      break;
  }
});
```

## Error Handling

The session management includes comprehensive error handling:

- Network errors: Returns true for validation to avoid false negatives
- Server errors: Logs detailed error information
- Token errors: Automatically clears invalid sessions

## Configuration

Default session settings:
- Session timeout: 30 minutes
- Warning threshold: 5 minutes before expiry
- Background timeout: 24 hours

You can customize these in the `SessionManager` class.

## Debugging

Enable debug logging to see session management activity:

```dart
// Check session status
Map<String, dynamic> status = await SessionManager.getSessionStatus();
print('Session status: $status');

// Get detailed server info
Map<String, dynamic>? serverInfo = await SessionManager.getSessionInfoFromServer(token);
print('Server session info: $serverInfo');
```

## Integration with Your Backend

The session management expects these response formats:

### Validate Token Response
```json
{
  "status": 200,
  "message": "Token is valid",
  "data": {
    "valid": true,
    "user": {...},
    "expiresAt": "2024-01-01T12:00:00Z"
  }
}
```

### Refresh Token Response
```json
{
  "status": 200,
  "message": "Token refreshed successfully",
  "data": {
    "token": "new_jwt_token",
    "refreshToken": "new_refresh_token",
    "user": {...}
  }
}
```

## Best Practices

1. **Always use `checkAndHandleSession()`** when the app resumes
2. **Listen to session events** for better UX
3. **Handle session expiration gracefully** by redirecting to login
4. **Use the comprehensive session status** for debugging
5. **Test with different network conditions** to ensure reliability 