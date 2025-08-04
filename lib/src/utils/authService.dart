import 'dart:convert';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Base URL of your API
  final String baseUrl = ApiService.baseUrl;

  // Shared preferences key for storing the auth token
  static const String _tokenKey = 'auth_token';

  // Method to save authentication token to shared preferences
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Method to get authentication token from shared preferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Method to remove authentication token from shared preferences
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Login method
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'email': email,
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
  }

  // Logout method
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
      return {
        'status': 500,
        'message': 'Error during logout: ${e.toString()}'
      };
    }
  }
}