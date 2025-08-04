// services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Make sure this is in your pubspec.yaml

import '../models/user.dart';
import '../utils/token_manager.dart';

class AuthService extends ChangeNotifier {
  final String baseUrl = ApiService.baseUrl;
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;
  final TokenManager _tokenManager = TokenManager();

  // --- Custom HTTP client for self-signed certificates ---
  static http.Client? _customClient;
  static Future<http.Client> _getCustomClient() async {
    return http.Client();
  }
  static Future<http.Response> _makeRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = await _getCustomClient();
    switch (method.toUpperCase()) {
      case 'GET':
        return await client.get(uri, headers: headers);
      case 'POST':
        return await client.post(uri, headers: headers, body: body);
      case 'PUT':
        return await client.put(uri, headers: headers, body: body);
      case 'DELETE':
        return await client.delete(uri, headers: headers, body: body);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize the auth service and try to load cached user data
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadUserFromPrefs();
    } catch (e) {
      _error = 'Error initializing auth service: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user data from SharedPreferences
  Future<void> _loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    final userToken = prefs.getString('auth_token');

    if (userData != null && userToken != null) {
      try {
        final userMap = json.decode(userData);
        _currentUser = User.fromJson(userMap);
        _token = userToken;

        // Optionally validate the token with the server
        final isValid = await _validateToken(userToken);
        if (!isValid) {
          // If token is invalid, clear data
          await logout();
        }
      } catch (e) {
        print('Error parsing saved user data: $e');
        await logout(); // Clear invalid data
      }
    }
  }

  // Validate token with the server
  Future<bool> _validateToken(String token) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/auth/validate-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error validating token: $e');
      return false;
    }
  }

  // Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final client = http.Client();
      
      final response = await client.post(
        Uri.parse('${ApiService.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        _token = responseData['token'];
        _currentUser = User.fromJson(responseData['user']);

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('auth_token', _token!);
        prefs.setString('user_data', json.encode(_currentUser!.toJson()));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = responseData['message'] ?? 'Authentication failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error during login: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register a new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String userType, // 'user', 'company', etc.
    String? companyName,
    String? companyLicense,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create request body based on user type
      final Map<String, dynamic> requestBody = {
        'name': name,
        'email': email,
        'password': password,
        'userType': userType,
      };

      // Add company details if registering as a company
      if (userType == 'company') {
        if (companyName == null || companyLicense == null) {
          throw Exception('Company name and license are required for company registration');
        }
        requestBody['companyName'] = companyName;
        requestBody['companyLicense'] = companyLicense;
      }

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        // Registration successful, proceed with login
        return await login(email, password);
      } else {
        _error = responseData['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error during registration: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      // Get the current token
      final token = await getToken();
      
      if (token != null) {
        // Call the logout endpoint to blacklist the token
        try {
          final response = await _makeRequest(
            'POST',
            Uri.parse('$baseUrl/api/auth/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          
          // Log the response for debugging
          print('Logout endpoint response: ${response.statusCode}');
        } catch (e) {
          // Don't fail logout if server call fails, just log it
          print('Error calling logout endpoint: $e');
        }
      }

      // Clear local data regardless of server response
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');

      _token = null;
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error during logout: $e';
      print(_error);
    }
  }

  // Get the current token
  Future<String?> getToken() async {
    if (_token != null) return _token;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Get user type ('user', 'company', 'admin', etc.)
  Future<String> getUserType() async {
    if (_currentUser != null) {
      return _currentUser!.userType;
    }

    // Try to load from preferences if not already loaded
    await _loadUserFromPrefs();

    if (_currentUser != null) {
      return _currentUser!.userType;
    }

    // Default to regular user if not authenticated
    return 'user';
  }

  // Update user profile
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? profileImage,
  }) async {
    if (_token == null || _currentUser == null) {
      _error = 'User not authenticated';
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (profileImage != null) updateData['profileImage'] = profileImage;

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _currentUser = User.fromJson(responseData['user']);

        // Update stored user data
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('user_data', json.encode(_currentUser!.toJson()));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final responseData = json.decode(response.body);
        _error = responseData['message'] ?? 'Failed to update profile';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error updating profile: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) {
      _error = 'User not authenticated';
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/users/change-password'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = responseData['message'] ?? 'Failed to change password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error changing password: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Request password reset
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final responseData = json.decode(response.body);
        _error = responseData['message'] ?? 'Failed to request password reset';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error requesting password reset: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reset password with token
  Future<bool> resetPassword(String token, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final responseData = json.decode(response.body);
        _error = responseData['message'] ?? 'Failed to reset password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error resetting password: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserData() async {
    print('AuthService: getUserData called');
    try {
      final token = await _tokenManager.getToken();
      print('AuthService: Token retrieved: ${token.isNotEmpty ? 'Token exists' : 'No token'}');

      final url = '$baseUrl/api/companies/data';
      print('AuthService: Making request to: $url');

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('AuthService: Response status code: ${response.statusCode}');
      print('AuthService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('AuthService: Successfully decoded user data');
        return data['data'];
      } else {
        print('AuthService: Failed with status code: ${response.statusCode}');
        throw Exception('Failed to get user data: ${response.body}');
      }
    } catch (e) {
      print('AuthService: Exception caught in getUserData: $e');
      throw Exception('Error in getUserData: $e');
    }
  }

  Future<String> getUserEmail() async {
    print('AuthService: getUserEmail called');
    try {
      final userData = await getUserData();
      final email = userData['email'] ?? '';
      print('AuthService: Got user email: $email');
      return email;
    } catch (e) {
      print('AuthService: Exception caught in getUserEmail: $e');
      // If there's an error, return empty string
      return '';
    }
  }
}