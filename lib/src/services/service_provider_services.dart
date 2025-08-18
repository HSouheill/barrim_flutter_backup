import 'dart:convert';
import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';
import '../models/service_provider.dart';
import '../utils/token_storage.dart';
import '../models/review.dart';

class ServiceProviderService {
  final String baseUrl = ApiService.baseUrl;
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

  // Get service provider data
  Future<ServiceProvider> getServiceProviderData() async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        throw Exception('No token found');
      }
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/service-provider/details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          return ServiceProvider.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to get service provider data');
        }
      } else {
        throw Exception('Failed to get service provider data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting service provider data: $e');
    }
  }

  Future<void> updateServiceProviderProfile({
    required String businessName,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) throw Exception('No token found');
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/update'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['fullName'] = businessName;
      if (email != null && email.isNotEmpty) request.fields['email'] = email;
      if (newPassword != null && newPassword.isNotEmpty) {
        request.fields['password'] = newPassword;
      }
      final client = await _getCustomClient();
      var response = await http.Response.fromStream(await client.send(request));
      if (response.statusCode != 200) {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  Future<void> updateServiceProviderProfileWithLogo({
    required String businessName,
    String? email,
    String? currentPassword,
    String? newPassword,
    required File logoFile,
  }) async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) throw Exception('No token found');
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/update'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['fullName'] = businessName;
      if (email != null && email.isNotEmpty) request.fields['email'] = email;
      if (newPassword != null && newPassword.isNotEmpty) {
        request.fields['password'] = newPassword;
      }
      request.files.add(await http.MultipartFile.fromPath(
        'logo',
        logoFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));
      final client = await _getCustomClient();
      var response = await http.Response.fromStream(await client.send(request));
      if (response.statusCode != 200) {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      throw Exception('Error updating profile with logo: $e');
    }
  }

  // Update service provider description
  Future<void> updateServiceProviderDescription(String description) async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        throw Exception('No token found');
      }
      final currentData = await getServiceProviderData();
      final Map<String, dynamic> requestData = {
        'fullName': currentData.fullName,
        'description': description,
      };
      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      );
      if (response.statusCode != 200) {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to update description');
      }
    } catch (e) {
      throw Exception('Error updating description: $e');
    }
  }

  // Upload certificate image for service provider
  Future<void> uploadCertificateImage(File certificateFile) async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/service-provider/certificate'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add certificate file
      request.files.add(
        await http.MultipartFile.fromPath(
          'certificate',
          certificateFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Send request to upload certificate
      final client = await _getCustomClient();
      var streamedResponse = await client.send(request);
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to upload certificate');
      }

      // If successful, we don't need to do anything else as the backend will update the user's record
    } catch (e) {
      throw Exception('Error uploading certificate: $e');
    }
  }

  // SUBSCRIPTION FUNCTIONS

  /// Create a subscription request for a specific plan
  Future<SubscriptionRequest> createSubscriptionRequest(String planId) async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/service-provider/subscriptions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'planId': planId,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 201 && responseData['data'] != null) {
          return SubscriptionRequest.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to create subscription request');
        }
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to create subscription request: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating subscription request: $e');
    }
  }

  /// Get current active subscription
  Future<CurrentSubscription?> getCurrentSubscription() async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/service-provider/subscriptions/current'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          return CurrentSubscription.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to get current subscription');
        }
      } else if (response.statusCode == 404) {
        // No active subscription found
        return null;
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to get current subscription: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting current subscription: $e');
    }
  }

  /// Pause current active subscription
  Future<void> pauseSubscription() async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/subscriptions/pause'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to pause subscription');
      }
    } catch (e) {
      throw Exception('Error pausing subscription: $e');
    }
  }

  /// Renew expired or paused subscription
  Future<SubscriptionRenewalInfo> renewSubscription() async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/subscriptions/renew'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          return SubscriptionRenewalInfo.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to renew subscription');
        }
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to renew subscription: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error renewing subscription: $e');
    }
  }

  /// Cancel active subscription
  Future<void> cancelSubscription() async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/subscriptions/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to cancel subscription');
      }
    } catch (e) {
      throw Exception('Error cancelling subscription: $e');
    }
  }

  /// Post a reply to a review (service provider only)
  Future<ReviewReply> postReviewReply({
    required String reviewId,
    required String replyText,
  }) async {
    final token = await _tokenStorage.getToken();
    if (token == null) throw Exception('No token found');

    final response = await _makeRequest(
      'POST',
      Uri.parse('$baseUrl/api/reviews/$reviewId/reply'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'replyText': replyText}),
    );

    final responseData = json.decode(response.body);
    if (response.statusCode == 200 && responseData['data'] != null) {
      return ReviewReply.fromJson(responseData['data']);
    } else {
      throw Exception(responseData['message'] ?? 'Failed to post reply');
    }
  }

  /// Get the reply for a review (service provider or review user)
  Future<ReviewReply> getReviewReply(String reviewId) async {
    final token = await _tokenStorage.getToken();
    if (token == null) throw Exception('No token found');

    final response = await _makeRequest(
      'GET',
      Uri.parse('$baseUrl/api/reviews/$reviewId/reply'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final responseData = json.decode(response.body);
    if (response.statusCode == 200 && responseData['data'] != null) {
      return ReviewReply.fromJson(responseData['data']);
    } else {
      throw Exception(responseData['message'] ?? 'Failed to get reply');
    }
  }
}

// Data Models for Subscription

class SubscriptionRequest {
  final String id;
  final String serviceProviderId;
  final String planId;
  final String status;
  final DateTime requestedAt;

  SubscriptionRequest({
    required this.id,
    required this.serviceProviderId,
    required this.planId,
    required this.status,
    required this.requestedAt,
  });

  factory SubscriptionRequest.fromJson(Map<String, dynamic> json) {
    return SubscriptionRequest(
      id: json['id'] ?? '',
      serviceProviderId: json['serviceProviderId'] ?? '',
      planId: json['planId'] ?? '',
      status: json['status'] ?? '',
      requestedAt: DateTime.parse(json['requestedAt']),
    );
  }
}

class CurrentSubscription {
  final Subscription subscription;
  final SubscriptionPlan plan;

  CurrentSubscription({
    required this.subscription,
    required this.plan,
  });

  factory CurrentSubscription.fromJson(Map<String, dynamic> json) {
    return CurrentSubscription(
      subscription: Subscription.fromJson(json['subscription']),
      plan: SubscriptionPlan.fromJson(json['plan']),
    );
  }
}

class Subscription {
  final String id;
  final String serviceProviderId;
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final bool autoRenew;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.id,
    required this.serviceProviderId,
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.autoRenew,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] ?? '',
      serviceProviderId: json['serviceProviderId'] ?? '',
      planId: json['planId'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      status: json['status'] ?? '',
      autoRenew: json['autoRenew'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Helper methods
  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';

  bool get isExpiringSoon {
    final now = DateTime.now();
    final daysUntilExpiry = endDate.difference(now).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry >= 0;
  }

  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays;
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String duration;
  final List<String> features;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.duration,
    required this.features,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      duration: json['duration'] ?? '',
      features: json['features'] != null
          ? List<String>.from(json['features'])
          : [],
      isActive: json['isActive'] ?? true,
    );
  }
}

class SubscriptionRenewalInfo {
  final DateTime startDate;
  final DateTime endDate;

  SubscriptionRenewalInfo({
    required this.startDate,
    required this.endDate,
  });

  factory SubscriptionRenewalInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionRenewalInfo(
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
    );
  }
}