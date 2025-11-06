// lib/services/service_provider_subscription_service.dart
// This service handles service provider subscription requests with Whish Money payment integration
//
// Whish Money Payment Integration:
// - The backend creates a Whish payment and returns collectUrl and externalId
// - The frontend receives the payment URL (collectUrl) from the backend after creating a subscription request
// - Users are redirected to Whish payment page to complete payment
// - After payment, Whish redirects back to the app via deep linking
//
// IMPORTANT: Backend Configuration for CreateServiceProviderSubscription
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
      final url = '$_baseUrl$_apiPrefix/subscription-plans';
      
      print('🟢 Service Provider Subscription Service: Fetching plans from: $url');
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );

      print('🟢 Service Provider Subscription Service: Response status: ${response.statusCode}');
      print('🟢 Service Provider Subscription Service: Response body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> plansData = responseData['data'] ?? [];
        
        print('🟢 Service Provider Subscription Service: Found ${plansData.length} plans');
        
        final List<SubscriptionPlan> plans = plansData.map((plan) {
          try {
            final parsedPlan = SubscriptionPlan.fromJson(plan);
            print('🟢 Parsed plan: ${parsedPlan.title}, ID: ${parsedPlan.id}, Price: ${parsedPlan.price}');
            return parsedPlan;
          } catch (e) {
            print('❌ Error parsing plan: $e, JSON: $plan');
            rethrow;
          }
        }).toList();

        print('🟢 Service Provider Subscription Service: Successfully parsed ${plans.length} plans');

        return ApiResponse<List<SubscriptionPlan>>(
          success: true,
          data: plans,
          message: responseData['message'] ?? 'Subscription plans retrieved successfully',
        );
      } else {
        print('❌ Service Provider Subscription Service: Request failed with status ${response.statusCode}');
        return ApiResponse<List<SubscriptionPlan>>(
          success: false,
          message: responseData['message'] ?? 'Failed to get subscription plans',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('❌ Service Provider Subscription Service: Exception: $e');
      return ApiResponse<List<SubscriptionPlan>>(
        success: false,
        message: 'Failed to retrieve subscription plans: $e',
      );
    }
  }

  /// Create a new service provider subscription request with Whish payment integration
  /// This matches the backend CreateServiceProviderSubscription implementation
  /// The backend creates a Whish payment and returns collectUrl for payment completion
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
      final uri = Uri.parse('$_baseUrl$_apiPrefix/subscription-requests');

      // Prepare fields with sanitized inputs (backend expects planId in form data)
      Map<String, String> fields = {
        'planId': planId.trim(),
      };

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add image if provided (optional - Whish payment doesn't require image)
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
      print('🟢 Service Provider Subscription Service: CreateServiceProviderSubscription Response Status: ${response.statusCode}');
      print('🟢 Service Provider Subscription Service: Response Body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);

      // Handle 409 Conflict - already has pending subscription request
      if (response.statusCode == 409) {
        return ApiResponse<SubscriptionRequest>(
          success: false,
          message: responseData['message'] ?? 'You already have a pending subscription request. Please complete the payment first.',
          statusCode: response.statusCode,
        );
      }

      // Handle 201 Created - successful payment initiation
      if (response.statusCode == 201) {
        final data = responseData['data'];
        if (data == null) {
          return ApiResponse<SubscriptionRequest>(
            success: false,
            message: 'No data received from server',
            statusCode: response.statusCode,
          );
        }
        
        // Backend returns: requestId, plan, status, submittedAt, paymentAmount, collectUrl, externalId
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
          companyId: null, // Service provider subscription doesn't have companyId
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
      } else {
        return ApiResponse<SubscriptionRequest>(
          success: false,
          message: responseData['message'] ?? 'Failed to create subscription request',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('❌ Service Provider Subscription Service: Exception in createSubscriptionRequest: $e');
      return ApiResponse<SubscriptionRequest>(
        success: false,
        message: 'Failed to create subscription request: ${e.toString()}',
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

  /// Check Whish account balance (via backend)
  /// Returns the account balance in the response data
  static Future<ApiResponse<double>> checkWhishAccountBalance() async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl$_apiPrefix/payment/whish/balance';
      
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

  /// Format subscription price
  static String formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return '\$${price.round()}';
    } else {
      return '\$${price.toStringAsFixed(2)}';
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