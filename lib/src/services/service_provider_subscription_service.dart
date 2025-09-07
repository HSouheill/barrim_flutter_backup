// lib/services/service_provider_subscription_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import '../models/api_response.dart';
import '../models/subscription.dart';
import '../utils/token_storage.dart';

class ServiceProviderSubscriptionService {
  static final TokenStorage _tokenStorage = TokenStorage();
  static const String _baseUrl = ApiService.baseUrl; // Replace with your actual API base URL
  static const String _apiPrefix = '/api/service-providers';

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

  // Helper method to make multipart requests with custom client
  static Future<http.StreamedResponse> _makeMultipartRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    final client = await _getCustomClient();
    
    final request = http.MultipartRequest(method, uri);
    
    // Add headers
    if (headers != null) {
      request.headers.addAll(headers);
    }
    
    // Add fields
    if (fields != null) {
      request.fields.addAll(fields);
    }
    
    // Add files
    if (files != null) {
      request.files.addAll(files);
    }
    
    return await client.send(request);
  }

  // Get authorization header with JWT token and security headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'User-Agent': 'Barrim-Mobile-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
  }

  // Get multipart headers with JWT token and security headers
  static Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _tokenStorage.getToken();
    return {
      'Authorization': 'Bearer $token',
      'User-Agent': 'Barrim-Mobile-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
  }

  /// Get all available subscription plans for service providers
  static Future<ApiResponse<List<SubscriptionPlan>>> getSubscriptionPlans() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$_baseUrl$_apiPrefix/subscription-plans'),
        headers: headers,
      );

      // Response logged without sensitive data

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> plansData = responseData['data'] ?? [];
        final List<SubscriptionPlan> plans = plansData
            .map((plan) => SubscriptionPlan.fromJson(plan))
            .toList();

        return ApiResponse<List<SubscriptionPlan>>(
          success: true,
          data: plans,
          message: responseData['message'] ?? 'Subscription plans retrieved successfully',
        );
      } else {
        return ApiResponse<List<SubscriptionPlan>>(
          success: false,
          message: responseData['message'] ?? 'Failed to get subscription plans',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<List<SubscriptionPlan>>(
        success: false,
        message: 'Failed to retrieve subscription plans',
      );
    }
  }

  /// Create a new subscription request
  static Future<ApiResponse<SubscriptionRequest>> createSubscriptionRequest({
    required String planId,
    File? paymentProofImage,
  }) async {
    try {
      // Input validation
      if (planId.trim().isEmpty) {
        throw Exception('Plan ID is required');
      }
      
      // Basic ID format validation (assuming MongoDB ObjectId format)
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(planId.trim())) {
        throw Exception('Invalid plan ID format');
      }
      
      // Validate payment proof image if provided
      if (paymentProofImage != null) {
        if (!await paymentProofImage.exists()) {
          throw Exception('Payment proof image file does not exist');
        }
        
        final fileSize = await paymentProofImage.length();
        if (fileSize > 5 * 1024 * 1024) { // 5MB limit
          throw Exception('Payment proof image is too large. Maximum size is 5MB');
        }
        
        final fileExtension = paymentProofImage.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
          throw Exception('Invalid file format. Only JPG, PNG, and GIF are allowed');
        }
      }
      
      final headers = await _getMultipartHeaders();
      final uri = Uri.parse('$_baseUrl$_apiPrefix/subscription-requests');

      // Prepare fields with sanitized inputs
      Map<String, String> fields = {
        'planId': planId.trim(),
      };

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add image if provided
      if (paymentProofImage != null) {
        final imageStream = http.ByteStream(paymentProofImage.openRead());
        final imageLength = await paymentProofImage.length();
        final multipartFile = http.MultipartFile(
          'image',
          imageStream,
          imageLength,
          filename: paymentProofImage.path.split('/').last,
        );
        files.add(multipartFile);
      }

      // Creating subscription request

      // Send the request using custom client
      final streamedResponse = await _makeMultipartRequest(
        'POST',
        uri,
        headers: headers,
        fields: fields,
        files: files,
      );
      
      final response = await http.Response.fromStream(streamedResponse);

      // Response logged without sensitive data

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        final SubscriptionRequest subscriptionRequest =
        SubscriptionRequest.fromJson(responseData['data']);

        return ApiResponse<SubscriptionRequest>(
          success: true,
          data: subscriptionRequest,
          message: responseData['message'] ?? 'Subscription request created successfully',
        );
      } else {
        return ApiResponse<SubscriptionRequest>(
          success: false,
          message: responseData['message'] ?? 'Failed to create subscription request',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<SubscriptionRequest>(
        success: false,
        message: 'Failed to create subscription request',
      );
    }
  }

  /// Get remaining time for current subscription
  static Future<ApiResponse<Map<String, dynamic>>> getSubscriptionTimeRemaining() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$_baseUrl$_apiPrefix/subscription/remaining-time'),
        headers: headers,
      );

      // Response logged without sensitive data

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Transform the response to match the expected structure
        final data = responseData['data'] as Map<String, dynamic>?;
        if (data != null) {
          // The API returns the data directly, so we need to wrap it properly
          final transformedData = {
            'hasActiveSubscription': data['hasActiveSubscription'] ?? false,
            'remainingTime': data['remainingTime'] ?? null,
          };
          
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            data: transformedData,
            message: responseData['message'] ?? 'Subscription time remaining retrieved successfully',
          );
        }
        
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: data,
          message: responseData['message'] ?? 'Subscription time remaining retrieved successfully',
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: responseData['message'] ?? 'Failed to get subscription time remaining',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Failed to retrieve subscription time remaining',
      );
    }
  }

  /// Get current active subscription details
  static Future<ApiResponse<Map<String, dynamic>>> getCurrentSubscription() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$_baseUrl$_apiPrefix/subscription/current'),
        headers: headers,
      );

      // Response logged without sensitive data

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: responseData['data'],
          message: responseData['message'] ?? 'Current subscription retrieved successfully',
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: responseData['message'] ?? 'Failed to get current subscription',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Failed to retrieve current subscription',
      );
    }
  }

  /// Cancel current active subscription
  static Future<ApiResponse<String>> cancelSubscription() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'POST',
        Uri.parse('$_baseUrl$_apiPrefix/subscription/cancel'),
        headers: headers,
      );

      // Response logged without sensitive data

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<String>(
          success: true,
          data: 'Subscription cancelled successfully',
          message: responseData['message'] ?? 'Subscription cancelled successfully',
        );
      } else {
        return ApiResponse<String>(
          success: false,
          message: responseData['message'] ?? 'Failed to cancel subscription',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        message: 'Failed to cancel subscription',
      );
    }
  }

  /// Get subscription status with comprehensive information
  static Future<ApiResponse<SubscriptionStatus>> getSubscriptionStatus() async {
    try {
      // Get both current subscription and time remaining
      final currentSubscriptionResponse = await getCurrentSubscription();
      final timeRemainingResponse = await getSubscriptionTimeRemaining();

      if (currentSubscriptionResponse.success && timeRemainingResponse.success) {
        final currentData = currentSubscriptionResponse.data;
        final timeData = timeRemainingResponse.data;

        SubscriptionStatus status = SubscriptionStatus(
          hasActiveSubscription: timeData?['isActive'] ?? false,
          remainingDays: timeData?['remainingDays'] ?? 0,
          endDate: timeData?['endDate'] != null
              ? DateTime.parse(timeData!['endDate'])
              : null,
          subscription: currentData?['subscription'] != null
              ? CompanySubscription.fromJson(currentData!['subscription'])
              : null,
          plan: currentData?['plan'] != null
              ? SubscriptionPlan.fromJson(currentData!['plan'])
              : null,
        );

        return ApiResponse<SubscriptionStatus>(
          success: true,
          data: status,
          message: 'Subscription status retrieved successfully',
        );
      } else {
        return ApiResponse<SubscriptionStatus>(
          success: false,
          message: 'Failed to get subscription status',
        );
      }
    } catch (e) {
      return ApiResponse<SubscriptionStatus>(
        success: false,
        message: 'Failed to retrieve subscription status',
      );
    }
  }

  /// Format remaining days to human readable format
  static String formatRemainingTime(int remainingDays) {
    if (remainingDays <= 0) {
      return 'Expired';
    } else if (remainingDays == 1) {
      return '1 day remaining';
    } else if (remainingDays < 30) {
      return '$remainingDays days remaining';
    } else {
      final months = remainingDays ~/ 30;
      final days = remainingDays % 30;
      if (days == 0) {
        return months == 1 ? '1 month remaining' : '$months months remaining';
      } else {
        return '$months month${months > 1 ? 's' : ''} and $days day${days > 1 ? 's' : ''} remaining';
      }
    }
  }

  /// Check if subscription is about to expire (within 7 days)
  static bool isSubscriptionExpiringSoon(int remainingDays) {
    return remainingDays > 0 && remainingDays <= 7;
  }

  /// Get subscription expiry warning message
  static String? getExpiryWarningMessage(int remainingDays) {
    if (remainingDays <= 0) {
      return 'Your subscription has expired. Please renew to continue using our services.';
    } else if (remainingDays <= 3) {
      return 'Your subscription expires in $remainingDays day${remainingDays > 1 ? 's' : ''}. Renew now to avoid service interruption.';
    } else if (remainingDays <= 7) {
      return 'Your subscription expires in $remainingDays days. Consider renewing soon.';
    }
    return null;
  }
}

/// Helper class to represent comprehensive subscription status
class SubscriptionStatus {
  final bool hasActiveSubscription;
  final int remainingDays;
  final DateTime? endDate;
  final CompanySubscription? subscription;
  final SubscriptionPlan? plan;

  SubscriptionStatus({
    required this.hasActiveSubscription,
    required this.remainingDays,
    this.endDate,
    this.subscription,
    this.plan,
  });

  bool get isExpired => remainingDays <= 0;
  bool get isExpiringSoon => remainingDays > 0 && remainingDays <= 7;

  String get statusText {
    if (isExpired) return 'Expired';
    if (isExpiringSoon) return 'Expiring Soon';
    if (hasActiveSubscription) return 'Active';
    return 'No Subscription';
  }
}