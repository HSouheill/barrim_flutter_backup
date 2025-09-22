import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  final String _tokenKey = 'auth_token';
  final String _userTypeKey = 'user_type';
  final String _userIdKey = 'user_id';
  final String _emailKey = 'user_email';

  // Save token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Get token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Delete token
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // Save user type
  Future<void> saveUserType(String userType) async {
    await _storage.write(key: _userTypeKey, value: userType);
  }

  // Get user type
  Future<String?> getUserType() async {
    return await _storage.read(key: _userTypeKey);
  }

  // Save user ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  // Get user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // Save user email
  Future<void> saveEmail(String email) async {
    await _storage.write(key: _emailKey, value: email);
  }

  // Get user email
  Future<String?> getEmail() async {
    return await _storage.read(key: _emailKey);
  }

  // Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}