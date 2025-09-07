import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'api_service.dart';

class ValidationService {
  static const String baseUrl = ApiService.baseUrl;

  // --- Custom HTTP client with proper SSL handling ---
  static http.Client? _customClient;
  static Future<http.Client> _getCustomClient() async {
    if (_customClient != null) return _customClient!;
    
    // In production, use standard HTTP client for proper SSL validation
    // Let's Encrypt certificates are automatically trusted
    _customClient = http.Client();
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
      // Input validation
      if (email.trim().isEmpty) {
        throw Exception('Email is required');
      }
      
      // Email format validation
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
        throw Exception('Invalid email format');
      }
      
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/check-email'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Barrim-Mobile-App/1.0',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
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
      throw Exception('Failed to check email availability');
    }
  }

  /// Check if phone number exists across all user types
  static Future<Map<String, dynamic>> checkPhoneExists(String phone) async {
    try {
      // Input validation
      if (phone.trim().isEmpty) {
        throw Exception('Phone number is required');
      }
      
      // Format phone number
      String formattedPhone = phone.trim();
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+961${formattedPhone.substring(1)}';
      } else if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+961$formattedPhone';
      }
      
      // Phone format validation
      if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(formattedPhone.replaceAll(RegExp(r'[\s-]'), ''))) {
        throw Exception('Invalid phone number format');
      }

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/check-phone'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Barrim-Mobile-App/1.0',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
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
      throw Exception('Failed to check phone availability');
    }
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.trim().isEmpty) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
  }

  /// Validate phone format
  static bool isValidPhone(String phone) {
    if (phone.trim().isEmpty) return false;
    // Remove spaces and special characters
    String cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^(\+?[0-9]{8,15}|[0-9]{8,15})$').hasMatch(cleanPhone);
  }

  /// Validate password strength
  static Map<String, dynamic> validatePassword(String password) {
    List<String> errors = [];
    bool isValid = true;

    if (password.trim().isEmpty) {
      errors.add('Password is required');
      isValid = false;
    } else if (password.length < 8) {
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
    if (email.trim().isEmpty) {
      result['isValid'] = false;
      result['errors'].add('Email is required');
    } else if (!isValidEmail(email)) {
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
    if (password.trim().isEmpty) {
      result['isValid'] = false;
      result['errors'].add('Password is required');
    } else {
      final passwordValidation = validatePassword(password);
      if (!passwordValidation['isValid']) {
        result['isValid'] = false;
        result['errors'].addAll(passwordValidation['errors']);
      }
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