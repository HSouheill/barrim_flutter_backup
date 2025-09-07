import 'dart:convert';
import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

// Model class for referred users
class ReferredUser {
  final String id;
  final String fullName;
  final String? logoPath;
  final String? userType;

  ReferredUser({
    required this.id,
    required this.fullName,
    this.logoPath,
    this.userType,
  });

  factory ReferredUser.fromJson(Map<String, dynamic> json) {
    return ReferredUser(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      logoPath: json['logoPath'],
      userType: json['userType'],
    );
  }
}

// Model class for referral data
class ReferralData {
  final String referralCode;
  final int points;
  final int referredCount;
  final List<ReferredUser> referredUsers;
  final String qrCodeUrl;

  ReferralData({
    required this.referralCode,
    required this.points,
    required this.referredCount,
    required this.referredUsers,
    required this.qrCodeUrl,
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    List<ReferredUser> users = [];
    if (json['referredUsers'] != null) {
      users = List<ReferredUser>.from(
          json['referredUsers'].map((user) => ReferredUser.fromJson(user))
      );
    }

    return ReferralData(
      referralCode: json['referralCode'] ?? '',
      points: json['points'] ?? 0,
      referredCount: json['referredCount'] ?? 0,
      referredUsers: users,
      qrCodeUrl: json['qrCodeURL'] ?? '',
    );
  }
}

class ReferralResult<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  ReferralResult.success(this.data)
      : errorMessage = null,
        isSuccess = true;

  ReferralResult.error(this.errorMessage)
      : data = null,
        isSuccess = false;
}

class ReferralService {
  // Base URL for API calls
  final String baseUrl = ApiService.baseUrl;

  // Debug mode flag
  final bool _debugMode = kDebugMode;

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

  // Get the auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        _logDebug('Auth token is null or empty');
        return null;
      }

      return token;
    } catch (e) {
      _logDebug('Error retrieving auth token: $e');
      return null;
    }
  }

  // Log debug messages
  void _logDebug(String message) {
    if (_debugMode && !kReleaseMode) {
      debugPrint('🔍 ReferralService: $message');
    }
  }

  // Fetch service provider referral data
  Future<ReferralResult<ReferralData>> getServiceProviderReferralData() async {
    try {
      _logDebug('Fetching referral data...');
      final token = await _getAuthToken();
      if (token == null) {
        return ReferralResult.error('Authentication token not found. Please log in again.');
      }

      final Uri endpoint = Uri.parse('$baseUrl/api/service-provider/referral-data');
      _logDebug('Sending GET request to: $endpoint');

      final response = await _makeRequest(
        'GET',
        endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _logDebug('Request timed out');
          throw Exception('Connection timed out. Please check your internet connection.');
        },
      );

      _logDebug('Response status code: ${response.statusCode}');
      // Response body logged without sensitive data

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);

          if (responseData['status'] == 200 && responseData['data'] != null) {
            final referralData = ReferralData.fromJson(responseData['data']);
            _logDebug('Successfully parsed referral data');
            return ReferralResult.success(referralData);
          } else {
            final message = responseData['message'] ?? 'Failed to load referral data';
            _logDebug('API returned error: $message');
            return ReferralResult.error(message);
          }
        } catch (e) {
          _logDebug('Error parsing response: $e');
          return ReferralResult.error('Error parsing server response. Please try again later.');
        }
      } else if (response.statusCode == 401) {
        _logDebug('Authentication failed (401)');
        return ReferralResult.error('Session expired. Please log in again.');
      } else if (response.statusCode >= 500) {
        _logDebug('Server error (${response.statusCode})');
        return ReferralResult.error('Server is currently unavailable. Please try again later.');
      } else {
        _logDebug('HTTP error: ${response.statusCode}');
        return ReferralResult.error('Failed to load referral data: ${response.statusCode}');
      }
    } catch (e) {
      _logDebug('Exception caught: $e');
      if (e.toString().contains('SocketException')) {
        return ReferralResult.error('No internet connection. Please check your network settings.');
      }
      return ReferralResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Get QR code as image
  Future<Image?> getQRCodeImage(String referralCode) async {
    try {
      // Input validation
      if (referralCode.trim().isEmpty) {
        return null;
      }
      
      // Basic format validation (alphanumeric with length check)
      if (!RegExp(r'^[a-zA-Z0-9]{6,20}$').hasMatch(referralCode.trim())) {
        return null;
      }
      
      _logDebug('Fetching QR code image');
      final token = await _getAuthToken();
      if (token == null) {
        _logDebug('Auth token not found for QR code request');
        return null;
      }

      // We'll use the direct URL to the QR code image
      final qrCodeUrl = '$baseUrl/api/qrcode/referral/${referralCode.trim()}';
      _logDebug('QR code URL: $qrCodeUrl');

      return Image.network(
        qrCodeUrl,
        headers: {
          'Authorization': 'Bearer $token',
        },
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) {
            _logDebug('QR code image loaded successfully');
            return child;
          }
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          _logDebug('Error loading QR code image: $error');
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(
                'Failed to load QR code',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _logDebug('Exception in getQRCodeImage: $e');
      return null;
    }
  }

  // Get QR code as base64 data
  Future<ReferralResult<String>> getQRCodeBase64(String referralCode) async {
    try {
      // Input validation
      if (referralCode.trim().isEmpty) {
        return ReferralResult.error('Referral code is required');
      }
      
      // Basic format validation (alphanumeric with length check)
      if (!RegExp(r'^[a-zA-Z0-9]{6,20}$').hasMatch(referralCode.trim())) {
        return ReferralResult.error('Invalid referral code format');
      }
      
      _logDebug('Fetching QR code base64');
      final token = await _getAuthToken();
      if (token == null) {
        return ReferralResult.error('Authentication token not found. Please log in again.');
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/qrcode/referral/${referralCode.trim()}/base64'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timed out'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          final base64Data = responseData['data']['qrCodeBase64'];
          _logDebug('Successfully received QR code base64 data');
          return ReferralResult.success(base64Data);
        } else {
          final message = responseData['message'] ?? 'Failed to load QR code';
          _logDebug('API returned error for QR code base64: $message');
          return ReferralResult.error(message);
        }
      } else {
        _logDebug('HTTP error in QR code base64: ${response.statusCode}');
        return ReferralResult.error('Failed to load QR code: ${response.statusCode}');
      }
    } catch (e) {
      _logDebug('Exception in getQRCodeBase64: $e');
      if (e.toString().contains('timed out')) {
        return ReferralResult.error('Request timed out. Please check your connection and try again.');
      }
      return ReferralResult.error('An error occurred: ${e.toString()}');
    }
  }

  // Handle referral code submission
  Future<ReferralResult<bool>> submitReferralCode(String referralCode) async {
    try {
      // Input validation
      if (referralCode.trim().isEmpty) {
        return ReferralResult.error('Referral code is required');
      }
      
      // Basic format validation (alphanumeric with length check)
      if (!RegExp(r'^[a-zA-Z0-9]{6,20}$').hasMatch(referralCode.trim())) {
        return ReferralResult.error('Invalid referral code format');
      }
      
      _logDebug('Submitting referral code');
      final token = await _getAuthToken();
      if (token == null) {
        return ReferralResult.error('Authentication token not found. Please log in again.');
      }

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/service-provider/referral'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'referralCode': referralCode.trim()
        }),
      );

      _logDebug('Submit referral response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 200) {
          _logDebug('Referral code submitted successfully');
          return ReferralResult.success(true);
        } else {
          final message = responseData['message'] ?? 'Failed to submit referral code';
          _logDebug('API returned error for submit: $message');
          return ReferralResult.error(message);
        }
      } else if (response.statusCode == 400) {
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ?? 'Invalid referral code';
          _logDebug('Invalid referral submission: $errorMessage');
          return ReferralResult.error(errorMessage);
        } catch (e) {
          return ReferralResult.error('Invalid referral code');
        }
      } else {
        _logDebug('HTTP error in submit: ${response.statusCode}');
        return ReferralResult.error('Failed to submit referral code: ${response.statusCode}');
      }
    } catch (e) {
      _logDebug('Exception in submitReferralCode: $e');
      return ReferralResult.error('An error occurred while submitting the code. Please try again.');
    }
  }

  // Get full referral link
  String getReferralLink(String referralCode) {
    // Input validation
    if (referralCode.trim().isEmpty) {
      return '';
    }
    
    // Basic format validation (alphanumeric with length check)
    if (!RegExp(r'^[a-zA-Z0-9]{6,20}$').hasMatch(referralCode.trim())) {
      return '';
    }
    
    return 'https://barrim.com/code?v=${referralCode.trim()}';
  }
}