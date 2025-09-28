// lib/utils/token_debug_helper.dart
import 'package:flutter/foundation.dart';
import 'centralized_token_manager.dart';

/// Debug helper for monitoring token state during navigation
class TokenDebugHelper {
  static bool _isEnabled = !kReleaseMode;
  
  /// Enable or disable debug logging
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }
  
  /// Log token state before navigation
  static Future<void> logTokenStateBeforeNavigation(String screenName) async {
    if (!_isEnabled) return;
    
    try {
      final debugInfo = await CentralizedTokenManager.getDebugInfo();
      print('🔍 [TOKEN DEBUG] Before navigating to $screenName:');
      print('   - Has Token: ${debugInfo['hasToken']}');
      print('   - Token Length: ${debugInfo['tokenLength']}');
      print('   - Valid Format: ${debugInfo['isValidFormat']}');
      print('   - Secure Storage: ${debugInfo['secureStorageToken']}');
      print('   - Shared Prefs: ${debugInfo['sharedPrefsToken']}');
      print('   - Tokens Match: ${debugInfo['tokensMatch']}');
    } catch (e) {
      print('❌ [TOKEN DEBUG] Error getting token state: $e');
    }
  }
  
  /// Log token state after navigation
  static Future<void> logTokenStateAfterNavigation(String screenName) async {
    if (!_isEnabled) return;
    
    try {
      final debugInfo = await CentralizedTokenManager.getDebugInfo();
      print('🔍 [TOKEN DEBUG] After navigating to $screenName:');
      print('   - Has Token: ${debugInfo['hasToken']}');
      print('   - Token Length: ${debugInfo['tokenLength']}');
      print('   - Valid Format: ${debugInfo['isValidFormat']}');
      print('   - Secure Storage: ${debugInfo['secureStorageToken']}');
      print('   - Shared Prefs: ${debugInfo['sharedPrefsToken']}');
      print('   - Tokens Match: ${debugInfo['tokensMatch']}');
    } catch (e) {
      print('❌ [TOKEN DEBUG] Error getting token state: $e');
    }
  }
  
  /// Log API request with token info
  static Future<void> logApiRequest(String endpoint) async {
    if (!_isEnabled) return;
    
    try {
      final token = await CentralizedTokenManager.getToken();
      print('🌐 [API DEBUG] Making request to $endpoint');
      print('   - Token Available: ${token != null}');
      print('   - Token Length: ${token?.length ?? 0}');
      print('   - Token Preview: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
    } catch (e) {
      print('❌ [API DEBUG] Error getting token for API request: $e');
    }
  }
  
  /// Log authentication error
  static void logAuthError(String context, String error) {
    if (!_isEnabled) return;
    
    print('❌ [AUTH ERROR] In $context: $error');
  }
  
  /// Log successful authentication
  static void logAuthSuccess(String context) {
    if (!_isEnabled) return;
    
    print('✅ [AUTH SUCCESS] $context');
  }
  
  /// Check and log token consistency
  static Future<void> checkTokenConsistency() async {
    if (!_isEnabled) return;
    
    try {
      final debugInfo = await CentralizedTokenManager.getDebugInfo();
      final hasToken = debugInfo['hasToken'] as bool;
      final secureStorageToken = debugInfo['secureStorageToken'] as bool;
      final sharedPrefsToken = debugInfo['sharedPrefsToken'] as bool;
      final tokensMatch = debugInfo['tokensMatch'] as bool;
      
      if (!hasToken) {
        print('⚠️ [TOKEN CONSISTENCY] No token found in any storage');
      } else if (!tokensMatch) {
        print('⚠️ [TOKEN CONSISTENCY] Tokens in different storages don\'t match');
      } else if (secureStorageToken && sharedPrefsToken) {
        print('✅ [TOKEN CONSISTENCY] Token found in both storages and they match');
      } else if (secureStorageToken) {
        print('✅ [TOKEN CONSISTENCY] Token found in secure storage only');
      } else if (sharedPrefsToken) {
        print('⚠️ [TOKEN CONSISTENCY] Token found in SharedPreferences only (should migrate to secure storage)');
      }
    } catch (e) {
      print('❌ [TOKEN CONSISTENCY] Error checking consistency: $e');
    }
  }
}
