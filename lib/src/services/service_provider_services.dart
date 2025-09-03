import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

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

  // Helper method to compress and resize image
  Future<File> _compressAndResizeImage(File originalFile) async {
    try {
      // Read the original image
      final Uint8List bytes = await originalFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }
      
      // Calculate new dimensions (max 800x800 pixels)
      int newWidth = originalImage.width;
      int newHeight = originalImage.height;
      
      if (newWidth > 800 || newHeight > 800) {
        if (newWidth > newHeight) {
          newHeight = (newHeight * 800 / newWidth).round();
          newWidth = 800;
        } else {
          newWidth = (newWidth * 800 / newHeight).round();
          newHeight = 800;
        }
      }
      
      // Resize the image
      final img.Image resizedImage = img.copyResize(originalImage, width: newWidth, height: newHeight);
      
      // Encode as JPEG with quality 85 (good balance between quality and size)
      final Uint8List compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Create a temporary file for the compressed image
      final Directory tempDir = Directory.systemTemp;
      final File compressedFile = File('${tempDir.path}/compressed_logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(compressedBytes);
      
      print('Image compressed: ${originalFile.lengthSync()} bytes -> ${compressedFile.lengthSync()} bytes');
      print('Image resized: ${originalImage.width}x${originalImage.height} -> ${newWidth}x${newHeight}');
      
      return compressedFile;
    } catch (e) {
      print('Failed to compress image: $e');
      // Return original file if compression fails
      return originalFile;
    }
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
          final data = responseData['data'] as Map<String, dynamic>;
          
          // Extract the actual service provider data from the nested structure
          Map<String, dynamic> serviceProviderData;
          if (data.containsKey('serviceProvider')) {
            // The API returns {category: "...", serviceProvider: {...}}
            serviceProviderData = Map<String, dynamic>.from(data['serviceProvider'] as Map<String, dynamic>);
            // Add the category to the service provider data
            if (data.containsKey('category')) {
              serviceProviderData['category'] = data['category'];
            }
          } else {
            // Direct service provider data
            serviceProviderData = data;
          }
          
          return ServiceProvider.fromJson(serviceProviderData);
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
      
      print('Profile update response status: ${response.statusCode}');
      print('Profile update response body: ${response.body}');
      
      if (response.statusCode != 200) {
        // Check for specific error status codes
        String errorMessage = 'Failed to update profile';
        
        if (response.statusCode == 413) {
          errorMessage = 'Request entity too large. Please try with a smaller file.';
        } else {
          try {
            if (response.body.trim().startsWith('<html>') || response.body.trim().startsWith('<!DOCTYPE')) {
              // Server returned HTML instead of JSON (likely an error page)
              if (response.body.contains('413 Request Entity Too Large')) {
                errorMessage = 'File size too large. Please try with a smaller file.';
              } else {
                errorMessage = 'Server error occurred while updating profile. Please try again later.';
              }
            } else {
              // Try to parse as JSON
              final responseData = json.decode(response.body);
              errorMessage = responseData['message'] ?? 'Failed to update profile';
            }
          } catch (parseError) {
            // If JSON parsing fails, use the raw response or default message
            if (response.body.isNotEmpty && response.body.length < 200) {
              errorMessage = 'Server response: ${response.body}';
            }
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // Update service provider info with proper field structure
  Future<void> updateServiceProviderInfo({
    required String businessName,
    String? email,
    String? currentPassword,
    String? newPassword,
    Map<String, dynamic>? additionalData,
    List<File>? certificateFiles,
  }) async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) throw Exception('No token found');
      
      // Create multipart request
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/update'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add basic fields
      request.fields['fullName'] = businessName;
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }
      if (newPassword != null && newPassword.isNotEmpty) {
        request.fields['password'] = newPassword;
      }
      
      // Add additional data fields
      if (additionalData != null) {
        if (additionalData['phone'] != null) {
          request.fields['phone'] = additionalData['phone'];
        }
        if (additionalData['serviceType'] != null) {
          request.fields['serviceType'] = additionalData['serviceType'];
        }
        if (additionalData['yearsExperience'] != null) {
          request.fields['yearsExperience'] = additionalData['yearsExperience'].toString();
        }
        if (additionalData['location'] != null) {
          Map<String, dynamic> location = additionalData['location'];
          if (location['country'] != null) {
            request.fields['country'] = location['country'];
          }
          if (location['district'] != null) {
            request.fields['district'] = location['district'];
          }
          if (location['city'] != null) {
            request.fields['city'] = location['city'];
          }
          if (location['street'] != null) {
            request.fields['street'] = location['street'];
          }
          if (location['postalCode'] != null) {
            request.fields['postalCode'] = location['postalCode'];
          }
        }
        
        // Handle arrays by sending them as comma-separated strings
        if (additionalData['availableDays'] != null) {
          List<String> availableDays = List<String>.from(additionalData['availableDays']);
          request.fields['availableDays'] = availableDays.join(',');
          print('Sending availableDays: $availableDays');
        }
        if (additionalData['availableHours'] != null) {
          List<String> availableHours = List<String>.from(additionalData['availableHours']);
          request.fields['availableHours'] = availableHours.join(',');
          print('Sending availableHours: $availableHours');
        }
      }
      
      // Add certificate files if provided
      if (certificateFiles != null && certificateFiles.isNotEmpty) {
        for (File certificateFile in certificateFiles) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'certificates',
              certificateFile.path,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }
      }
      
      print('Updating service provider info with data: ${request.fields}');
      print('Certificate files count: ${request.files.length}');
      
      // Send multipart request
      final client = await _getCustomClient();
      var response = await http.Response.fromStream(await client.send(request));
      
      print('Service provider info update response status: ${response.statusCode}');
      print('Service provider info update response body: ${response.body}');
      
      if (response.statusCode != 200) {
        String errorMessage = 'Failed to update service provider info';
        
        try {
          if (response.body.trim().startsWith('<html>') || response.body.trim().startsWith('<!DOCTYPE')) {
            errorMessage = 'Server error occurred while updating service provider info. Please try again later.';
          } else {
            final responseData = json.decode(response.body);
            errorMessage = responseData['message'] ?? 'Failed to update service provider info';
          }
        } catch (parseError) {
          if (response.body.isNotEmpty && response.body.length < 200) {
            errorMessage = 'Server response: ${response.body}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Error updating service provider info: $e');
    }
  }

  Future<void> updateServiceProviderProfileWithLogo({
    required String businessName,
    String? email,
    String? currentPassword,
    String? newPassword,
    required File logoFile,
  }) async {
    // Declare processedLogoFile outside try block so it can be accessed in catch block
    File processedLogoFile = logoFile;
    
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) throw Exception('No token found');
      
      // Validate logo file
      if (!await logoFile.exists()) {
        throw Exception('Logo file does not exist');
      }
      
      final fileSize = await logoFile.length();
      if (fileSize == 0) {
        throw Exception('Logo file is empty');
      }
      
      print('Updating profile with logo - URL: $baseUrl/api/service-provider/update');
      print('Original logo file path: ${logoFile.path}');
      print('Original logo file size: $fileSize bytes');
      
      // Compress and resize the image if it's too large
      if (fileSize > 1024 * 1024) { // If larger than 1MB, compress it
        print('Logo file is large, compressing...');
        processedLogoFile = await _compressAndResizeImage(logoFile);
        final compressedSize = await processedLogoFile.length();
        print('Compressed logo file size: $compressedSize bytes');
        
        // Check if compression was successful and file is still too large
        if (compressedSize > 5 * 1024 * 1024) {
          throw Exception('Logo file is still too large after compression (${(compressedSize / (1024 * 1024)).toStringAsFixed(1)}MB). Please choose a smaller image.');
        }
      }
      
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
      
      // Add the logo file
      try {
        final multipartFile = await http.MultipartFile.fromPath(
          'logo',
          processedLogoFile.path,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
        print('Logo file added successfully to request (using ${processedLogoFile == logoFile ? 'original' : 'compressed'} file)');
      } catch (e) {
        throw Exception('Failed to prepare logo file for upload: $e');
      }
      
      print('Request fields: ${request.fields}');
      print('Request files count: ${request.files.length}');
      
      final client = await _getCustomClient();
      print('Sending multipart request...');
      var response = await http.Response.fromStream(await client.send(request));
      print('Response received');
      
      print('Profile update response status: ${response.statusCode}');
      print('Profile update response body: ${response.body}');
      
      if (response.statusCode != 200) {
        // Check for specific error status codes
        String errorMessage = 'Failed to update profile';
        
        if (response.statusCode == 413) {
          errorMessage = 'File size too large. The image has been compressed, but it\'s still too big. Please choose a smaller image (under 5MB).';
        } else {
          try {
            if (response.body.trim().startsWith('<html>') || response.body.trim().startsWith('<!DOCTYPE')) {
              // Server returned HTML instead of JSON (likely an error page)
              if (response.body.contains('413 Request Entity Too Large')) {
                errorMessage = 'File size too large. Please choose a smaller image file.';
              } else {
                errorMessage = 'Server error occurred while updating profile. Please try again later.';
              }
            } else {
              // Try to parse as JSON
              final responseData = json.decode(response.body);
              errorMessage = responseData['message'] ?? 'Failed to update profile';
            }
          } catch (parseError) {
            // If JSON parsing fails, use the raw response or default message
            if (response.body.isNotEmpty && response.body.length < 200) {
              errorMessage = 'Server response: ${response.body}';
            }
          }
        }
        throw Exception(errorMessage);
      }
      
      // Clean up temporary compressed file if it was created
      if (processedLogoFile != logoFile) {
        try {
          await processedLogoFile.delete();
          print('Temporary compressed file cleaned up');
        } catch (e) {
          print('Failed to clean up temporary file: $e');
        }
      }
    } catch (e) {
      // Clean up temporary compressed file if it was created (even on error)
      if (processedLogoFile != logoFile) {
        try {
          await processedLogoFile.delete();
          print('Temporary compressed file cleaned up after error');
        } catch (e) {
          print('Failed to clean up temporary file after error: $e');
        }
      }
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