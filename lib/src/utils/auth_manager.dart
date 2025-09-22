// utils/auth_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthManager {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userTypeKey = 'user_type';
  static final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Save authentication data
  static Future<void> saveAuthData(String token) async {
    await _storage.write(key: _tokenKey, value: token);

    // Extract and save user ID and type from token
    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      if (decodedToken.containsKey('userId')) {
        await _storage.write(key: _userIdKey, value: decodedToken['userId']);
      }

      if (decodedToken.containsKey('userType')) {
        await _storage.write(key: _userTypeKey, value: decodedToken['userType']);
      }
    } catch (e) {
      print('Error extracting data from token: $e');
    }
  }

  // Get auth token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Get user ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // Get user type
  static Future<String?> getUserType() async {
    return await _storage.read(key: _userTypeKey);
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) {
      return false;
    }

    try {
      return !JwtDecoder.isExpired(token);
    } catch (e) {
      return false;
    }
  }

  // Check if user is a service provider
  static Future<bool> isServiceProvider() async {
    final userType = await getUserType();
    return userType == 'serviceProvider';
  }

  // Logout
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userTypeKey);
  }
}