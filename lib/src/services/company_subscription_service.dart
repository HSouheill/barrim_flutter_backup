// lib/services/company_subscription_service.dart
// This service ensures all API calls use HTTPS for security
import 'dart:convert';
import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';
import '../models/subscription.dart';
import '../models/api_response.dart';
import '../utils/token_storage.dart';

class CompanySubscriptionService {
  static final TokenStorage _tokenStorage = TokenStorage();
  static const String _baseUrl = ApiService.baseUrl; // TODO: Move to api_constants.dart
  static const String _subscriptionEndpoint = '/api/companies';

  // Validate that all URLs are using HTTPS
  static bool _validateHttpsUrl(String url) {
    if (!url.startsWith('https://')) {
      print('CompanySubscriptionService: WARNING - Non-HTTPS URL detected: $url');
      return false;
    }
    return true;
  }

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

  // Get authentication headers with security headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenStorage.getToken();
    
    // Validate token format
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token is missing or empty');
    }
    
    // Basic JWT format validation (should have 3 parts separated by dots)
    if (!token.contains('.') || token.split('.').length != 3) {
      throw Exception('Invalid token format. Expected JWT format: header.payload.signature');
    }
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'User-Agent': 'Barrim-Mobile-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
  }

  // Get multipart headers for file uploads with security headers
  static Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _tokenStorage.getToken();
    
    // Validate token format
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token is missing or empty');
    }
    
    // Basic JWT format validation (should have 3 parts separated by dots)
    if (!token.contains('.') || token.split('.').length != 3) {
      throw Exception('Invalid token format. Expected JWT format: header.payload.signature');
    }
    
    return {
      'Authorization': 'Bearer $token',
      'User-Agent': 'Barrim-Mobile-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
  }

  /// Get all available subscription plans for companies
  static Future<ApiResponse<List<SubscriptionPlan>>> getSubscriptionPlans() async {
    try {
      final headers = await _getHeaders();
      
      final url = '$_baseUrl$_subscriptionEndpoint/subscription-plans';
      
      // Ensure HTTPS is being used
      if (!_validateHttpsUrl(url)) {
        throw Exception('Cannot get subscription plans with non-HTTPS URL');
      }
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );
      
      // Response logged without sensitive data

      try {
        final responseData = json.decode(response.body);

        if (response.statusCode == 200) {
          final List<dynamic> plansJson = responseData['data'] ?? [];
          
          final plans = plansJson.map((json) {
            return SubscriptionPlan.fromJson(json);
          }).toList();

          return ApiResponse<List<SubscriptionPlan>>(
            success: true,
            message: responseData['message'] ?? 'Subscription plans retrieved successfully',
            data: plans,
          );
        } else {
          return ApiResponse<List<SubscriptionPlan>>(
            success: false,
            message: responseData['message'] ?? 'Failed to retrieve subscription plans',
            statusCode: response.statusCode,
          );
        }
      } catch (parseError) {
        throw Exception('Failed to parse subscription plans response');
      }
    } catch (e) {
      return ApiResponse<List<SubscriptionPlan>>(
        success: false,
        message: 'Failed to retrieve subscription plans',
      );
    }
  }

  /// Create a subscription request with optional payment proof image
  static Future<ApiResponse<SubscriptionRequest>> createSubscriptionRequest({
    required String planId,
    required String branchId,
    File? paymentProofImage,
  }) async {
    try {
      // Input validation
      if (planId.trim().isEmpty) {
        throw Exception('Plan ID is required');
      }
      if (branchId.trim().isEmpty) {
        throw Exception('Branch ID is required');
      }
      
      // Basic ID format validation (assuming MongoDB ObjectId format)
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(planId.trim())) {
        throw Exception('Invalid plan ID format');
      }
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(branchId.trim())) {
        throw Exception('Invalid branch ID format');
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
      final url = '$_baseUrl$_subscriptionEndpoint/subscription/$branchId/request';
      
      // Ensure HTTPS is being used
      if (!_validateHttpsUrl(url)) {
        throw Exception('Cannot create subscription request with non-HTTPS URL');
      }
      
      final uri = Uri.parse(url);

      // Prepare fields with sanitized inputs
      Map<String, String> fields = {
        'planId': planId.trim(),
        'branchId': branchId.trim(),
      };

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add image if provided
      if (paymentProofImage != null) {
        final imageExtension = paymentProofImage.path.split('.').last.toLowerCase();
        final mimeType = _getMimeType(imageExtension);

        var imageFile = await http.MultipartFile.fromPath(
          'image',
          paymentProofImage.path,
          contentType: MediaType.parse(mimeType),
        );
        files.add(imageFile);
      }

      // Send the request using custom client
      final streamedResponse = await _makeMultipartRequest(
        'POST',
        uri,
        headers: headers,
        fields: fields,
        files: files,
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        final subscriptionRequest = SubscriptionRequest.fromJson(responseData['data']);
        return ApiResponse<SubscriptionRequest>(
          success: true,
          message: responseData['message'] ?? 'Subscription request created successfully',
          data: subscriptionRequest,
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

  /// Get current active subscription
  static Future<ApiResponse<CurrentSubscriptionData?>> getCurrentSubscription({required String branchId}) async {
    try {
      // Input validation
      if (branchId.trim().isEmpty) {
        throw Exception('Branch ID is required');
      }
      
      // Basic ID format validation (assuming MongoDB ObjectId format)
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(branchId.trim())) {
        throw Exception('Invalid branch ID format');
      }
      
      final headers = await _getHeaders();
      final url = '$_baseUrl$_subscriptionEndpoint/subscription/request/$branchId/status';
      
      // Ensure HTTPS is being used
      if (!_validateHttpsUrl(url)) {
        throw Exception('Cannot get current subscription with non-HTTPS URL');
      }
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        CurrentSubscriptionData? subscriptionData;
        if (responseData['data'] != null) {
          subscriptionData = CurrentSubscriptionData.fromJson(responseData['data']);
        }

        return ApiResponse<CurrentSubscriptionData?>(
          success: true,
          message: responseData['message'] ?? 'Current subscription retrieved successfully',
          data: subscriptionData,
        );
      } else {
        return ApiResponse<CurrentSubscriptionData?>(
          success: false,
          message: responseData['message'] ?? 'Failed to retrieve current subscription',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<CurrentSubscriptionData?>(
        success: false,
        message: 'Failed to retrieve current subscription',
      );
    }
  }

  /// Get subscription remaining time
  static Future<ApiResponse<SubscriptionRemainingTimeData>> getSubscriptionRemainingTime({required String branchId}) async {
    try {
      // Input validation
      if (branchId.trim().isEmpty) {
        throw Exception('Branch ID is required');
      }
      
      // Basic ID format validation (assuming MongoDB ObjectId format)
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(branchId.trim())) {
        throw Exception('Invalid branch ID format');
      }
      
      final headers = await _getHeaders();
      final url = '$_baseUrl$_subscriptionEndpoint/subscription/$branchId/remaining-time';
      
      // Ensure HTTPS is being used
      if (!_validateHttpsUrl(url)) {
        throw Exception('Cannot get subscription remaining time with non-HTTPS URL');
      }
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final remainingTimeData = SubscriptionRemainingTimeData.fromJson(responseData['data']);

        return ApiResponse<SubscriptionRemainingTimeData>(
          success: true,
          message: responseData['message'] ?? 'Subscription remaining time retrieved successfully',
          data: remainingTimeData,
        );
      } else {
        return ApiResponse<SubscriptionRemainingTimeData>(
          success: false,
          message: responseData['message'] ?? 'Failed to retrieve subscription remaining time',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<SubscriptionRemainingTimeData>(
        success: false,
        message: 'Failed to retrieve subscription remaining time',
      );
    }
  }

  /// Cancel active subscription
  static Future<ApiResponse<void>> cancelSubscription({required String branchId}) async {
    try {
      // Input validation
      if (branchId.trim().isEmpty) {
        throw Exception('Branch ID is required');
      }
      
      // Basic ID format validation (assuming MongoDB ObjectId format)
      if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(branchId.trim())) {
        throw Exception('Invalid branch ID format');
      }
      
      final headers = await _getHeaders();
      final url = '$_baseUrl$_subscriptionEndpoint/subscription/$branchId/cancel';
      
      // Ensure HTTPS is being used
      if (!_validateHttpsUrl(url)) {
        throw Exception('Cannot cancel subscription with non-HTTPS URL');
      }
      
      final response = await _makeRequest(
        'POST',
        Uri.parse(url),
        headers: headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<void>(
          success: true,
          message: responseData['message'] ?? 'Subscription cancelled successfully',
        );
      } else {
        return ApiResponse<void>(
          success: false,
          message: responseData['message'] ?? 'Failed to cancel subscription',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        message: 'Failed to cancel subscription',
      );
    }
  }

  /// Check if company has active subscription
  static Future<bool> hasActiveSubscription({required String branchId}) async {
    try {
      final response = await getSubscriptionRemainingTime(branchId: branchId);
      if (response.success && response.data != null) {
        return response.data!.hasActiveSubscription ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get subscription status summary
  static Future<ApiResponse<SubscriptionStatus>> getSubscriptionStatus({required String branchId}) async {
    try {
      final currentSubscriptionResponse = await getCurrentSubscription(branchId: branchId);
      final remainingTimeResponse = await getSubscriptionRemainingTime(branchId: branchId);

      if (currentSubscriptionResponse.success && remainingTimeResponse.success) {
        final hasActive = remainingTimeResponse.data?.hasActiveSubscription ?? false;
        final subscription = currentSubscriptionResponse.data?.subscription;
        final plan = currentSubscriptionResponse.data?.plan;
        final remainingTime = remainingTimeResponse.data?.remainingTime;

        final status = SubscriptionStatus(
          hasActiveSubscription: hasActive,
          subscription: subscription,
          plan: plan,
          remainingTime: remainingTime,
          isExpired: hasActive ? false : (subscription != null),
          daysRemaining: remainingTime?.days ?? 0,
        );

        return ApiResponse<SubscriptionStatus>(
          success: true,
          message: 'Subscription status retrieved successfully',
          data: status,
        );
      } else {
        return ApiResponse<SubscriptionStatus>(
          success: false,
          message: 'Failed to retrieve subscription status',
        );
      }
    } catch (e) {
      return ApiResponse<SubscriptionStatus>(
        success: false,
        message: 'Failed to retrieve subscription status',
      );
    }
  }

  /// Helper method to get MIME type for images
  static String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Validate image file
  static bool isValidImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    const validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    return validExtensions.contains(extension);
  }

  /// Format subscription duration
  static String formatDuration(int days) {
    if (days < 7) {
      return '$days day${days == 1 ? '' : 's'}';
    } else if (days < 30) {
      final weeks = (days / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'}';
    } else if (days < 365) {
      final months = (days / 30).floor();
      return '$months month${months == 1 ? '' : 's'}';
    } else {
      final years = (days / 365).floor();
      return '$years year${years == 1 ? '' : 's'}';
    }
  }

  /// Format subscription price
  static String formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return '\$${price.round()}';
    } else {
      return '\$${price.toStringAsFixed(2)}';
    }
  }
}

/// Additional model for subscription status summary
class SubscriptionStatus {
  final bool hasActiveSubscription;
  final CompanySubscription? subscription;
  final SubscriptionPlan? plan;
  final SubscriptionRemainingTime? remainingTime;
  final bool isExpired;
  final int daysRemaining;

  SubscriptionStatus({
    required this.hasActiveSubscription,
    this.subscription,
    this.plan,
    this.remainingTime,
    required this.isExpired,
    required this.daysRemaining,
  });

  bool get isActive => hasActiveSubscription && !isExpired;
  bool get isExpiringSoon => daysRemaining <= 7 && daysRemaining > 0;

  String get statusText {
    if (isActive) {
      if (isExpiringSoon) {
        return 'Expiring Soon';
      }
      return 'Active';
    } else if (isExpired) {
      return 'Expired';
    } else {
      return 'No Subscription';
    }
  }
}