import 'dart:convert';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Base URL of your API
  final String baseUrl = ApiService.baseUrl;

  // Secure storage for auth token
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const String _tokenKey = 'auth_token';

  // Method to save authentication token securely
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

  // Method to get authentication token securely
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

  // Method to remove authentication token securely
  Future<void> removeToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error removing token: $e');
      }
    }
  }

  // Login method with input validation and security headers
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Input validation
      if (email.trim().isEmpty) {
        throw Exception('Email is required');
      }
      if (password.trim().isEmpty) {
        throw Exception('Password is required');
      }
      
      // Email format validation
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
        throw Exception('Invalid email format');
      }
      
      // Password length validation
      if (password.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'User-Agent': 'Barrim-Mobile-App/1.0',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
        body: jsonEncode(<String, String>{
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save token if login is successful
        if (responseData['data'] != null && responseData['data']['token'] != null) {
          await saveToken(responseData['data']['token']);
        }
      }

      return responseData;
    } catch (e) {
      if (!kReleaseMode) {
        print('Login error: $e');
      }
      rethrow;
    }
  }

  // Logout method with security headers
  Future<Map<String, dynamic>> logout() async {
    try {
      // Get the auth token
      final token = await getToken();

      if (token == null) {
        return {
          'status': 401,
          'message': 'Not authenticated'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/logout'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'User-Agent': 'Barrim-Mobile-App/1.0',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );

      final responseData = jsonDecode(response.body);

      // Remove token regardless of server response
      await removeToken();

      // Return the server response with proper status handling
      return {
        'status': response.statusCode,
        'message': responseData['message'] ?? 'Logout completed',
        'data': responseData['data'] ?? {},
      };
    } catch (e) {
      // Handle any exceptions and still clear the token
      await removeToken();
      if (!kReleaseMode) {
        print('Logout error: $e');
      }
      return {
        'status': 500,
        'message': 'Error during logout'
      };
    }
  }
}