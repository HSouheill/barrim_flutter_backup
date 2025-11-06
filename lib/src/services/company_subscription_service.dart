// lib/services/company_subscription_service.dart
//
// Whish Money Payment Integration:
// - The backend should be configured to use Whish Money API for payment processing
// - For testing: Configure backend to use https://api.sandbox.whish.money/itel-service/api/
// - For production: Configure backend to use https://whish.money/itel-service/api/
// - The frontend receives the payment URL (collectUrl) from the backend after creating a subscription request
// - Currently using sandbox/testing API for development
//
// Backend Whish API Headers Required:
//   channel: "10196975"
//   secret: "024709627da343afbcd5278a5fea819e"
//   websiteurl: "barrim.com" (CRITICAL: Use domain only, NOT "https://barrim.com")
//   Content-Type: "application/json"
// See ApiConstants.getWhishHeaders() for reference implementation
//
// IMPORTANT: If backend receives "auth.session_not_exist" error:
// 1. Check websiteurl format - should be "barrim.com" not "https://barrim.com"
// 2. Verify credentials with Whish support
// 3. Ensure Whish account is active and properly configured
//
// IMPORTANT: Backend Configuration for CreateBranchSubscriptionRequest
// Deep Linking for Payment Redirects:
// When creating a Whish payment for subscription requests, the backend MUST use these redirect URLs:
// - Success: barrim://payment-success?requestId={requestId}
// - Failure: barrim://payment-failed?requestId={requestId}
// Alternative (will also work): https://barrim.online/payment-success?requestId={requestId}
// See ApiConstants.getPaymentSuccessUrl() and getPaymentFailedUrl() for helper functions
// The frontend deep link handler in main.dart will automatically catch these URLs and navigate
// users back to their subscription page after payment completion.
//
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
  static const String _baseUrl = ApiService.baseUrl; 
  static const String _subscriptionEndpoint = '/api/companies';

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
      
      print('🔵 Company Subscription Service: Fetching plans from: $url');
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );
      
      print('🔵 Company Subscription Service: Response status: ${response.statusCode}');
      print('🔵 Company Subscription Service: Response body: ${response.body}');

      try {
        final responseData = json.decode(response.body);

        if (response.statusCode == 200) {
          final List<dynamic> plansJson = responseData['data'] ?? [];
          
          print('🔵 Company Subscription Service: Found ${plansJson.length} plans');
          
          final plans = plansJson.map((json) {
            try {
              final plan = SubscriptionPlan.fromJson(json);
              print('🔵 Parsed plan: ${plan.title}, ID: ${plan.id}, Price: ${plan.price}');
              return plan;
            } catch (e) {
              print('❌ Error parsing plan: $e, JSON: $json');
              rethrow;
            }
          }).toList();

          print('🔵 Company Subscription Service: Successfully parsed ${plans.length} plans');
          
          return ApiResponse<List<SubscriptionPlan>>(
            success: true,
            message: responseData['message'] ?? 'Subscription plans retrieved successfully',
            data: plans,
          );
        } else {
          print('❌ Company Subscription Service: Request failed with status ${response.statusCode}');
          return ApiResponse<List<SubscriptionPlan>>(
            success: false,
            message: responseData['message'] ?? 'Failed to retrieve subscription plans',
            statusCode: response.statusCode,
          );
        }
      } catch (parseError) {
        print('❌ Company Subscription Service: Parse error: $parseError');
        print('❌ Response body was: ${response.body}');
        return ApiResponse<List<SubscriptionPlan>>(
          success: false,
          message: 'Failed to parse subscription plans response: $parseError',
        );
      }
    } catch (e) {
      print('❌ Company Subscription Service: Exception: $e');
      return ApiResponse<List<SubscriptionPlan>>(
        success: false,
        message: 'Failed to retrieve subscription plans: $e',
      );
    }
  }

  /// Create a branch subscription request with Whish payment integration
  /// This matches the backend CreateBranchSubscriptionRequest implementation
  /// The backend creates a Whish payment and returns collectUrl for payment completion
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
      
      // Validate payment proof image if provided (optional for Whish payment flow)
      if (paymentProofImage != null) {
        if (!await paymentProofImage.exists()) {
          throw Exception('Payment proof image file does not exist');
        }
        
        final fileSize = await paymentProofImage.length();
        if (fileSize > 10 * 1024 * 1024) { // 10MB limit (matching backend)
          throw Exception('Payment proof image is too large. Maximum size is 10MB');
        }
        
        final fileExtension = paymentProofImage.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
          throw Exception('Invalid file format. Only JPG, PNG, and GIF are allowed');
        }
      }
      
      final headers = await _getMultipartHeaders();
      // Backend endpoint: branchId is in URL path, planId is in form data
      // Note: Endpoint may vary based on backend routing - update if backend uses different path
      final url = '$_baseUrl$_subscriptionEndpoint/subscription/$branchId/request';
      
      final uri = Uri.parse(url);

      // Prepare fields with sanitized inputs (backend expects planId in form data)
      Map<String, String> fields = {
        'planId': planId.trim(),
      };

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add image if provided (optional - Whish payment doesn't require image)
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
      
      // Log response for debugging
      print('🔵 Company Subscription Service: CreateBranchSubscriptionRequest Response Status: ${response.statusCode}');
      print('🔵 Company Subscription Service: Response Body: ${response.body}');
      
      final responseData = json.decode(response.body);

      // Handle 409 Conflict - already has pending subscription request
      if (response.statusCode == 409) {
        return ApiResponse<SubscriptionRequest>(
          success: false,
          message: responseData['message'] ?? 'You already have a pending subscription request for this branch. Please complete the payment first.',
          statusCode: response.statusCode,
        );
      }

      // Handle 201 Created - successful payment initiation
      if (response.statusCode == 201) {
        // Backend returns: requestId, plan, status, submittedAt, paymentAmount, collectUrl, externalId
        final data = responseData['data'];
        
        if (data == null) {
          return ApiResponse<SubscriptionRequest>(
            success: false,
            message: 'No data received from server',
            statusCode: response.statusCode,
          );
        }
        
        // Parse the response data - backend returns requestId (not id), submittedAt (not requestedAt)
        final requestId = data['requestId']?.toString() ?? data['id']?.toString();
        final planData = data['plan'];
        final status = data['status']?.toString() ?? 'pending_payment';
        final submittedAt = data['submittedAt'] ?? data['requestedAt'];
        final collectUrl = data['collectUrl']?.toString();
        final externalId = data['externalId'];
        // paymentAmount is available in response but not needed for SubscriptionRequest model
        
        // Parse planId from plan data if available, otherwise use provided planId
        String? parsedPlanId;
        if (planData != null && planData is Map) {
          parsedPlanId = planData['id']?.toString() ?? planData['_id']?.toString();
        }
        
        // Parse dates
        DateTime? requestedAt;
        if (submittedAt != null) {
          try {
            if (submittedAt is String) {
              requestedAt = DateTime.parse(submittedAt);
            } else if (submittedAt is int) {
              requestedAt = DateTime.fromMillisecondsSinceEpoch(submittedAt);
            }
          } catch (e) {
            print('⚠️ Error parsing submittedAt: $e');
          }
        }
        
        // Parse externalId (can be int or string)
        int? parsedExternalId;
        if (externalId != null) {
          if (externalId is int) {
            parsedExternalId = externalId;
          } else if (externalId is String) {
            parsedExternalId = int.tryParse(externalId);
          } else if (externalId is num) {
            parsedExternalId = externalId.toInt();
          }
        }
        
        // Create subscription request object with all payment data
        final subscriptionRequest = SubscriptionRequest(
          id: requestId,
          companyId: null, // Branch subscription doesn't have companyId
          planId: parsedPlanId ?? planId.trim(),
          status: status,
          adminId: null,
          adminNote: null,
          requestedAt: requestedAt ?? DateTime.now(),
          processedAt: null,
          imagePath: null,
          collectUrl: collectUrl,
          externalId: parsedExternalId,
          paymentStatus: status == 'pending_payment' ? 'pending' : (data['paymentStatus']?.toString() ?? 'pending'),
          paidAt: null,
        );
        
        return ApiResponse<SubscriptionRequest>(
          success: true,
          message: responseData['message'] ?? 'Payment initiated successfully. Please complete the payment to activate your subscription.',
          data: subscriptionRequest,
        );
      } 
      
      // Handle other error status codes
      return ApiResponse<SubscriptionRequest>(
        success: false,
        message: responseData['message'] ?? 'Failed to create subscription request',
        statusCode: response.statusCode,
      );
    } catch (e) {
      print('❌ Company Subscription Service: Exception in createSubscriptionRequest: $e');
      return ApiResponse<SubscriptionRequest>(
        success: false,
        message: 'Failed to create subscription request: ${e.toString()}',
      );
    }
  }

  /// Check Whish account balance (via backend)
  /// Returns the account balance in the response data
  static Future<ApiResponse<double>> checkWhishAccountBalance() async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl$_subscriptionEndpoint/payment/whish/balance';
      
      final uri = Uri.parse(url);
      final response = await _makeRequest('GET', uri, headers: headers);
      final responseData = json.decode(response.body);
      
      if (response.statusCode == 200) {
        // Backend should return balance in response.data
        final balance = responseData['data'] is num 
            ? (responseData['data'] as num).toDouble()
            : (responseData['data']?['balance'] is num 
                ? (responseData['data']['balance'] as num).toDouble()
                : null);
        
        if (balance != null) {
          return ApiResponse<double>(
            success: true,
            message: responseData['message'] ?? 'Balance retrieved successfully',
            data: balance,
          );
        } else {
          return ApiResponse<double>(
            success: false,
            message: 'Invalid balance data received from server',
          );
        }
      } else {
        return ApiResponse<double>(
          success: false,
          message: responseData['message'] ?? 'Failed to check account balance',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('Error checking Whish account balance: $e');
      return ApiResponse<double>(
        success: false,
        message: 'Failed to check account balance: ${e.toString()}',
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