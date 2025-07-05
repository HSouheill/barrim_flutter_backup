import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_manager.dart';
import '../utils/api_constants.dart';
import 'api_service.dart';

class AppleAuthService {
  /// Apple Sign-In request
  static Future<Map<String, dynamic>> appleLogin(String idToken) async {
    try {
      // Replicate _getHeaders logic
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token != null ? 'Bearer $token' : '',
      };

      // Use standard HTTP client
      final client = http.Client();
      final uri = Uri.parse('${ApiService.baseUrl}/api/auth/apple-login');
      final response = await client.post(
        uri,
        headers: headers,
        body: jsonEncode({'idToken': idToken}),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Save token if present
        if (responseData['data'] != null && responseData['data']['token'] != null) {
          final token = responseData['data']['token'];
          await ApiService.saveToken(token);
          await AuthManager.saveAuthData(token);
        }
        return responseData;
      } else {
        final errorMsg = responseData['message'] ?? 'Apple login failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Apple login error: $e');
      throw Exception(e.toString().contains('Exception:')
          ? e.toString().split('Exception: ')[1]
          : 'Connection error. Please check your network.');
    }
  }
} 