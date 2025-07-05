// services/wholesaler_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import '../models/wholesaler_model.dart';
import '../utils/token_storage.dart';
import 'api_service.dart';
import 'package:flutter/foundation.dart';

class WholesalerService {
  // Base URL for API requests
  final String baseUrl = ApiService.baseUrl;
  final TokenStorage _tokenStorage = TokenStorage();

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

  // Get the auth token
  Future<String?> _getToken() async {
    return await _tokenStorage.getToken();
  }

  // Headers with authentication token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get wholesaler data
  Future<Wholesaler?> getWholesalerData() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/data'),
        headers: headers,
      );
      print('Request URL: ${Uri.parse('$baseUrl/api/wholesaler/data')}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          // Changed from 'wholesalerInfo' to 'wholesaler' to match backend
          final wholesaler = apiResponse.data['wholesaler'];
          print('Wholesaler Data: $wholesaler');
          return Wholesaler.fromJson(wholesaler);  // Assuming your fromJson method is correctly implemented
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to load wholesaler data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getWholesalerData: $e');
      return null;
    }
  }

  // Get branches for a wholesaler
  Future<List<Branch>> getWholesalerBranches({String? wholesalerId}) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/api/wholesaler/branches';

      if (wholesalerId != null) {
        url = '$url?wholesalerId=$wholesalerId';
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          if (apiResponse.data is List) {
            return List<Branch>.from(
                apiResponse.data.map((branchJson) => Branch.fromJson(branchJson))
            );
          } else {
            return [];
          }
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to load branches: ${response.statusCode}');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in getBranches: $e');
      }
      return [];
    }
  }

  // Create a new branch with images and videos
  Future<Branch?> createBranch({
    required String name,
    required Address location,
    required String phone,
    required String category,
    String? subCategory,
    required String description,
    List<File> images = const [],
    List<File> videos = const [],
  }) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/api/wholesaler/branches');

      // Create multipart request
      var request = http.MultipartRequest('POST', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add branch data as JSON
      final branchData = {
        'name': name,
        'country': location.country,
        'district': location.district,
        'city': location.city,
        'street': location.street,
        'postalCode': location.postalCode,
        'lat': location.lat,
        'lng': location.lng,
        'phone': phone,
        'category': category,
        'subCategory': subCategory,
        'description': description,
      };

      // Add branch data as a field
      request.fields['data'] = json.encode(branchData);

      // Add image files
      for (var i = 0; i < images.length; i++) {
        final file = images[i];
        final fileName = file.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        request.files.add(await http.MultipartFile.fromPath(
          'images',
          file.path,
          contentType: MediaType(
            'image',
            extension == 'jpg' ? 'jpeg' : extension,
          ),
        ));
      }

      // Add video files
      for (var i = 0; i < videos.length; i++) {
        final file = videos[i];
        final fileName = file.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        request.files.add(await http.MultipartFile.fromPath(
          'videos',
          file.path,
          contentType: MediaType('video', extension),
        ));
      }

      // Send request
      final client = await _getCustomClient();
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          return Branch.fromJson(apiResponse.data);
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to create branch: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in createBranch: $e');
      return null;
    }
  }

  // Update wholesaler data
  Future<bool> updateWholesalerData(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/wholesaler/data'),
        headers: headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);
        return apiResponse.status == 200;
      } else {
        throw Exception('Failed to update wholesaler data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in updateWholesalerData: $e');
      return false;
    }
  }
  // Upload wholesaler logo
  Future<String?> uploadLogo(File logoFile) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/upload-logo');

      // Create multipart request
      var request = http.MultipartRequest('POST', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add logo file
      final fileName = logoFile.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      request.files.add(await http.MultipartFile.fromPath(
        'logo',
        logoFile.path,
        contentType: MediaType(
          'image',
          extension == 'jpg' ? 'jpeg' : extension,
        ),
      ));

      // Send request
      final client = await _getCustomClient();
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          return apiResponse.data['logoUrl'];
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to upload logo: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in uploadLogo: $e');
      return null;
    }
  }

  // Edit an existing branch with optional new images and videos
  Future<Branch?> editBranch({
    required String branchId,
    required String name,
    required Address location,
    required String phone,
    required String category,
    String? subCategory,
    required String description,
    List<File> newImages = const [],
    List<File> newVideos = const [],
  }) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/api/wholesaler/branches/$branchId');

      // Create multipart request
      var request = http.MultipartRequest('PUT', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add branch data as JSON
      final branchData = {
        'name': name,
        'country': location.country,
        'district': location.district,
        'city': location.city,
        'street': location.street,
        'postalCode': location.postalCode,
        'lat': location.lat,
        'lng': location.lng,
        'phone': phone,
        'category': category,
        'subCategory': subCategory,
        'description': description,
      };

      // Add branch data as a field
      request.fields['data'] = json.encode(branchData);

      // Add new image files if provided
      for (var image in newImages) {
        final fileName = image.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        request.files.add(await http.MultipartFile.fromPath(
          'images',
          image.path,
          contentType: MediaType(
            'image',
            extension == 'jpg' ? 'jpeg' : extension,
          ),
        ));
      }

      // Add new video files if provided
      for (var video in newVideos) {
        final fileName = video.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        request.files.add(await http.MultipartFile.fromPath(
          'videos',
          video.path,
          contentType: MediaType('video', extension),
        ));
      }

      // Send request
      final client = await _getCustomClient();
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          return Branch.fromJson(apiResponse.data);
        } else {
          throw Exception(apiResponse.message ?? 'Unknown error updating branch');
        }
      } else {
        if (!kReleaseMode) {
          print('Failed to update branch. Status: ${response.statusCode}, Body: ${response.body}');
        }
        throw Exception('Failed to update branch: ${response.statusCode}');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in editBranch: $e');
      }
      return null;
    }
  }


  // Get a specific branch by ID
  Future<Branch?> getBranch(String branchId) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/branches/$branchId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          return Branch.fromJson(apiResponse.data);
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to load branch: ${response.statusCode}');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in getBranch: $e');
      }
      return null;
    }
  }

  // Delete a branch by ID
  Future<bool> deleteBranch(String branchId) async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/wholesaler/branches/$branchId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);
        return apiResponse.status == 200;
      } else {
        throw Exception('Failed to delete branch: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in deleteBranch: $e');
      return false;
    }
  }

  // Update in wholesaler_service.dart

  Future<WholesalerReferralData?> getWholesalerReferralData() async {
    try {
      final headers = await _getHeaders();
      print('Making request to $baseUrl/api/wholesaler/referral');
      print('Headers: $headers');

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/referral'),
        headers: headers,
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body.substring(0, 200)}...'); // Log first 200 chars to avoid overwhelming logs
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          // Extract the data correctly from the nested structure
          final referralData = apiResponse.data['referralData'];
          final qrCode = apiResponse.data['qrCode'];

          if (referralData != null) {
            // Create with data from the referralData object
            return WholesalerReferralData(
              referralCode: referralData['referralCode'] ?? '',
              referralCount: referralData['referralCount'] ?? 0,
              points: referralData['points'] ?? 0,
              referralLink: referralData['referralLink'] ?? '',
              qrCode: qrCode, // QR code is at the top level of the data object
            );
          } else {
            // Fallback if referralData is missing but there's still some data
            print('Warning: referralData object is missing in the response');
            return WholesalerReferralData(
              referralCode: apiResponse.data['referralCode'] ?? '',
              referralCount: apiResponse.data['referralCount'] ?? 0,
              points: apiResponse.data['points'] ?? 0,
              referralLink: apiResponse.data['referralLink'] ?? '',
              qrCode: qrCode,
            );
          }
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to load referral data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getWholesalerReferralData: $e');
      return null;
    }
  }


// Since we're already getting QR code data in the referral response,
// we can simplify this method to use the cached value or make a new request if needed
  Future<String?> getWholesalerReferralQRCode() async {
    // If we already have QR code data from the referral response, use that
    // This method now just serves as a fallback
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/referral'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          return apiResponse.data['qrCode'];
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to load QR code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getWholesalerReferralQRCode: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> changeWholesalerDetails({
    required String currentPassword,
    String? newPassword,
    String? email,
    File? logoFile,
  }) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/api/wholesaler/details');

      // Create multipart request
      var request = http.MultipartRequest('PUT', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add current password (required for all changes)
      request.fields['currentPassword'] = currentPassword;

      // Add new password if provided
      if (newPassword != null && newPassword.isNotEmpty) {
        request.fields['newPassword'] = newPassword;
      }

      // Add email if provided
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }

      // Add logo file if provided
      if (logoFile != null) {
        final fileName = logoFile.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        request.files.add(await http.MultipartFile.fromPath(
          'logo',
          logoFile.path,
          contentType: MediaType(
            'image',
            extension == 'jpg' ? 'jpeg' : extension,
          ),
        ));
      }

      // Send request
      final client = await _getCustomClient();
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200) {
          return apiResponse.data;
        } else {
          throw Exception(apiResponse.message ?? 'Unknown error updating wholesaler details');
        }
      } else {
        print('Failed to update wholesaler details. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to update wholesaler details: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error in changeWholesalerDetails: $e');
      return null;
    }
  }
  Future<List<Wholesaler>> getAllWholesalers() async {
    try {
      final headers = await _getHeaders();
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesalers'),
        headers: headers,
      );

      print('\n=== WHOLESALER API RESPONSE DEBUG ===');
      print('Status Code: ${response.statusCode}');
      print('Raw Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        print('\nParsed API Response:');
        print('Status: ${apiResponse.status}');
        print('Message: ${apiResponse.message}');
        print('Data Type: ${apiResponse.data.runtimeType}');

        if (apiResponse.status == 200 && apiResponse.data != null) {
          if (apiResponse.data is List) {
            print('\nProcessing wholesalers list...');
            return List<Wholesaler>.from(
                apiResponse.data.map((wholesalerJson) {
                  print('\nProcessing wholesaler JSON:');
                  print('Raw wholesaler data: $wholesalerJson');
                  
                  // Check address field specifically
                  print('Address field in JSON: ${wholesalerJson['address']}');
                  
                  // Handle address field correctly
                  if (wholesalerJson['address'] == null) {
                    print('Warning: Address is null in the response');
                    // If address is missing, create a default one to avoid null issues
                    wholesalerJson['address'] = {
                      'country': '',
                      'district': '',
                      'city': '',
                      'street': '',
                      'postalCode': '',
                      'lat': 0.0,
                      'lng': 0.0,
                    };
                  }

                  final wholesaler = Wholesaler.fromJson(wholesalerJson);
                  print('Created wholesaler object:');
                  print('Business Name: ${wholesaler.businessName}');
                  print('Address: ${wholesaler.address?.toJson()}');
                  return wholesaler;
                })
            );
          } else {
            print('Error: API response data is not a list');
            return [];
          }
        } else {
          print('Error: API response status is not 200 or data is null');
          throw Exception(apiResponse.message);
        }
      } else {
        print('Error: HTTP status code is not 200');
        throw Exception('Failed to load wholesalers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getAllWholesalers: $e');
      return [];
    }
  }



}