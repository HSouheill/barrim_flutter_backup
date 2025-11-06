// services/wholesaler_subscription_service.dart
// This service handles wholesaler branch subscription requests with Whish Money payment integration
//
// Whish Money Payment Integration:
// - The backend creates a Whish payment and returns collectUrl and externalId
// - The frontend receives the payment URL (collectUrl) from the backend after creating a subscription request
// - Users are redirected to Whish payment page to complete payment
// - After payment, Whish redirects back to the app via deep linking
//
// IMPORTANT: Backend Configuration for CreateWholesalerSubscription
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
import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;
import '../models/api_response.dart';
import '../models/subscription.dart';
import '../utils/token_storage.dart';

// Custom exception for 409 Conflict errors
class ConflictException implements Exception {
  final String message;
  final int statusCode;
  
  ConflictException(this.message, this.statusCode);
  
  @override
  String toString() => 'ConflictException: $message (Status: $statusCode)';
}

class WholesalerSubscriptionService {
  static final WholesalerSubscriptionService _instance = WholesalerSubscriptionService._internal();
  factory WholesalerSubscriptionService() => _instance;
  WholesalerSubscriptionService._internal();

  // Replace with your actual base URL
  static const String baseUrl = ApiService.baseUrl;

  final TokenStorage _tokenStorage = TokenStorage();

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

  /// Get authorization headers with token and security headers
  Future<Map<String, String>> _getHeaders() async {
    try {
      final token = await _tokenStorage.getToken();
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ''}',
        'User-Agent': 'Barrim-Mobile-App/1.0',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      };
      
      return headers;
    } catch (e) {
      if (!kReleaseMode) {
        print('WholesalerSubscriptionService - Error getting headers: $e');
      }
      rethrow;
    }
  }

  /// Get multipart headers with token and security headers
  Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _tokenStorage.getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'User-Agent': 'Barrim-Mobile-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
  }

  /// Get available subscription plans for wholesalers
  ///
  /// Returns a list of available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final headers = await _getHeaders();
      
      final url = '$baseUrl/api/wholesaler/subscription-plans';
      
      print('🟡 Wholesaler Subscription Service: Fetching plans from: $url');
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );

      print('🟡 Wholesaler Subscription Service: Response status: ${response.statusCode}');
      print('🟡 Wholesaler Subscription Service: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> plansData = responseData['data'] ?? [];
        
        print('🟡 Wholesaler Subscription Service: Found ${plansData.length} plans');
        
        final plans = plansData.map((plan) {
          try {
            final parsedPlan = SubscriptionPlan.fromJson(plan);
            print('🟡 Parsed plan: ${parsedPlan.title}, ID: ${parsedPlan.id}, Price: ${parsedPlan.price}');
            return parsedPlan;
          } catch (e) {
            print('❌ Error parsing plan: $e, JSON: $plan');
            rethrow;
          }
        }).toList();
        
        print('🟡 Wholesaler Subscription Service: Successfully parsed ${plans.length} plans');
        
        return plans;
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final errorMessage = responseData['message'] ?? 'Failed to get available plans';
        print('❌ Wholesaler Subscription Service: Request failed with status ${response.statusCode}: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Wholesaler Subscription Service: Exception: $e');
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else {
        throw Exception('Failed to get available plans: $e');
      }
    }
  }

  /// Create a new wholesaler branch subscription request with Whish payment integration
  /// This matches the backend CreateBranchSubscriptionRequest implementation
  /// The backend creates a Whish payment and returns collectUrl for payment completion
  ///
  /// [planId] - The ID of the subscription plan
  /// [branchId] - The ID of the branch for the subscription
  /// [imageFile] - Optional image file for payment proof (if required)
  ///
  /// Returns the created subscription request or throws an exception
  Future<WholesalerBranchSubscriptionRequest> createWholesalerSubscription({
    required String planId,
    required String branchId,
    File? imageFile,
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
      
      // Validate image file if provided (optional for Whish payment flow)
      if (imageFile != null) {
        if (!await imageFile.exists()) {
          throw Exception('Payment proof image file does not exist');
        }
        
        final fileSize = await imageFile.length();
        if (fileSize > 10 * 1024 * 1024) { // 10MB limit (matching backend)
          throw Exception('Payment proof image is too large. Maximum size is 10MB');
        }
        
        final fileExtension = imageFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
          throw Exception('Invalid file format. Only JPG, PNG, and GIF are allowed');
        }
      }
      
      // Backend endpoint: branchId is in URL path, planId is in form data
      final uri = Uri.parse('$baseUrl/api/wholesaler/subscription/$branchId/request');
      final headers = await _getMultipartHeaders();

      // Prepare fields with sanitized inputs (backend expects planId in form data)
      Map<String, String> fields = {
        'planId': planId.trim(),
      };

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add image file if provided (optional - Whish payment doesn't require image)
      if (imageFile != null) {
        final fileName = path.basename(imageFile.path);
        files.add(
          await http.MultipartFile.fromPath(
            'paymentProof',
            imageFile.path,
            filename: fileName,
          ),
        );
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

      // Log response details for debugging
      print('🟡 WholesalerSubscriptionService - CreateBranchSubscriptionRequest Response Status: ${response.statusCode}');
      print('🟡 WholesalerSubscriptionService - Response Body: ${response.body}');

      // Handle 409 Conflict - already has pending subscription request
      if (response.statusCode == 409) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final errorMessage = responseData['message'] ?? 'You already have a pending subscription request for this branch. Please complete the payment first.';
        print('🟡 WholesalerSubscriptionService - Throwing ConflictException for 409 error');
        throw ConflictException(errorMessage, response.statusCode);
      }

      // Handle 201 Created - successful payment initiation
      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final data = responseData['data'];

        if (data == null) {
          throw Exception('No data received from server');
        }

        // Backend returns: requestId, plan, status, submittedAt, paymentAmount, collectUrl, externalId
        try {
          // Parse the response data - backend returns requestId (not id), submittedAt (not requestedAt)
          final requestId = data['requestId']?.toString() ?? data['id']?.toString();
          final planData = data['plan'];
          final status = data['status']?.toString() ?? 'pending_payment';
          final submittedAt = data['submittedAt'] ?? data['requestedAt'];
          final collectUrl = data['collectUrl']?.toString();
          final externalId = data['externalId'];
          // paymentAmount is available in response but not needed for WholesalerBranchSubscriptionRequest model
          
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
          final subscriptionRequest = WholesalerBranchSubscriptionRequest(
            id: requestId,
            branchId: branchId.trim(),
            planId: parsedPlanId ?? planId.trim(),
            status: status,
            requestedAt: requestedAt ?? DateTime.now(),
            imagePath: null,
            collectUrl: collectUrl,
            externalId: parsedExternalId,
            paymentStatus: status == 'pending_payment' ? 'pending' : (data['paymentStatus']?.toString() ?? 'pending'),
            paidAt: null,
          );
          
          return subscriptionRequest;
        } catch (parseError) {
          print('⚠️ WholesalerSubscriptionService - Parse error: $parseError');
          // If parsing fails, create a basic success response with available data
          try {
            final fallbackResult = WholesalerBranchSubscriptionRequest(
              id: data is Map ? (data['requestId'] ?? data['id'] ?? 'unknown')?.toString() : 'unknown',
              branchId: branchId.trim(),
              planId: planId.trim(),
              status: data is Map ? (data['status'] ?? 'pending_payment')?.toString() : 'pending_payment',
              requestedAt: DateTime.now(),
              imagePath: null,
              collectUrl: data is Map ? data['collectUrl']?.toString() : null,
              externalId: data is Map ? (data['externalId'] is int ? data['externalId'] : (data['externalId'] is String ? int.tryParse(data['externalId']) : null)) : null,
              paymentStatus: data is Map ? (data['paymentStatus'] ?? 'pending')?.toString() : 'pending',
            );
            return fallbackResult;
          } catch (fallbackError) {
            if (parseError.toString().contains("type 'String' is not a subtype of type 'bool'")) {
              throw Exception('Data type mismatch in server response. Please try again or contact support.');
            }
            rethrow;
          }
        }
      } else {
        print('🟡 WholesalerSubscriptionService - HTTP Status: ${response.statusCode}');
        print('🟡 WholesalerSubscriptionService - Response Body: ${response.body}');
        
        // Try to parse the response body
        String errorMessage = 'Failed to create subscription request';
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);
          errorMessage = responseData['message'] ?? 'Failed to create subscription request';
          print('🟡 WholesalerSubscriptionService - Parsed Error Message: $errorMessage');
        } catch (parseError) {
          print('🟡 WholesalerSubscriptionService - Failed to parse response body: $parseError');
          // Use the raw response body if JSON parsing fails
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }
        
        // Create a custom exception that includes the status code
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ WholesalerSubscriptionService - Caught exception: $e');
      print('❌ WholesalerSubscriptionService - Exception type: ${e.runtimeType}');
      if (e is ConflictException) {
        // Preserve ConflictException for 409 errors
        print('🟡 WholesalerSubscriptionService - Preserving ConflictException');
        rethrow;
      } else if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else if (e.toString().contains("type 'String' is not a subtype of type 'bool'")) {
        throw Exception('Data type mismatch in server response. Please try again or contact support.');
      } else {
        throw Exception('Failed to create subscription request: ${e.toString()}');
      }
    }
  }


  /// Get the remaining time of the current wholesaler subscription
  ///
  /// Returns subscription remaining time data
  Future<SubscriptionRemainingTimeData> getWholesalerSubscriptionRemainingTime(String branchId) async {
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
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/subscription/$branchId/remaining-time'),
        headers: headers,
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final data = responseData['data'];

        if (data == null) {
          return SubscriptionRemainingTimeData(
            hasActiveSubscription: false,
            remainingTime: null,
          );
        }

        final result = SubscriptionRemainingTimeData.fromJson(data);
        return result;
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final errorMessage = responseData['message'] ?? 'Failed to get subscription remaining time';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else if (e.toString().contains("type 'String' is not a subtype of type 'bool'")) {
        throw Exception('Data type mismatch in server response. Please try again or contact support.');
      } else {
        throw Exception('Failed to get subscription remaining time');
      }
    }
  }

  /// Cancel the current active wholesaler subscription
  ///
  /// [branchId] - The ID of the branch to cancel subscription for
  /// Returns true if cancellation was successful
  Future<bool> cancelWholesalerSubscription(String branchId) async {
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
      final response = await _makeRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/wholesaler/subscription/$branchId/cancel'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to cancel subscription');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else {
        throw Exception('Failed to cancel subscription');
      }
    }
  }

  /// Check if wholesaler has an active subscription
  ///
  /// Returns true if there's an active subscription
  Future<bool> hasActiveSubscription(String branchId) async {
    try {
      final remainingTimeData = await getWholesalerSubscriptionRemainingTime(branchId);
      return remainingTimeData.hasActiveSubscription ?? false;
    } catch (e) {
      // If there's an error, assume no active subscription
      return false;
    }
  }

  /// Check Whish account balance (via backend)
  /// Returns the account balance in the response data
  Future<ApiResponse<double>> checkWhishAccountBalance() async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/api/wholesaler/payment/whish/balance';
      
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

  /// Get subscription status summary
  ///
  /// Returns a comprehensive summary of the subscription status
  Future<WholesalerSubscriptionStatus> getSubscriptionStatus(String branchId) async {
    try {
      final remainingTime = await getWholesalerSubscriptionRemainingTime(branchId);

      return WholesalerSubscriptionStatus(
        hasActiveSubscription: remainingTime.hasActiveSubscription ?? false,
        remainingTime: remainingTime.remainingTime,
      );
    } catch (e) {
      throw Exception('Failed to get subscription status');
    }
  }
}

/// Data model for current wholesaler subscription
class CurrentWholesalerSubscriptionData {
  final WholesalerSubscription? subscription;
  final SubscriptionPlan? plan;

  CurrentWholesalerSubscriptionData({
    this.subscription,
    this.plan,
  });

  factory CurrentWholesalerSubscriptionData.fromJson(Map<String, dynamic> json) {
    return CurrentWholesalerSubscriptionData(
      subscription: json['subscription'] != null
          ? WholesalerSubscription.fromJson(json['subscription'])
          : null,
      plan: json['plan'] != null
          ? SubscriptionPlan.fromJson(json['plan'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscription': subscription?.toJson(),
      'plan': plan?.toJson(),
    };
  }
}

/// Data model for wholesaler subscription
class WholesalerSubscription {
  final String? id;
  final String? wholesalerId;
  final String? planId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final bool? autoRenew;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WholesalerSubscription({
    this.id,
    this.wholesalerId,
    this.planId,
    this.startDate,
    this.endDate,
    this.status,
    this.autoRenew,
    this.createdAt,
    this.updatedAt,
  });

  factory WholesalerSubscription.fromJson(Map<String, dynamic> json) {
    return WholesalerSubscription(
      id: json['id'],
      wholesalerId: json['wholesalerId'],
      planId: json['planId'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      status: json['status'],
      autoRenew: json['autoRenew'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wholesalerId': wholesalerId,
      'planId': planId,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status,
      'autoRenew': autoRenew,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

/// Comprehensive subscription status
class WholesalerSubscriptionStatus {
  final bool hasActiveSubscription;
  final CurrentWholesalerSubscriptionData? currentSubscription;
  final SubscriptionRemainingTime? remainingTime;

  WholesalerSubscriptionStatus({
    required this.hasActiveSubscription,
    this.currentSubscription,
    this.remainingTime,
  });

  /// Check if subscription is about to expire (less than 7 days)
  bool get isExpiringSoon {
    if (remainingTime?.days == null) return false;
    return (remainingTime!.days! <= 7);
  }

  /// Check if subscription is about to expire (less than 1 day)
  bool get isExpiringToday {
    if (remainingTime?.days == null) return false;
    return (remainingTime!.days! <= 1);
  }


  /// Get subscription plan name
  String get planName {
    return currentSubscription?.plan?.title ?? 'Unknown Plan';
  }

  /// Get subscription status text
  String get statusText {
    if (!hasActiveSubscription) return 'No Active Subscription';
    if (isExpiringToday) return 'Expires Today';
    if (isExpiringSoon) return 'Expires Soon';
    return 'Active';
  }
}