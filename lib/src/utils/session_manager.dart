import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';

class SessionManager {
  static const String _tokenKey = 'auth_token';
  static const String _userDataKey = 'user_data';
  static const String _lastActivityKey = 'last_activity';
  static const Duration _sessionTimeout = Duration(hours: 24); // 24 hours session timeout

  // Save session data
  static Future<void> saveSession(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userDataKey, json.encode(userData));
    await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  // Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get stored user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return null;
  }

  // Check if session is valid
  static Future<bool> isSessionValid() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      // Check if token is expired using JWT decoder
      if (JwtDecoder.isExpired(token)) {
        await clearSession();
        return false;
      }

      // Check if session has timed out based on last activity
      final prefs = await SharedPreferences.getInstance();
      final lastActivityString = prefs.getString(_lastActivityKey);
      if (lastActivityString != null) {
        final lastActivity = DateTime.parse(lastActivityString);
        final now = DateTime.now();
        if (now.difference(lastActivity) > _sessionTimeout) {
          await clearSession();
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error checking session validity: $e');
      await clearSession();
      return false;
    }
  }

  // Update last activity timestamp
  static Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  // Clear session data
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_lastActivityKey);
  }

  // Get session info for debugging
  static Future<Map<String, dynamic>> getSessionInfo() async {
    final token = await getToken();
    final userData = await getUserData();
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getString(_lastActivityKey);

    return {
      'hasToken': token != null,
      'hasUserData': userData != null,
      'lastActivity': lastActivity,
      'tokenExpired': token != null ? JwtDecoder.isExpired(token) : null,
    };
  }
} 