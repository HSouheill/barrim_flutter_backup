import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:barrim/src/utils/env_config.dart';

// Session event types
enum SessionEvent {
  sessionStarted,
  sessionRefreshed,
  sessionWarning,
  sessionExpired,
  sessionEnded,
  sessionRestored,
}

/// Extended session service for long-term session persistence
/// Supports sessions that can last for months or years
class ExtendedSessionService {
  static const String _tokenKey = 'extended_auth_token';
  static const String _userKey = 'extended_user_data';
  static const String _lastActivityKey = 'extended_last_activity';
  static const String _sessionTimeoutKey = 'extended_session_timeout';
  static const String _refreshTokenKey = 'extended_refresh_token';
  static const String _lastVisitedPageKey = 'extended_last_visited_page';
  static const String _lastPageDataKey = 'extended_last_page_data';
  static const String _sessionCreatedKey = 'extended_session_created';
  static const String _rememberMeKey = 'extended_remember_me';
  
  // Secure storage configuration
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // Extended session timeout (1 year for remember me)
  static const Duration extendedSessionTimeout = Duration(days: 365);
  
  // Regular session timeout (30 days for normal sessions)
  static const Duration regularSessionTimeout = Duration(days: 30);
  
  // Session warning threshold (7 days before expiry)
  static const Duration sessionWarningThreshold = Duration(days: 7);
  
  // Background activity timeout (1 year)
  static const Duration backgroundTimeout = Duration(days: 365);
  
  static Timer? _sessionTimer;
  static Timer? _backgroundTimer;
  static StreamController<SessionEvent>? _sessionEventController;
  
  // Initialize extended session service
  static Future<void> initialize() async {
    _sessionEventController = StreamController<SessionEvent>.broadcast();
    await _startSessionMonitoring();
  }
  
  // Get session event stream
  static Stream<SessionEvent> get sessionEvents {
    _sessionEventController ??= StreamController<SessionEvent>.broadcast();
    return _sessionEventController!.stream;
  }
  
  // Save extended session data
  static Future<void> saveExtendedSession({
    required String token,
    required String userData,
    String? refreshToken,
    String? lastVisitedPage,
    Map<String, dynamic>? lastPageData,
    bool rememberMe = false,
    Duration? customTimeout,
  }) async {
    try {
      // Input validation
      if (token.trim().isEmpty) {
        throw Exception('Token cannot be empty');
      }
      if (userData.trim().isEmpty) {
        throw Exception('User data cannot be empty');
      }
      
      // Basic JWT format validation
      if (!token.contains('.')) {
        throw Exception('Invalid token format');
      }
      
      final now = DateTime.now();
      final timeout = rememberMe ? extendedSessionTimeout : (customTimeout ?? regularSessionTimeout);
      
      await Future.wait([
        _storage.write(key: _tokenKey, value: token.trim()),
        _storage.write(key: _userKey, value: userData.trim()),
        _storage.write(key: _lastActivityKey, value: now.millisecondsSinceEpoch.toString()),
        _storage.write(key: _sessionTimeoutKey, value: timeout.inMilliseconds.toString()),
        _storage.write(key: _sessionCreatedKey, value: now.millisecondsSinceEpoch.toString()),
        _storage.write(key: _rememberMeKey, value: rememberMe.toString()),
        if (refreshToken != null) _storage.write(key: _refreshTokenKey, value: refreshToken.trim()),
        if (lastVisitedPage != null) _storage.write(key: _lastVisitedPageKey, value: lastVisitedPage),
        if (lastPageData != null) _storage.write(key: _lastPageDataKey, value: json.encode(lastPageData)),
      ]);
      
      await _startSessionMonitoring();
      _notifySessionEvent(SessionEvent.sessionStarted);
      
      if (!kReleaseMode) {
        print('Extended session saved successfully with ${timeout.inDays} days timeout (Remember Me: $rememberMe)');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error saving extended session: $e');
      }
      throw Exception('Failed to save extended session data');
    }
  }
  
  // Get stored token
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting extended token: $e');
      }
      return null;
    }
  }
  
  // Get stored user data
  static Future<String?> getUserData() async {
    try {
      return await _storage.read(key: _userKey);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting extended user data: $e');
      }
      return null;
    }
  }
  
  // Get refresh token
  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting extended refresh token: $e');
      }
      return null;
    }
  }
  
  // Get last visited page
  static Future<String?> getLastVisitedPage() async {
    try {
      return await _storage.read(key: _lastVisitedPageKey);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting last visited page: $e');
      }
      return null;
    }
  }
  
  // Get last page data
  static Future<Map<String, dynamic>?> getLastPageData() async {
    try {
      final data = await _storage.read(key: _lastPageDataKey);
      if (data != null) {
        return json.decode(data);
      }
      return null;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting last page data: $e');
      }
      return null;
    }
  }
  
  // Check if remember me is enabled
  static Future<bool> isRememberMeEnabled() async {
    try {
      final rememberMe = await _storage.read(key: _rememberMeKey);
      return rememberMe == 'true';
    } catch (e) {
      if (!kReleaseMode) {
        print('Error checking remember me status: $e');
      }
      return false;
    }
  }
  
  // Check if session is valid (local validation only by default)
  static Future<bool> isSessionValid({bool validateWithServer = false}) async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final lastActivityMsStr = await _storage.read(key: _lastActivityKey);
      final timeoutMsStr = await _storage.read(key: _sessionTimeoutKey);
      final rememberMe = await isRememberMeEnabled();
      
      if (token == null || lastActivityMsStr == null || timeoutMsStr == null) {
        if (!kReleaseMode) {
          print('Extended session validation failed: Missing session data');
        }
        return false;
      }
      
      final lastActivityMs = int.tryParse(lastActivityMsStr);
      final timeoutMs = int.tryParse(timeoutMsStr);
      
      if (lastActivityMs == null || timeoutMs == null) {
        if (!kReleaseMode) {
          print('Extended session validation failed: Invalid session data format');
        }
        return false;
      }
      
      final lastActivity = DateTime.fromMillisecondsSinceEpoch(lastActivityMs);
      final timeout = Duration(milliseconds: timeoutMs);
      final expiryTime = lastActivity.add(timeout);
      final now = DateTime.now();
      
      if (now.isAfter(expiryTime)) {
        if (!kReleaseMode) {
          print('Extended session expired: Last activity was ${now.difference(lastActivity).inDays} days ago (Remember Me: $rememberMe)');
        }
        return false;
      }
      
      // Only validate with server if requested and not during startup
      if (validateWithServer) {
        return await _validateTokenWithServer(token);
      }
      
      return true; // Local validation passed
    } catch (e) {
      if (!kReleaseMode) {
        print('Error validating extended session: $e');
      }
      return false;
    }
  }
  
  // Validate token with server
  static Future<bool> _validateTokenWithServer(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${EnvConfig.apiBaseUrl}/api/auth/validate-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'User-Agent': 'Barrim-Mobile-App/1.0',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseData = data['data'] ?? {};
        final isValid = responseData['valid'] == true;
        if (!kReleaseMode) {
          print('Extended token validation successful: $isValid');
        }
        return isValid;
      } else if (response.statusCode == 401) {
        if (!kReleaseMode) {
          print('Extended token validation failed: Unauthorized (401)');
        }
        return false;
      } else if (response.statusCode >= 500) {
        // Server errors (5xx) - assume token is still valid, server issue
        if (!kReleaseMode) {
          print('Server error during extended token validation (${response.statusCode}) - assuming token is valid');
        }
        return true;
      } else {
        // Other client errors (4xx except 401) - assume token is still valid
        if (!kReleaseMode) {
          print('Client error during extended token validation (${response.statusCode}) - assuming token is valid');
        }
        return true;
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error validating extended token with server: $e');
      }
      // Return true for network errors to avoid false negatives
      return true;
    }
  }
  
  // Update last activity timestamp
  static Future<void> updateLastActivity() async {
    try {
      final now = DateTime.now();
      await _storage.write(key: _lastActivityKey, value: now.millisecondsSinceEpoch.toString());
      
      // Restart session monitoring with updated activity
      await _startSessionMonitoring();
      
      if (!kReleaseMode) {
        print('Extended session last activity updated: ${now.toString()}');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error updating extended session last activity: $e');
      }
    }
  }
  
  // Save last visited page
  static Future<void> saveLastVisitedPage(String pageName, {
    Map<String, dynamic>? pageData,
    String? routePath,
    Map<String, dynamic>? routeArguments,
  }) async {
    try {
      final lastPageData = {
        'pageName': pageName,
        'pageData': pageData ?? {},
        'routePath': routePath ?? pageName,
        'routeArguments': routeArguments ?? {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await Future.wait([
        _storage.write(key: _lastVisitedPageKey, value: pageName),
        _storage.write(key: _lastPageDataKey, value: json.encode(lastPageData)),
      ]);
      
      if (!kReleaseMode) {
        print('Extended session last visited page saved: $pageName');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error saving extended session last visited page: $e');
      }
    }
  }
  
  // Get time remaining until session expires
  static Future<Duration?> getTimeUntilExpiry() async {
    try {
      final lastActivityMsStr = await _storage.read(key: _lastActivityKey);
      final timeoutMsStr = await _storage.read(key: _sessionTimeoutKey);
      
      if (lastActivityMsStr == null || timeoutMsStr == null) {
        return null;
      }
      
      final lastActivityMs = int.tryParse(lastActivityMsStr);
      final timeoutMs = int.tryParse(timeoutMsStr);
      
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
      if (!kReleaseMode) {
        print('Error getting extended session time until expiry: $e');
      }
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
      
      print('Refreshing extended session with token...');
      final response = await http.post(
        Uri.parse('${EnvConfig.apiBaseUrl}/api/auth/refresh-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      print('Extended session refresh response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseData = data['data'] ?? {};
        final newToken = responseData['token'];
        final newRefreshToken = responseData['refreshToken'];
        final userData = responseData['user'];
        
        print('Extended session refresh successful: newToken=${newToken != null}, newRefreshToken=${newRefreshToken != null}');
        
        if (newToken != null) {
          // Update stored tokens
          await _storage.write(key: _tokenKey, value: newToken);
          if (newRefreshToken != null) {
            await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
          }
          if (userData != null) {
            await _storage.write(key: _userKey, value: json.encode(userData));
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
      
      print('Extended session refresh failed: HTTP ${response.statusCode}');
      print('Response body: ${response.body}');
      
      // Handle specific error cases
      if (response.statusCode == 401) {
        final responseData = json.decode(response.body);
        final errorMessage = responseData['message'] ?? 'User account is inactive';
        print('Extended session refresh failed: $errorMessage');
        
        // If account is inactive, clear the session
        if (errorMessage.toLowerCase().contains('inactive')) {
          await clearSession();
          return SessionRefreshResult(
            success: false,
            error: 'Account is inactive. Please contact support.',
            shouldLogout: true,
          );
        }
        
        return SessionRefreshResult(
          success: false,
          error: 'Authentication failed: $errorMessage',
          shouldLogout: true,
        );
      }
      
      return SessionRefreshResult(
        success: false,
        error: 'Failed to refresh extended session: HTTP ${response.statusCode}',
      );
    } catch (e) {
      print('Error refreshing extended session: $e');
      return SessionRefreshResult(success: false, error: e.toString());
    }
  }
  
  // Clear extended session data
  static Future<void> clearSession() async {
    try {
      await Future.wait([
        _storage.delete(key: _tokenKey),
        _storage.delete(key: _userKey),
        _storage.delete(key: _lastActivityKey),
        _storage.delete(key: _sessionTimeoutKey),
        _storage.delete(key: _refreshTokenKey),
        _storage.delete(key: _lastVisitedPageKey),
        _storage.delete(key: _lastPageDataKey),
        _storage.delete(key: _sessionCreatedKey),
        _storage.delete(key: _rememberMeKey),
      ]);
      
      _stopSessionMonitoring();
      _notifySessionEvent(SessionEvent.sessionEnded);
      
      if (!kReleaseMode) {
        print('Extended session cleared successfully');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error clearing extended session: $e');
      }
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
  
  // Get comprehensive session status
  static Future<Map<String, dynamic>> getSessionStatus() async {
    try {
      final token = await getToken();
      final userData = await getUserData();
      final lastVisitedPage = await getLastVisitedPage();
      final lastPageData = await getLastPageData();
      final isValid = await isSessionValid();
      final timeUntilExpiry = await getTimeUntilExpiry();
      final rememberMe = await isRememberMeEnabled();
      
      return {
        'hasToken': token != null,
        'hasUserData': userData != null,
        'hasLastVisitedPage': lastVisitedPage != null,
        'hasLastPageData': lastPageData != null,
        'isValid': isValid,
        'timeUntilExpiry': timeUntilExpiry?.inDays,
        'rememberMe': rememberMe,
        'sessionTimeout': rememberMe ? extendedSessionTimeout.inDays : regularSessionTimeout.inDays,
        'warningThreshold': sessionWarningThreshold.inDays,
      };
    } catch (e) {
      print('Error getting extended session status: $e');
      return {'error': e.toString()};
    }
  }
  
  // Check if the saved route is still valid (extended validity)
  static Future<bool> isSavedRouteValid({Duration maxAge = const Duration(days: 365)}) async {
    try {
      final lastPageData = await getLastPageData();
      if (lastPageData == null) return false;
      
      final timestamp = lastPageData['timestamp'] as int?;
      if (timestamp == null) return false;
      
      final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final age = now.difference(savedTime);
      
      return age <= maxAge;
    } catch (e) {
      print('Error checking if saved route is valid: $e');
      return false;
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
  
  // Get current route information for restoration
  static Future<Map<String, dynamic>?> getCurrentRouteInfo() async {
    try {
      final lastPageData = await getLastPageData();
      if (lastPageData == null) return null;
      
      return {
        'pageName': lastPageData['pageName'],
        'routePath': lastPageData['routePath'],
        'pageData': lastPageData['pageData'],
        'routeArguments': lastPageData['routeArguments'],
        'timestamp': lastPageData['timestamp'],
      };
    } catch (e) {
      print('Error getting current route info: $e');
      return null;
    }
  }
}

// Session refresh result
class SessionRefreshResult {
  final bool success;
  final String? newToken;
  final String? newRefreshToken;
  final String? error;
  final bool shouldLogout;
  
  SessionRefreshResult({
    required this.success,
    this.newToken,
    this.newRefreshToken,
    this.error,
    this.shouldLogout = false,
  });
}
