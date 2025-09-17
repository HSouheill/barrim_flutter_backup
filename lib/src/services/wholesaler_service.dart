// services/wholesaler_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import '../models/wholesaler_model.dart';
import '../utils/token_storage.dart';
import 'api_service.dart';
import 'package:flutter/foundation.dart';

class WholesalerService {
  // Base URL for API requests
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

  // Get the auth token
  Future<String?> _getToken() async {
    return await _tokenStorage.getToken();
  }

  // Headers with authentication token and security headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'User-Agent': 'Barrim-Mobile-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
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
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          // Changed from 'wholesalerInfo' to 'wholesaler' to match backend
          final wholesaler = apiResponse.data['wholesaler'];
          return Wholesaler.fromJson(wholesaler);  // Assuming your fromJson method is correctly implemented
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to load wholesaler data');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in getWholesalerData: $e');
      }
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
    String? instagram,
    String? facebook,
    List<File> images = const [],
    List<File> videos = const [],
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final url = Uri.parse('$baseUrl/api/wholesaler/branches');
      
      // Branch creation in progress

      // Validate and compress files before upload
      List<File> processedImages = [];
      List<File> processedVideos = [];
      
      // Process images - compress if too large
      for (var image in images) {
        try {
          final fileSize = await image.length();
          final maxImageSize = 5 * 1024 * 1024; // 5MB limit
          
          if (fileSize > maxImageSize) {
            final compressedImage = await _compressImage(image);
            if (compressedImage != null) {
              final compressedSize = await compressedImage.length();
              
              // Double-check that compressed image is still under limit
              if (compressedSize <= maxImageSize) {
                processedImages.add(compressedImage);
              } else {
                // Clean up the temporary compressed file
                try {
                  await compressedImage.delete();
                } catch (e) {
                  if (!kReleaseMode) {
                    print('Error deleting temporary compressed file: $e');
                  }
                }
              }
            }
          } else {
            processedImages.add(image);
          }
        } catch (e) {
          if (!kReleaseMode) {
            print('Error processing image: $e');
          }
          // Continue with other images
        }
      }
      
      // Process videos - check size limit
      for (var video in videos) {
        try {
          final fileSize = await video.length();
          final maxVideoSize = 25 * 1024 * 1024; // Reduced to 25MB limit for better compatibility
          
          if (fileSize > maxVideoSize) {
            // Show user feedback about skipped video
            // Note: We can't show ScaffoldMessenger here as this is not in a UI context
          } else {
            processedVideos.add(video);
          }
        } catch (e) {
          if (!kReleaseMode) {
            print('Error processing video: $e');
          }
          // Continue with other videos
        }
      }
      
      // Check if we have any files to upload
      if (processedImages.isEmpty && processedVideos.isEmpty) {
        if (!kReleaseMode) {
          print('Warning: No valid files to upload after processing');
        }
      }
      
      // Calculate total request size to prevent 413 errors
      int totalRequestSize = 0;
      for (var image in processedImages) {
        try {
          totalRequestSize += await image.length();
        } catch (e) {
          if (!kReleaseMode) {
            print('Error calculating image size: $e');
          }
        }
      }
      for (var video in processedVideos) {
        try {
          totalRequestSize += await video.length();
        } catch (e) {
          if (!kReleaseMode) {
            print('Error calculating video size: $e');
          }
        }
      }
      
      // Add estimated overhead for multipart data (headers, form fields, etc.)
      totalRequestSize += 1024 * 1024; // Add 1MB overhead
      
      // If total size is still too large, remove largest files
      final maxTotalSize = 20 * 1024 * 1024; // 20MB total limit
      if (totalRequestSize > maxTotalSize) {
        
        // Sort images by size and keep only the smallest ones
        List<MapEntry<File, int>> imageSizes = [];
        for (var image in processedImages) {
          try {
            final size = await image.length();
            imageSizes.add(MapEntry(image, size));
          } catch (e) {
            if (!kReleaseMode) {
              print('Error getting image size: $e');
            }
          }
        }
        
        // Sort by size (smallest first) and keep only files that fit within limit
        imageSizes.sort((a, b) => a.value.compareTo(b.value));
        
        processedImages.clear();
        int currentSize = 0;
        for (var entry in imageSizes) {
          if (currentSize + entry.value <= maxTotalSize) {
            processedImages.add(entry.key);
            currentSize += entry.value;
          } else {
            // Clean up temporary compressed files
            if (entry.key.path.contains('compressed_')) {
              try {
                await entry.key.delete();
              } catch (e) {
                if (!kReleaseMode) {
                  print('Error deleting temporary file: $e');
                }
              }
            }
          }
        }
        
        // Do the same for videos
        List<MapEntry<File, int>> videoSizes = [];
        for (var video in processedVideos) {
          try {
            final size = await video.length();
            videoSizes.add(MapEntry(video, size));
          } catch (e) {
            if (!kReleaseMode) {
              print('Error getting video size: $e');
            }
          }
        }
        
        videoSizes.sort((a, b) => a.value.compareTo(b.value));
        
        processedVideos.clear();
        for (var entry in videoSizes) {
          if (currentSize + entry.value <= maxTotalSize) {
            processedVideos.add(entry.key);
            currentSize += entry.value;
          } else {
            // Skipping large video file
          }
        }
        
        if (!kReleaseMode) {
          print('After size optimization - Images: ${processedImages.length}, Videos: ${processedVideos.length}');
        }
      }

      // Create multipart request
      var request = http.MultipartRequest('POST', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add branch data as JSON - matching the Go backend structure
      final branchData = {
        'name': name,
        'country': location.country.isNotEmpty ? location.country : 'Lebanon',
        'district': location.district.isNotEmpty ? location.district : '',
        'city': location.city.isNotEmpty ? location.city : 'Beirut',
        'street': location.street.isNotEmpty ? location.street : '',
        'postalCode': location.postalCode.isNotEmpty ? location.postalCode : '',
        'lat': location.lat,
        'lng': location.lng,
        'phone': phone,
        'category': category.isNotEmpty ? category : 'Uncategorized',
        'subCategory': subCategory ?? '',
        'description': description.isNotEmpty ? description : 'No description provided',
        'instagram': instagram ?? '',
        'facebook': facebook ?? '',
      };

      // Add branch data as a field - this matches the Go backend expectation
      request.fields['data'] = json.encode(branchData);

      // Sending branch data

      // Add processed image files
      for (var image in processedImages) {
        final fileName = image.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        // Validate file exists and is readable
        if (!await image.exists()) {
          if (!kReleaseMode) {
            print('Warning: Image file does not exist');
          }
          continue;
        }

        try {
          request.files.add(await http.MultipartFile.fromPath(
            'images',
            image.path,
            contentType: MediaType(
              'image',
              extension == 'jpg' ? 'jpeg' : extension,
            ),
          ));
          // Image file added successfully
        } catch (e) {
          if (!kReleaseMode) {
            print('Error adding processed image file: $e');
          }
        }
      }

      // Add processed video files
      for (var video in processedVideos) {
        final fileName = video.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        // Validate file exists and is readable
        if (!await video.exists()) {
          if (!kReleaseMode) {
            print('Warning: Video file does not exist');
          }
          continue;
        }

        try {
          request.files.add(await http.MultipartFile.fromPath(
            'videos',
            video.path,
            contentType: MediaType('video', extension),
          ));
          // Video file added successfully
        } catch (e) {
          if (!kReleaseMode) {
            print('Error adding processed video file: $e');
          }
        }
      }

      // Send request
      final client = await _getCustomClient();
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          // The Go backend returns the branch data in the expected format
          // Create a Branch object from the response data
          final branchJson = apiResponse.data;
          
          // Ensure the response has the required fields
          if (branchJson['_id'] != null) {
            return Branch.fromJson(branchJson);
          } else {
            throw Exception('Invalid branch data received from server');
          }
        } else {
          throw Exception(apiResponse.message);
        }
      } else if (response.statusCode == 413) {
        throw Exception('Files are too large. Please use smaller images/videos (max 5MB for images, 50MB for videos).');
      } else if (response.statusCode == 400) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);
        throw Exception(apiResponse.message);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Wholesaler not found');
      } else if (response.statusCode == 500) {
        throw Exception('Server error - please try again later');
      } else {
        throw Exception('Failed to create branch: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in createBranch');
      }
      rethrow; // Re-throw to let the UI handle the error
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
      if (!kReleaseMode) {
        print('Error in updateWholesalerData: $e');
      }
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
      if (!kReleaseMode) {
        print('Error in uploadLogo: $e');
      }
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
    String? instagram,
    String? facebook,
    List<File> newImages = const [],
    List<File> newVideos = const [],
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final url = Uri.parse('$baseUrl/api/wholesaler/branches/$branchId');
      
      // Editing branch

      // Validate and compress files before upload
      List<File> processedImages = [];
      List<File> processedVideos = [];
      
      // Process new images - compress if too large
      for (var image in newImages) {
        try {
          final fileSize = await image.length();
          final maxImageSize = 5 * 1024 * 1024; // 5MB limit
          
          if (fileSize > maxImageSize) {
            final compressedImage = await _compressImage(image);
            if (compressedImage != null) {
              processedImages.add(compressedImage);
            }
          } else {
            processedImages.add(image);
          }
        } catch (e) {
          if (!kReleaseMode) {
            print('Error processing image: $e');
          }
          // Continue with other images
        }
      }
      
      // Process new videos - check size limit
      for (var video in newVideos) {
        try {
          final fileSize = await video.length();
          final maxVideoSize = 50 * 1024 * 1024; // 50MB limit
          
          if (fileSize > maxVideoSize) {
            // Skipping large video file
          } else {
            processedVideos.add(video);
          }
        } catch (e) {
          if (!kReleaseMode) {
            print('Error processing video: $e');
          }
          // Continue with other videos
        }
      }

      // Create multipart request
      var request = http.MultipartRequest('PUT', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add branch data as JSON - matching the Go backend structure
      final branchData = {
        'name': name,
        'country': location.country.isNotEmpty ? location.country : 'Lebanon',
        'district': location.district.isNotEmpty ? location.district : '',
        'city': location.city.isNotEmpty ? location.city : 'Beirut',
        'street': location.street.isNotEmpty ? location.street : '',
        'postalCode': location.postalCode.isNotEmpty ? location.postalCode : '',
        'lat': location.lat,
        'lng': location.lng,
        'phone': phone,
        'category': category.isNotEmpty ? category : 'Uncategorized',
        'subCategory': subCategory ?? '',
        'description': description.isNotEmpty ? description : 'No description provided',
        'instagram': instagram ?? '',
        'facebook': facebook ?? '',
      };

      // Debug logging for social media data
      if (!kReleaseMode) {
        print('WholesalerService.editBranch: Sending social media data - Instagram: "${instagram ?? ''}", Facebook: "${facebook ?? ''}"');
        print('WholesalerService.editBranch: Full branch data: $branchData');
      }

      // Add branch data as a field - this matches the Go backend expectation
      request.fields['data'] = json.encode(branchData);

      // Sending branch update data

      // Add processed new image files if provided
      for (var image in processedImages) {
        final fileName = image.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        // Validate file exists and is readable
        if (!await image.exists()) {
          if (!kReleaseMode) {
            print('Warning: Image file does not exist');
          }
          continue;
        }

        try {
          request.files.add(await http.MultipartFile.fromPath(
            'images',
            image.path,
            contentType: MediaType(
              'image',
              extension == 'jpg' ? 'jpeg' : extension,
            ),
          ));
          // New image file added successfully
        } catch (e) {
          if (!kReleaseMode) {
            print('Error adding processed new image file: $e');
          }
        }
      }

      // Add processed new video files if provided
      for (var video in processedVideos) {
        final fileName = video.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        // Validate file exists and is readable
        if (!await video.exists()) {
          if (!kReleaseMode) {
            print('Warning: Video file does not exist');
          }
          continue;
        }

        try {
          request.files.add(await http.MultipartFile.fromPath(
            'videos',
            video.path,
            contentType: MediaType('video', extension),
          ));
          // New video file added successfully
        } catch (e) {
          if (!kReleaseMode) {
            print('Error adding processed new video file: $e');
          }
        }
      }

      // Send request
      final client = await _getCustomClient();
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          // The Go backend returns the branch data in the expected format
          final branchJson = apiResponse.data;
          
          // Ensure the response has the required fields
          if (branchJson['_id'] != null) {
            return Branch.fromJson(branchJson);
          } else {
            throw Exception('Invalid branch data received from server');
          }
        } else {
          throw Exception(apiResponse.message ?? 'Failed to update branch');
        }
      } else if (response.statusCode == 413) {
        throw Exception('Files are too large. Please use smaller images/videos (max 5MB for images, 50MB for videos).');
      } else if (response.statusCode == 400) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);
        throw Exception(apiResponse.message);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Branch not found');
      } else if (response.statusCode == 500) {
        throw Exception('Server error - please try again later');
      } else {
        throw Exception('Failed to update branch: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in editBranch');
      }
      rethrow; // Re-throw to let the UI handle the error
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
      if (!kReleaseMode) {
        print('Error in deleteBranch: $e');
      }
      return false;
    }
  }

  // Update in wholesaler_service.dart

  Future<WholesalerReferralData?> getWholesalerReferralData() async {
    try {
      final headers = await _getHeaders();

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesaler/referral'),
        headers: headers,
      );

      // Response logged without sensitive data
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
      if (!kReleaseMode) {
        print('Error in getWholesalerReferralData: $e');
      }
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
      if (!kReleaseMode) {
        print('Error in getWholesalerReferralQRCode: $e');
      }
      return null;
    }
  }

  // Helper method to compress image
  Future<File?> _compressImage(File imageFile, {int maxWidth = 800, int maxHeight = 800, int quality = 85}) async {
    try {
      // Read the image file
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image if it's too large - be more aggressive with resizing
      img.Image resizedImage = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        // Calculate new dimensions maintaining aspect ratio
        double aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (image.width > image.height) {
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
        
        resizedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // Try different quality settings if the first attempt is still too large
      List<int> qualityLevels = [85, 70, 50, 30];
      File? compressedFile;
      
      for (int qualityLevel in qualityLevels) {
        // Encode as JPEG with quality setting
        final compressedBytes = img.encodeJpg(resizedImage, quality: qualityLevel);
        final compressedSize = compressedBytes.length;
        
        // If we're under 5MB, we're good
        if (compressedSize <= 5 * 1024 * 1024) {
          // Create temporary file
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(compressedBytes);
          
          compressedFile = tempFile;
          break;
        }
      }
      
      if (compressedFile == null) {
        return null;
      }
      
      return compressedFile;
    } catch (e) {
      if (!kReleaseMode) {
        print('Error compressing image: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> changeWholesalerDetails({
    String? currentPassword,
    String? newPassword,
    String? email,
    String? businessName,
    File? logoFile,
  }) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('$baseUrl/api/wholesaler/details');

      // Create multipart request
      var request = http.MultipartRequest('PUT', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add current password if provided (required for password changes)
      if (currentPassword != null && currentPassword.isNotEmpty) {
        request.fields['currentPassword'] = currentPassword;
      }

      // Add new password if provided
      if (newPassword != null && newPassword.isNotEmpty) {
        request.fields['newPassword'] = newPassword;
      }

      // Add email if provided
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }

      // Add business name if provided
      if (businessName != null && businessName.isNotEmpty) {
        request.fields['businessName'] = businessName;
      }

      // Add logo file if provided with size validation
      if (logoFile != null) {
        // Check file size (limit to 5MB)
        final fileSize = await logoFile.length();
        final maxSize = 5 * 1024 * 1024; // 5MB in bytes
        
        if (fileSize > maxSize) {
          // Try to compress the image
          final compressedFile = await _compressImage(logoFile);
          if (compressedFile != null) {
            final compressedSize = await compressedFile.length();
            if (compressedSize <= maxSize) {
              logoFile = compressedFile; // Use compressed file
            } else {
              throw Exception('Image is too large even after compression. Please use a smaller image.');
            }
          } else {
            throw Exception('Failed to compress image. Please use a smaller image.');
          }
        }

        final fileName = logoFile.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        // Validate file type
        if (!['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
          throw Exception('Logo file must be JPG, PNG, or GIF format');
        }

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
      } else if (response.statusCode == 413) {
        throw Exception('File size too large. Please use an image smaller than 5MB.');
      } else {
        throw Exception('Failed to update wholesaler details');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in changeWholesalerDetails: $e');
      }
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

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = ApiResponse.fromJson(responseData);

        if (apiResponse.status == 200 && apiResponse.data != null) {
          if (apiResponse.data is List) {
            return List<Wholesaler>.from(
                apiResponse.data.map((wholesalerJson) {
                  // Handle address field correctly
                  if (wholesalerJson['address'] == null) {
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
                  return wholesaler;
                })
            );
          } else {
            return [];
          }
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to load wholesalers');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in getAllWholesalers: $e');
      }
      return [];
    }
  }



}