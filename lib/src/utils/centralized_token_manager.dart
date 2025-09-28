// lib/utils/centralized_token_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Centralized token management to ensure consistency across the app
/// This class provides a single source of truth for token operations
class CentralizedTokenManager {
  static const String _tokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';
  
  // Primary storage: FlutterSecureStorage
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // Fallback storage: SharedPreferences (for compatibility)
  static SharedPreferences? _prefs;
  
  /// Initialize the token manager
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Get authentication token with fallback support
  static Future<String?> getToken() async {
    try {
      // Try secure storage first (primary)
      String? token = await _secureStorage.read(key: _tokenKey);
      
      if (token != null && token.isNotEmpty) {
        if (!kReleaseMode) {
          print('Token retrieved from secure storage');
        }
        return token;
      }
      
      // Fallback to SharedPreferences
      if (_prefs != null) {
        token = _prefs!.getString(_tokenKey);
        if (token != null && token.isNotEmpty) {
          if (!kReleaseMode) {
            print('Token retrieved from SharedPreferences (fallback)');
          }
          // Migrate to secure storage
          await _secureStorage.write(key: _tokenKey, value: token);
          return token;
        }
      }
      
      if (!kReleaseMode) {
        print('No token found in any storage');
      }
      return null;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error retrieving token: $e');
      }
      return null;
    }
  }
  
  /// Save authentication token to both storages
  static Future<void> saveToken(String token) async {
    try {
      if (token.trim().isEmpty) {
        throw Exception('Token cannot be empty');
      }
      
      // Basic JWT format validation
      if (!token.contains('.')) {
        throw Exception('Invalid token format');
      }
      
      final trimmedToken = token.trim();
      
      // Save to secure storage (primary)
      await _secureStorage.write(key: _tokenKey, value: trimmedToken);
      
      // Also save to SharedPreferences for compatibility
      if (_prefs != null) {
        await _prefs!.setString(_tokenKey, trimmedToken);
      }
      
      if (!kReleaseMode) {
        print('Token saved successfully to both storages');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error saving token: $e');
      }
      rethrow;
    }
  }
  
  /// Clear token from all storages
  static Future<void> clearToken() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _tokenKey),
        if (_prefs != null) _prefs!.remove(_tokenKey),
      ]);
      
      if (!kReleaseMode) {
        print('Token cleared from all storages');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error clearing token: $e');
      }
    }
  }
  
  /// Check if token exists
  static Future<bool> hasToken() async {
    try {
      final token = await getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error checking token existence: $e');
      }
      return false;
    }
  }
  
  /// Get user type
  static Future<String?> getUserType() async {
    try {
      String? userType = await _secureStorage.read(key: _userTypeKey);
      
      if (userType == null && _prefs != null) {
        userType = _prefs!.getString(_userTypeKey);
        if (userType != null) {
          // Migrate to secure storage
          await _secureStorage.write(key: _userTypeKey, value: userType);
        }
      }
      
      return userType;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting user type: $e');
      }
      return null;
    }
  }
  
  /// Save user type
  static Future<void> saveUserType(String userType) async {
    try {
      await _secureStorage.write(key: _userTypeKey, value: userType);
      if (_prefs != null) {
        await _prefs!.setString(_userTypeKey, userType);
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error saving user type: $e');
      }
    }
  }
  
  /// Get user ID
  static Future<String?> getUserId() async {
    try {
      String? userId = await _secureStorage.read(key: _userIdKey);
      
      if (userId == null && _prefs != null) {
        userId = _prefs!.getString(_userIdKey);
        if (userId != null) {
          // Migrate to secure storage
          await _secureStorage.write(key: _userIdKey, value: userId);
        }
      }
      
      return userId;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting user ID: $e');
      }
      return null;
    }
  }
  
  /// Save user ID
  static Future<void> saveUserId(String userId) async {
    try {
      await _secureStorage.write(key: _userIdKey, value: userId);
      if (_prefs != null) {
        await _prefs!.setString(_userIdKey, userId);
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error saving user ID: $e');
      }
    }
  }
  
  /// Get user email
  static Future<String?> getEmail() async {
    try {
      String? email = await _secureStorage.read(key: _emailKey);
      
      if (email == null && _prefs != null) {
        email = _prefs!.getString(_emailKey);
        if (email != null) {
          // Migrate to secure storage
          await _secureStorage.write(key: _emailKey, value: email);
        }
      }
      
      return email;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting email: $e');
      }
      return null;
    }
  }
  
  /// Save user email
  static Future<void> saveEmail(String email) async {
    try {
      await _secureStorage.write(key: _emailKey, value: email);
      if (_prefs != null) {
        await _prefs!.setString(_emailKey, email);
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error saving email: $e');
      }
    }
  }
  
  /// Clear all stored data
  static Future<void> clearAll() async {
    try {
      await Future.wait([
        _secureStorage.deleteAll(),
        if (_prefs != null) _prefs!.clear(),
      ]);
      
      if (!kReleaseMode) {
        print('All data cleared from all storages');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error clearing all data: $e');
      }
    }
  }
  
  /// Get authentication headers for API requests
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'BarrimApp/1.0.12',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      if (!kReleaseMode) {
        print('Warning: No authentication token found for API request');
      }
    }
    
    return headers;
  }
  
  /// Validate token format
  static bool isValidTokenFormat(String? token) {
    if (token == null || token.trim().isEmpty) {
      return false;
    }
    
    // Basic JWT format validation (3 parts separated by dots)
    final parts = token.split('.');
    return parts.length == 3;
  }
  
  /// Get debug information about token state
  static Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final secureToken = await _secureStorage.read(key: _tokenKey);
      final prefsToken = _prefs?.getString(_tokenKey);
      final token = await getToken();
      final hasToken = token != null && token.isNotEmpty;
      
      return {
        'hasToken': hasToken,
        'tokenLength': token?.length ?? 0,
        'isValidFormat': isValidTokenFormat(token),
        'secureStorageToken': secureToken != null,
        'sharedPrefsToken': prefsToken != null,
        'tokensMatch': secureToken == prefsToken,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
