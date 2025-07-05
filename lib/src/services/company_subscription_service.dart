// lib/services/company_subscription_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import '../models/subscription.dart';
import '../models/api_response.dart';
import '../utils/token_storage.dart';

class CompanySubscriptionService {
  static final TokenStorage _tokenStorage = TokenStorage();
  static const String _baseUrl = ApiService.baseUrl; // TODO: Move to api_constants.dart
  static const String _subscriptionEndpoint = '/api/companies';

  // --- Custom HTTP client for self-signed certificates ---
  static http.Client? _customClient;
  static Future<http.Client> _getCustomClient() async {
    if (_customClient != null) return _customClient!;
    HttpClient httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) {
      return host == '104.131.188.174' || host == 'yourdomain.com';
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

  // Get authentication headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get multipart headers for file uploads
  static Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _tokenStorage.getToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }

  /// Get all available subscription plans for companies
  static Future<ApiResponse<List<SubscriptionPlan>>> getSubscriptionPlans() async {
    try {
      print('Starting getSubscriptionPlans request...');
      final headers = await _getHeaders();
      print('Headers: $headers');
      
      final url = '$_baseUrl$_subscriptionEndpoint/subscription-plans';
      print('Requesting URL: $url');
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );
      print('Response status code: ${response.statusCode}');
      print('Raw subscription plans response: ${response.body}');

      try {
        final responseData = json.decode(response.body);
        print('Decoded subscription plans response: $responseData');

        if (response.statusCode == 200) {
          print('Subscription plans data type: ${responseData['data']?.runtimeType}');
          print('Subscription plans data: ${responseData['data']}');
          
          final List<dynamic> plansJson = responseData['data'] ?? [];
          print('Plans JSON before mapping: $plansJson');
          
          final plans = plansJson.map((json) {
            print('Processing plan JSON: $json');
            return SubscriptionPlan.fromJson(json);
          }).toList();
          print('Processed plans: ${plans.map((p) => p.toJson()).toList()}');

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
        print('Error parsing response: $parseError');
        print('Response that failed to parse: ${response.body}');
        rethrow;
      }
    } catch (e, stackTrace) {
      print('Error in getSubscriptionPlans: $e');
      print('Stack trace: $stackTrace');
      return ApiResponse<List<SubscriptionPlan>>(
        success: false,
        message: 'Network error: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Create a subscription request with optional payment proof image
  static Future<ApiResponse<SubscriptionRequest>> createSubscriptionRequest({
    required String planId,
    File? paymentProofImage,
  }) async {
    try {
      final headers = await _getMultipartHeaders();
      final uri = Uri.parse('$_baseUrl$_subscriptionEndpoint/subscription/request');

      // Prepare fields
      Map<String, String> fields = {
        'planId': planId,
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
        message: 'Network error: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Get current active subscription
  static Future<ApiResponse<CurrentSubscriptionData?>> getCurrentSubscription() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$_baseUrl$_subscriptionEndpoint/current-subscription'),
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
        message: 'Network error: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Get subscription remaining time
  static Future<ApiResponse<SubscriptionRemainingTimeData>> getSubscriptionRemainingTime() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$_baseUrl$_subscriptionEndpoint/subscription/remaining-time'),
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
        message: 'Network error: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Cancel active subscription
  static Future<ApiResponse<void>> cancelSubscription() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'POST',
        Uri.parse('$_baseUrl$_subscriptionEndpoint/subscription/cancel'),
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
        message: 'Network error: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Check if company has active subscription
  static Future<bool> hasActiveSubscription() async {
    try {
      final response = await getSubscriptionRemainingTime();
      if (response.success && response.data != null) {
        return response.data!.hasActiveSubscription ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get subscription status summary
  static Future<ApiResponse<SubscriptionStatus>> getSubscriptionStatus() async {
    try {
      final currentSubscriptionResponse = await getCurrentSubscription();
      final remainingTimeResponse = await getSubscriptionRemainingTime();

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
        message: 'Network error: ${e.toString()}',
        error: e.toString(),
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