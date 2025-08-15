import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'api_service.dart';

class ValidationService {
  static const String baseUrl = ApiService.baseUrl;

  // --- Custom HTTP client for self-signed certificates ---
  static http.Client? _customClient;
  static Future<http.Client> _getCustomClient() async {
    if (_customClient != null) return _customClient!;
    HttpClient httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) {
      return host == '104.131.188.174' || host == 'barrim.online';
    };
    _customClient = IOClient(httpClient);
    return _customClient!;
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

  /// Check if email exists across all user types
  static Future<Map<String, dynamic>> checkEmailExists(String email) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/check-email'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'exists': responseData['exists'] ?? false,
          'userTypes': responseData['userTypes'] ?? [],
          'message': responseData['message'] ?? '',
        };
      } else {
        throw Exception(responseData['message'] ?? 'Failed to check email');
      }
    } catch (e) {
      throw Exception('Error checking email: $e');
    }
  }

  /// Check if phone number exists across all user types
  static Future<Map<String, dynamic>> checkPhoneExists(String phone) async {
    try {
      // Format phone number
      String formattedPhone = phone.trim();
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+961${formattedPhone.substring(1)}';
      } else if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+961$formattedPhone';
      }

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/check-phone'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': formattedPhone,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'exists': responseData['exists'] ?? false,
          'userTypes': responseData['userTypes'] ?? [],
          'message': responseData['message'] ?? '',
        };
      } else {
        throw Exception(responseData['message'] ?? 'Failed to check phone');
      }
    } catch (e) {
      throw Exception('Error checking phone: $e');
    }
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
  }

  /// Validate phone format
  static bool isValidPhone(String phone) {
    // Remove spaces and special characters
    String cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^(\+?[0-9]{8,15}|[0-9]{8,15})$').hasMatch(cleanPhone);
  }

  /// Validate password strength
  static Map<String, dynamic> validatePassword(String password) {
    List<String> errors = [];
    bool isValid = true;

    if (password.length < 8) {
      errors.add('Password must be at least 8 characters long');
      isValid = false;
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least one uppercase letter');
      isValid = false;
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least one lowercase letter');
      isValid = false;
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least one number');
      isValid = false;
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Password must contain at least one special character');
      isValid = false;
    }

    return {
      'isValid': isValid,
      'errors': errors,
    };
  }

  /// Comprehensive validation for signup
  static Future<Map<String, dynamic>> validateSignupData({
    required String email,
    required String password,
    String? phone,
    required String userType,
  }) async {
    Map<String, dynamic> result = {
      'isValid': true,
      'errors': [],
      'warnings': [],
    };

    // Validate email format
    if (!isValidEmail(email)) {
      result['isValid'] = false;
      result['errors'].add('Please enter a valid email address');
    }

    // Check if email exists
    try {
      final emailCheck = await checkEmailExists(email);
      if (emailCheck['exists']) {
        result['isValid'] = false;
        List<String> existingTypes = emailCheck['userTypes'];
        result['errors'].add('Email already exists for: ${existingTypes.join(', ')}');
      }
    } catch (e) {
      result['warnings'].add('Could not verify email availability: ${e.toString()}');
    }

    // Validate phone if provided
    if (phone != null && phone.isNotEmpty) {
      if (!isValidPhone(phone)) {
        result['isValid'] = false;
        result['errors'].add('Please enter a valid phone number');
      } else {
        try {
          final phoneCheck = await checkPhoneExists(phone);
          if (phoneCheck['exists']) {
            result['isValid'] = false;
            List<String> existingTypes = phoneCheck['userTypes'];
            result['errors'].add('Phone number already exists for: ${existingTypes.join(', ')}');
          }
        } catch (e) {
          result['warnings'].add('Could not verify phone availability: ${e.toString()}');
        }
      }
    }

    // Validate password strength
    final passwordValidation = validatePassword(password);
    if (!passwordValidation['isValid']) {
      result['isValid'] = false;
      result['errors'].addAll(passwordValidation['errors']);
    }

    return result;
  }

  /// Get user-friendly error message for validation failures
  static String getErrorMessage(List<String> errors) {
    if (errors.isEmpty) return '';
    
    if (errors.length == 1) {
      return errors.first;
    }
    
    return 'Multiple validation errors:\n${errors.map((e) => '• $e').join('\n')}';
  }

  /// Get user-friendly warning message
  static String getWarningMessage(List<String> warnings) {
    if (warnings.isEmpty) return '';
    
    if (warnings.length == 1) {
      return warnings.first;
    }
    
    return 'Warnings:\n${warnings.map((w) => '• $w').join('\n')}';
  }
} 