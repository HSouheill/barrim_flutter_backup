// lib/utils/token_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class TokenManager {
  static const String _tokenKey = 'auth_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Save the token securely
  Future<void> saveToken(String token) async {
    try {
      // Basic token format validation
      if (token.trim().isEmpty) {
        throw Exception('Token cannot be empty');
      }
      
      // Basic JWT format validation
      if (!token.contains('.')) {
        throw Exception('Invalid token format');
      }
      
      await _storage.write(key: _tokenKey, value: token.trim());
    } catch (e) {
      if (!kReleaseMode) {
        print('Error saving token: $e');
      }
      rethrow;
    }
  }

  // Get the token securely
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error getting token: $e');
      }
      return null;
    }
  }

  // Clear the token (for logout)
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error clearing token: $e');
      }
    }
  }

  // Check if a token exists
  Future<bool> hasToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error checking token existence: $e');
      }
      return false;
    }
  }
}