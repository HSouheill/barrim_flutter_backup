import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Session event types
enum SessionEvent {
  sessionStarted,
  sessionRefreshed,
  sessionWarning,
  sessionExpired,
  sessionEnded,
}

// Session refresh result
class SessionRefreshResult {
  final bool success;
  final String? newToken;
  final String? newRefreshToken;
  final String? error;
  
  SessionRefreshResult({
    required this.success,
    this.newToken,
    this.newRefreshToken,
    this.error,
  });
}

// Session exception
class SessionException implements Exception {
  final String message;
  SessionException(this.message);
  
  @override
  String toString() => 'SessionException: $message';
}

class SessionManager {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _lastActivityKey = 'last_activity';
  static const String _sessionTimeoutKey = 'session_timeout';
  static const String _refreshTokenKey = 'refresh_token';
  
  // Default session timeout (30 minutes)
  static const Duration defaultSessionTimeout = Duration(minutes: 30);
  
  // Session warning threshold (5 minutes before expiry)
  static const Duration sessionWarningThreshold = Duration(minutes: 5);
  
  // Background activity timeout (24 hours)
  static const Duration backgroundTimeout = Duration(hours: 24);
  
  static Timer? _sessionTimer;
  static Timer? _backgroundTimer;
  static StreamController<SessionEvent>? _sessionEventController;
  
  // Initialize session manager
  static Future<void> initialize() async {
    _sessionEventController = StreamController<SessionEvent>.broadcast();
    await _startSessionMonitoring();
  }
  
  // Get session event stream
  static Stream<SessionEvent> get sessionEvents {
    _sessionEventController ??= StreamController<SessionEvent>.broadcast();
    return _sessionEventController!.stream;
  }
  
  // Save session data
  static Future<void> saveSession({
    required String token,
    required String userData,
    String? refreshToken,
    Duration? customTimeout,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final timeout = customTimeout ?? defaultSessionTimeout;
      
      await Future.wait([
        prefs.setString(_tokenKey, token),
        prefs.setString(_userKey, userData),
        prefs.setInt(_lastActivityKey, now.millisecondsSinceEpoch),
        prefs.setInt(_sessionTimeoutKey, timeout.inMilliseconds),
        if (refreshToken != null) prefs.setString(_refreshTokenKey, refreshToken),
      ]);
      
      await _startSessionMonitoring();
      _notifySessionEvent(SessionEvent.sessionStarted);
      
      print('Session saved successfully with ${timeout.inMinutes}min timeout');
    } catch (e) {
      print('Error saving session: $e');
      throw SessionException('Failed to save session data');
    }
  }
  
  // Get stored token
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }
  
  // Get stored user data
  static Future<String?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userKey);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  // Get refresh token
  static Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } catch (e) {
      print('Error getting refresh token: $e');
      return null;
    }
  }
  
  // Check if session is valid
  static Future<bool> isSessionValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString(_tokenKey);
      final lastActivityMs = prefs.getInt(_lastActivityKey);
      final timeoutMs = prefs.getInt(_sessionTimeoutKey);
      
      if (token == null || lastActivityMs == null || timeoutMs == null) {
        print('Session validation failed: Missing session data');
        return false;
      }
      
      final lastActivity = DateTime.fromMillisecondsSinceEpoch(lastActivityMs);
      final timeout = Duration(milliseconds: timeoutMs);
      final expiryTime = lastActivity.add(timeout);
      final now = DateTime.now();
      
      if (now.isAfter(expiryTime)) {
        print('Session expired: Last activity was ${now.difference(lastActivity).inMinutes} minutes ago');
        return false;
      }
      
      // Additional server-side validation
      return await _validateTokenWithServer(token);
    } catch (e) {
      print('Error validating session: $e');
      return false;
    }
  }
  
  // Validate token with server
  static Future<bool> _validateTokenWithServer(String token) async {
    try {
      print('Validating token with server...');
      final response = await http.get(
        Uri.parse('https://barrim.online/api/auth/validate-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      print('Token validation response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseData = data['data'] ?? {};
        final isValid = responseData['valid'] == true;
        print('Token validation result: $isValid');
        return isValid;
      } else if (response.statusCode == 401) {
        print('Token validation failed: Unauthorized');
        return false;
      } else {
        print('Token validation failed: HTTP ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error validating token with server: $e');
      // Return true for network errors to avoid false negatives
      return true;
    }
  }
  
  // Update last activity timestamp
  static Future<void> updateLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setInt(_lastActivityKey, now.millisecondsSinceEpoch);
      
      // Restart session monitoring with updated activity
      await _startSessionMonitoring();
      
      print('Last activity updated: ${now.toString()}');
    } catch (e) {
      print('Error updating last activity: $e');
    }
  }
  
  // Get time remaining until session expires
  static Future<Duration?> getTimeUntilExpiry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final lastActivityMs = prefs.getInt(_lastActivityKey);
      final timeoutMs = prefs.getInt(_sessionTimeoutKey);
      
      if (lastActivityMs == null || timeoutMs == null) {
        return null;
      }
      
      final lastActivity = DateTime.fromMillisecondsSinceEpoch(lastActivityMs);
      final timeout = Duration(milliseconds: timeoutMs);
      final expiryTime = lastActivity.add(timeout);
      final now = DateTime.now();
      
      if (now.isAfter(expiryTime)) {
        return Duration.zero;
      }
      
      return expiryTime.difference(now);
    } catch (e) {
      print('Error getting time until expiry: $e');
      return null;
    }
  }
  
  // Refresh session using refresh token
  static Future<SessionRefreshResult> refreshSession() async {
    try {
      final token = await getToken();
      if (token == null) {
        return SessionRefreshResult(success: false, error: 'No token available');
      }
      
      print('Refreshing session with token...');
      final response = await http.post(
        Uri.parse('https://barrim.online/api/auth/refresh-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      print('Session refresh response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseData = data['data'] ?? {};
        final newToken = responseData['token'];
        final newRefreshToken = responseData['refreshToken'];
        final userData = responseData['user'];
        
        print('Session refresh successful: newToken=${newToken != null}, newRefreshToken=${newRefreshToken != null}');
        
        if (newToken != null) {
          // Update stored tokens
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, newToken);
          if (newRefreshToken != null) {
            await prefs.setString(_refreshTokenKey, newRefreshToken);
          }
          if (userData != null) {
            await prefs.setString(_userKey, json.encode(userData));
          }
          
          // Update last activity
          await updateLastActivity();
          
          _notifySessionEvent(SessionEvent.sessionRefreshed);
          
          return SessionRefreshResult(
            success: true,
            newToken: newToken,
            newRefreshToken: newRefreshToken,
          );
        }
      }
      
      print('Session refresh failed: HTTP ${response.statusCode}');
      print('Response body: ${response.body}');
      
      return SessionRefreshResult(
        success: false,
        error: 'Failed to refresh session: HTTP ${response.statusCode}',
      );
    } catch (e) {
      print('Error refreshing session: $e');
      return SessionRefreshResult(success: false, error: e.toString());
    }
  }
  
  // Clear session data
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await Future.wait([
        prefs.remove(_tokenKey),
        prefs.remove(_userKey),
        prefs.remove(_lastActivityKey),
        prefs.remove(_sessionTimeoutKey),
        prefs.remove(_refreshTokenKey),
      ]);
      
      _stopSessionMonitoring();
      _notifySessionEvent(SessionEvent.sessionEnded);
      
      print('Session cleared successfully');
    } catch (e) {
      print('Error clearing session: $e');
    }
  }
  
  // Start session monitoring
  static Future<void> _startSessionMonitoring() async {
    _stopSessionMonitoring();
    
    final timeUntilExpiry = await getTimeUntilExpiry();
    if (timeUntilExpiry == null || timeUntilExpiry <= Duration.zero) {
      return;
    }
    
    // Set timer for session warning
    final warningTime = timeUntilExpiry - sessionWarningThreshold;
    if (warningTime > Duration.zero) {
      _sessionTimer = Timer(warningTime, () {
        _notifySessionEvent(SessionEvent.sessionWarning);
      });
    }
    
    // Set timer for session expiry
    _backgroundTimer = Timer(timeUntilExpiry, () {
      _notifySessionEvent(SessionEvent.sessionExpired);
    });
  }
  
  // Stop session monitoring
  static void _stopSessionMonitoring() {
    _sessionTimer?.cancel();
    _backgroundTimer?.cancel();
    _sessionTimer = null;
    _backgroundTimer = null;
  }
  
  // Notify session event
  static void _notifySessionEvent(SessionEvent event) {
    if (_sessionEventController != null && !_sessionEventController!.isClosed) {
      _sessionEventController!.add(event);
    }
  }
  
  // Dispose resources
  static void dispose() {
    _stopSessionMonitoring();
    _sessionEventController?.close();
    _sessionEventController = null;
  }
  
  // Get session info for debugging
  static Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final lastActivityMs = prefs.getInt(_lastActivityKey);
      final timeoutMs = prefs.getInt(_sessionTimeoutKey);
      
      final lastActivity = lastActivityMs != null 
          ? DateTime.fromMillisecondsSinceEpoch(lastActivityMs)
          : null;
      
      final timeout = timeoutMs != null 
          ? Duration(milliseconds: timeoutMs)
          : null;
      
      final timeUntilExpiry = await getTimeUntilExpiry();
      
      return {
        'hasToken': token != null,
        'lastActivity': lastActivity?.toIso8601String(),
        'timeout': timeout?.inMinutes,
        'timeUntilExpiry': timeUntilExpiry?.inMinutes,
        'isValid': await isSessionValid(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Get detailed session info from server
  static Future<Map<String, dynamic>?> getSessionInfoFromServer(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://barrim.online/api/auth/validate-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseData = data['data'] ?? {};
        
        if (responseData['valid'] == true) {
          return {
            'valid': true,
            'user': responseData['user'],
            'expiresAt': responseData['expiresAt'],
            'message': responseData['message'] ?? 'Token is valid',
          };
        } else {
          return {
            'valid': false,
            'message': responseData['message'] ?? 'Token is invalid',
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'valid': false,
          'message': 'Token is unauthorized',
        };
      } else {
        return {
          'valid': false,
          'message': 'Server error: HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error getting session info from server: $e');
      return null;
    }
  }

  // Check if session is about to expire (within warning threshold)
  static Future<bool> isSessionExpiringSoon() async {
    try {
      final timeUntilExpiry = await getTimeUntilExpiry();
      if (timeUntilExpiry == null) return false;
      
      return timeUntilExpiry <= sessionWarningThreshold;
    } catch (e) {
      print('Error checking if session is expiring soon: $e');
      return false;
    }
  }

  // Get comprehensive session status
  static Future<Map<String, dynamic>> getSessionStatus() async {
    try {
      final token = await getToken();
      final userData = await getUserData();
      final isValid = await isSessionValid();
      final timeUntilExpiry = await getTimeUntilExpiry();
      final isExpiringSoon = await isSessionExpiringSoon();
      
      return {
        'hasToken': token != null,
        'hasUserData': userData != null,
        'isValid': isValid,
        'timeUntilExpiry': timeUntilExpiry?.inMinutes,
        'isExpiringSoon': isExpiringSoon,
        'sessionTimeout': defaultSessionTimeout.inMinutes,
        'warningThreshold': sessionWarningThreshold.inMinutes,
      };
    } catch (e) {
      print('Error getting session status: $e');
      return {'error': e.toString()};
    }
  }
} 