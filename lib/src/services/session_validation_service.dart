import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barrim/src/services/extended_session_service.dart';
import 'package:barrim/src/utils/session_manager.dart';

// Session validation events
enum SessionValidationEvent {
  sessionValid,
  sessionExpiringSoon,
  sessionExpired,
  sessionRefreshed,
  validationError,
}

/// Comprehensive session validation service that handles both regular and extended sessions
class SessionValidationService {
  static Timer? _validationTimer;
  static Timer? _warningTimer;
  static StreamController<SessionValidationEvent>? _eventController;
  
  // Validation intervals
  static const Duration validationInterval = Duration(minutes: 5);
  static const Duration warningInterval = Duration(minutes: 1);
  
  // Initialize the validation service
  static Future<void> initialize() async {
    _eventController = StreamController<SessionValidationEvent>.broadcast();
    await _startPeriodicValidation();
  }
  
  // Get validation event stream
  static Stream<SessionValidationEvent> get validationEvents {
    _eventController ??= StreamController<SessionValidationEvent>.broadcast();
    return _eventController!.stream;
  }
  
  // Start periodic validation
  static Future<void> _startPeriodicValidation() async {
    _stopPeriodicValidation();
    
    // Validate immediately
    await _validateSession();
    
    // Set up periodic validation
    _validationTimer = Timer.periodic(validationInterval, (timer) async {
      await _validateSession();
    });
    
    // Set up warning checks
    _warningTimer = Timer.periodic(warningInterval, (timer) async {
      await _checkSessionWarnings();
    });
  }
  
  // Stop periodic validation
  static void _stopPeriodicValidation() {
    _validationTimer?.cancel();
    _warningTimer?.cancel();
    _validationTimer = null;
    _warningTimer = null;
  }
  
  // Validate current session
  static Future<bool> _validateSession() async {
    try {
      // First check extended session
      final isExtendedValid = await ExtendedSessionService.isSessionValid();
      if (isExtendedValid) {
        _notifyEvent(SessionValidationEvent.sessionValid);
        return true;
      }
      
      // Fall back to regular session
      final isRegularValid = await SessionManager.isSessionValid();
      if (isRegularValid) {
        _notifyEvent(SessionValidationEvent.sessionValid);
        return true;
      }
      
      // No valid session found
      _notifyEvent(SessionValidationEvent.sessionExpired);
      return false;
    } catch (e) {
      if (!kReleaseMode) {
        print('Session validation error: $e');
      }
      _notifyEvent(SessionValidationEvent.validationError);
      return false;
    }
  }
  
  // Check for session warnings
  static Future<void> _checkSessionWarnings() async {
    try {
      // Check extended session warnings
      final isExtendedExpiringSoon = await ExtendedSessionService.isSessionExpiringSoon();
      if (isExtendedExpiringSoon) {
        _notifyEvent(SessionValidationEvent.sessionExpiringSoon);
        return;
      }
      
      // Check regular session warnings
      final isRegularExpiringSoon = await SessionManager.isSessionExpiringSoon();
      if (isRegularExpiringSoon) {
        _notifyEvent(SessionValidationEvent.sessionExpiringSoon);
        return;
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Session warning check error: $e');
      }
    }
  }
  
  // Comprehensive session validation with fallback
  static Future<SessionValidationResult> validateSessionComprehensive() async {
    try {
      // First try extended session
      final extendedStatus = await ExtendedSessionService.getSessionStatus();
      if (extendedStatus['isValid'] == true) {
        return SessionValidationResult(
          isValid: true,
          sessionType: SessionType.extended,
          timeUntilExpiry: Duration(days: extendedStatus['timeUntilExpiry'] ?? 0),
          rememberMe: extendedStatus['rememberMe'] ?? false,
          lastActivity: DateTime.now(), // Extended session tracks this internally
        );
      }
      
      // Fall back to regular session
      final regularStatus = await SessionManager.getSessionStatus();
      if (regularStatus['isValid'] == true) {
        return SessionValidationResult(
          isValid: true,
          sessionType: SessionType.regular,
          timeUntilExpiry: Duration(minutes: regularStatus['timeUntilExpiry'] ?? 0),
          rememberMe: false,
          lastActivity: DateTime.now(), // Regular session tracks this internally
        );
      }
      
      // No valid session
      return SessionValidationResult(
        isValid: false,
        sessionType: SessionType.none,
        timeUntilExpiry: Duration.zero,
        rememberMe: false,
        lastActivity: null,
      );
    } catch (e) {
      if (!kReleaseMode) {
        print('Comprehensive session validation error: $e');
      }
      return SessionValidationResult(
        isValid: false,
        sessionType: SessionType.none,
        timeUntilExpiry: Duration.zero,
        rememberMe: false,
        lastActivity: null,
        error: e.toString(),
      );
    }
  }
  
  // Refresh session with fallback
  static Future<bool> refreshSessionWithFallback() async {
    try {
      // First try extended session refresh
      final extendedRefreshResult = await ExtendedSessionService.refreshSession();
      if (extendedRefreshResult.success) {
        _notifyEvent(SessionValidationEvent.sessionRefreshed);
        return true;
      }
      
      // Fall back to regular session refresh
      final regularRefreshResult = await SessionManager.refreshSession();
      if (regularRefreshResult.success) {
        _notifyEvent(SessionValidationEvent.sessionRefreshed);
        return true;
      }
      
      return false;
    } catch (e) {
      if (!kReleaseMode) {
        print('Session refresh error: $e');
      }
      _notifyEvent(SessionValidationEvent.validationError);
      return false;
    }
  }
  
  // Get session info for debugging
  static Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final extendedStatus = await ExtendedSessionService.getSessionStatus();
      final regularStatus = await SessionManager.getSessionStatus();
      
      return {
        'extendedSession': extendedStatus,
        'regularSession': regularStatus,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Check if user should be redirected to login
  static Future<bool> shouldRedirectToLogin() async {
    try {
      final result = await validateSessionComprehensive();
      return !result.isValid;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error checking if should redirect to login: $e');
      }
      return true; // Default to redirecting to login on error
    }
  }
  
  // Clear all sessions
  static Future<void> clearAllSessions() async {
    try {
      await Future.wait([
        ExtendedSessionService.clearSession(),
        SessionManager.clearSession(),
      ]);
      _notifyEvent(SessionValidationEvent.sessionExpired);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error clearing sessions: $e');
      }
    }
  }
  
  // Notify validation event
  static void _notifyEvent(SessionValidationEvent event) {
    if (_eventController != null && !_eventController!.isClosed) {
      _eventController!.add(event);
    }
  }
  
  // Dispose resources
  static void dispose() {
    _stopPeriodicValidation();
    _eventController?.close();
    _eventController = null;
  }
}

// Session validation result
class SessionValidationResult {
  final bool isValid;
  final SessionType sessionType;
  final Duration timeUntilExpiry;
  final bool rememberMe;
  final DateTime? lastActivity;
  final String? error;
  
  SessionValidationResult({
    required this.isValid,
    required this.sessionType,
    required this.timeUntilExpiry,
    required this.rememberMe,
    this.lastActivity,
    this.error,
  });
  
  bool get isExpiringSoon => timeUntilExpiry.inDays <= 7 || timeUntilExpiry.inHours <= 24;
  bool get isExtendedSession => sessionType == SessionType.extended;
  bool get isRegularSession => sessionType == SessionType.regular;
  bool get hasError => error != null;
}

// Session types
enum SessionType {
  none,
  regular,
  extended,
}
