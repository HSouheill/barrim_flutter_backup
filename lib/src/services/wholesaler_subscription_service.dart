// services/wholesaler_subscription_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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

  /// Get authorization headers with token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  /// Get multipart headers with token
  Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _tokenStorage.getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  /// Get available subscription plans for wholesalers
  ///
  /// Returns a list of available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/subscription-plans'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> plansData = responseData['data'] ?? [];

        return plansData.map((plan) => SubscriptionPlan.fromJson(plan)).toList();
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to get available plans');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else {
        throw Exception('Failed to get available plans: ${e.toString()}');
      }
    }
  }

  /// Create a new wholesaler subscription request
  ///
  /// [planId] - The ID of the subscription plan
  /// [imageFile] - Optional image file for payment proof (if required)
  ///
  /// Returns the created subscription request or throws an exception
  Future<SubscriptionRequest> createWholesalerSubscription({
    required String planId,
    File? imageFile,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/wholesaler/subscription');
      final headers = await _getMultipartHeaders();

      // Prepare fields
      Map<String, String> fields = {
        'planId': planId,
      };

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add image file if provided
      if (imageFile != null) {
        final fileName = path.basename(imageFile.path);
        files.add(
          await http.MultipartFile.fromPath(
            'image',
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

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final data = responseData['data'];

        return SubscriptionRequest.fromJson(data);
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to create subscription request');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else {
        throw Exception('Failed to create subscription request: ${e.toString()}');
      }
    }
  }

  /// Get the current active wholesaler subscription
  ///
  /// Returns the current subscription data or null if no active subscription
  Future<CurrentWholesalerSubscriptionData?> getCurrentWholesalerSubscription() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/subscription/current'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final data = responseData['data'];

        if (data == null) {
          return null; // No active subscription
        }

        return CurrentWholesalerSubscriptionData.fromJson(data);
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to get current subscription');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else {
        throw Exception('Failed to get current subscription: ${e.toString()}');
      }
    }
  }

  /// Get the remaining time of the current wholesaler subscription
  ///
  /// Returns subscription remaining time data
  Future<SubscriptionRemainingTimeData> getWholesalerSubscriptionRemainingTime() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/subscription/remaining-time'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final data = responseData['data'];

        return SubscriptionRemainingTimeData.fromJson(data);
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to get subscription remaining time');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e is FormatException) {
        throw Exception('Invalid response format from server.');
      } else {
        throw Exception('Failed to get subscription remaining time: ${e.toString()}');
      }
    }
  }

  /// Cancel the current active wholesaler subscription
  ///
  /// Returns true if cancellation was successful
  Future<bool> cancelWholesalerSubscription() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/wholesaler/subscription/cancel'),
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
        throw Exception('Failed to cancel subscription: ${e.toString()}');
      }
    }
  }

  /// Check if wholesaler has an active subscription
  ///
  /// Returns true if there's an active subscription
  Future<bool> hasActiveSubscription() async {
    try {
      final remainingTimeData = await getWholesalerSubscriptionRemainingTime();
      return remainingTimeData.hasActiveSubscription ?? false;
    } catch (e) {
      // If there's an error, assume no active subscription
      return false;
    }
  }

  /// Get subscription status summary
  ///
  /// Returns a comprehensive summary of the subscription status
  Future<WholesalerSubscriptionStatus> getSubscriptionStatus() async {
    try {
      final currentSubscription = await getCurrentWholesalerSubscription();
      final remainingTime = await getWholesalerSubscriptionRemainingTime();

      return WholesalerSubscriptionStatus(
        hasActiveSubscription: remainingTime.hasActiveSubscription ?? false,
        currentSubscription: currentSubscription,
        remainingTime: remainingTime.remainingTime,
      );
    } catch (e) {
      throw Exception('Failed to get subscription status: ${e.toString()}');
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