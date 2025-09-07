// services/wholesaler_subscription_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;
import '../models/subscription.dart';
import '../models/wholesaler_model.dart';
import '../utils/token_storage.dart';

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
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> plansData = responseData['data'] ?? [];
        
        final plans = plansData.map((plan) => SubscriptionPlan.fromJson(plan)).toList();
        return plans;
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final errorMessage = responseData['message'] ?? 'Failed to get available plans';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else {
        throw Exception('Failed to get available plans');
      }
    }
  }

  /// Create a new wholesaler subscription request
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
      
      // Validate image file if provided
      if (imageFile != null) {
        if (!await imageFile.exists()) {
          throw Exception('Payment proof image file does not exist');
        }
        
        final fileSize = await imageFile.length();
        if (fileSize > 5 * 1024 * 1024) { // 5MB limit
          throw Exception('Payment proof image is too large. Maximum size is 5MB');
        }
        
        final fileExtension = imageFile.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
          throw Exception('Invalid file format. Only JPG, PNG, and GIF are allowed');
        }
      }
      
      final uri = Uri.parse('$baseUrl/api/wholesaler/subscription/$branchId/request');
      final headers = await _getMultipartHeaders();

      // Prepare fields with sanitized inputs
      Map<String, String> fields = {
        'planId': planId.trim(),
        'branchId': branchId.trim(),
      };

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add image file if provided - use 'paymentProof' as the field name
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

      // Response logged without sensitive data

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final data = responseData['data'];

        if (data == null) {
          throw Exception('No data received from server');
        }

        try {
          final result = WholesalerBranchSubscriptionRequest.fromJson(data);
          return result;
        } catch (parseError) {
          // If parsing fails, create a basic success response with available data
          try {
            final fallbackResult = WholesalerBranchSubscriptionRequest(
              id: data is Map ? (data['requestId'] ?? data['id'] ?? 'unknown')?.toString() : 'unknown',
              branchId: branchId.trim(),
              planId: planId.trim(),
              status: data is Map ? (data['status'] ?? 'pending')?.toString() : 'pending',
              requestedAt: DateTime.now(),
              imagePath: data is Map ? data['imagePath']?.toString() : null,
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
        final Map<String, dynamic> responseData = json.decode(response.body);
        final errorMessage = responseData['message'] ?? 'Failed to create subscription request';
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
        throw Exception('Failed to create subscription request');
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