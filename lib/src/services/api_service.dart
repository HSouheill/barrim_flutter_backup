import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

import '../models/branch_review.dart';
import '../models/notification_model.dart';
import '../models/review.dart';
import '../utils/api_constants.dart';
import '../utils/auth_manager.dart';
import '../utils/token_manager.dart';
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'https://barrim.online';
  static const String alternativeBaseUrl = 'https://104.131.188.174'; // Fallback IP address
  
  // Method to get the appropriate base URL
  static String getBaseUrl() {
    // You can add logic here to switch between URLs if needed
    return baseUrl;
  }

  // Headers for API requests
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  // Get stored token
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Store token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear token (for logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Helper method to make HTTP requests with standard client
  static Future<http.Response> _makeRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = http.Client();
    
    try {
      // Add timeout and retry logic for DNS issues
      switch (method.toUpperCase()) {
        case 'GET':
          return await client.get(uri, headers: headers).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection.');
            },
          );
        case 'POST':
          return await client.post(uri, headers: headers, body: body).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection.');
            },
          );
        case 'PUT':
          return await client.put(uri, headers: headers, body: body).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection.');
            },
          );
        case 'DELETE':
          return await client.delete(uri, headers: headers, body: body).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection.');
            },
          );
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } catch (e) {
      // Handle DNS resolution errors specifically
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('No address associated with hostname')) {
        throw Exception('Cannot connect to server. Please check:\n1. Your internet connection\n2. Try again in a few moments');
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  // Helper method to make multipart requests with standard client
  static Future<http.StreamedResponse> _makeMultipartRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    final client = http.Client();
    
    try {
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
    } finally {
      client.close();
    }
  }

  // Login request
  // Update the login function in api_service.dart
  // Login request that handles different user types
  static Future<Map<String, dynamic>> login(String emailOrPhone,
      String password) async {
    try {
      // Determine if the input is an email or phone number
      final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailOrPhone);
      // Updated phone regex to match login page
      final isPhone = RegExp(r'^(\+?[0-9]{8,15}|[0-9]{8,15})$').hasMatch(emailOrPhone.replaceAll(RegExp(r'[\s-]'), ''));

      if (!isEmail && !isPhone) {
        throw Exception('Invalid email or phone number format. For phone numbers, use format: +96170123456 or 70123456');
      }

      // Format phone number if it's a phone login
      String formattedInput = emailOrPhone;
      if (isPhone) {
        // Remove any spaces or special characters
        formattedInput = emailOrPhone.replaceAll(RegExp(r'[\s-]'), '');
        // Add country code if not present and number starts with 0
        if (formattedInput.startsWith('0')) {
          formattedInput = '+961${formattedInput.substring(1)}';
        }
        // Add country code if not present and number doesn't start with +
        else if (!formattedInput.startsWith('+')) {
          formattedInput = '+961$formattedInput';
        }
      }

      print('Formatted login input: $formattedInput'); // Debug print

      // Prepare request body based on input type
      Map<String, dynamic> requestBody = {
        'password': password,
      };

      // Add email or phone field based on input type
      if (isEmail) {
        requestBody['email'] = formattedInput;
      } else {
        requestBody['phone'] = formattedInput;
      }

      print('Request body: $requestBody'); // Debug print

      // Use custom client for handling self-signed certificates
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/login'),
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );

      // Print response for debugging
      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Successfully logged in
        if (responseData['data'] != null &&
            responseData['data']['token'] != null) {
          final token = responseData['data']['token'];
          await saveToken(token);
          await AuthManager.saveAuthData(token);

          // Verify token was saved
          final savedToken = await AuthManager.getToken();
          print("Saved token verification: ${savedToken != null
              ? 'Token saved'
              : 'Token not saved'}");

          // Store user type for future reference
          final prefs = await SharedPreferences.getInstance();
          String userType = responseData['data']['user']['userType'] ?? 'user';
          await prefs.setString('user_type', userType);

          // Based on user type, fetch and store appropriate data
          try {
            switch (userType) {
              case 'company':
                final companyData = await getCompanyData(token);
                await prefs.setString('company_data', jsonEncode(companyData));
                break;
              case 'wholesaler':
                final userData = await getUserProfile(token);
                await prefs.setString('wholesaler_info',
                    jsonEncode(userData['wholesalerInfo'] ?? {}));
                break;
              case 'serviceProvider':
                final userData = await getUserProfile(token);
                await prefs.setString('service_provider_info',
                    jsonEncode(userData['serviceProviderInfo'] ?? {}));
                break;
              case 'user':
              // Store basic user profile
                final userData = await getUserProfile(token);
                await prefs.setString('user_data', jsonEncode(userData));
                break;
            }
          } catch (e) {
            print('Error fetching specific user data on login: $e');
          }
        }
        return responseData;
      } else {
        final errorMsg = responseData['message'] ?? 'Login failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Login error: $e');
      throw Exception(e.toString().contains('Exception:')
          ? e.toString().split('Exception: ')[1]
          : 'Connection error. Please check your network.');
    }
  }


  // Sign up request for regular user
  static Future<Map<String, dynamic>> signupUser(
      Map<String, dynamic> userData) async {
    try {
      final Map<String, dynamic> requestData = {
        'email': userData['email'],
        'password': userData['password'],
        'fullName': userData['fullName'],
        'userType': 'user',
        'dateOfBirth': userData['dateOfBirth'] ?? '',
        'gender': userData['gender'] ?? '',
        'phone': userData['phone'] ?? '',
        'referralCode': userData['referralCode'] ?? '',
        'interestedDeals': userData['interestedDeals'] ?? [],
        'location': userData['location'] ?? null,
      };
      // await ApiService.signupBusiness(requestData);

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/signup'),
        headers: await _getHeaders(),
        body: jsonEncode(requestData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Successfully signed up
        if (responseData['data'] != null &&
            responseData['data']['token'] != null) {
          await saveToken(responseData['data']['token']);
        }
        return responseData;
      } else {
        // Handle error
        throw Exception(responseData['message'] ?? 'Signup failed');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Save user location
  static Future<void> saveUserLocation(Map<String, dynamic> userData) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/user/save-location'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userData['userId'],
          // Assuming you have a userId in userData
          'location': userData['location'],
        }),
      );

      final responseData = jsonDecode(response.body);
      print(responseData);
      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? 'Failed to save location');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> signupBusiness(Map<String, dynamic> userData, File? logoFile) async {
    try {
      // Create multipart request using custom client
      final uri = Uri.parse('$baseUrl/api/auth/signup-with-logo');
      
      // Prepare fields
      Map<String, String> fields = {};
      
      // Add text fields - basic user info
      fields['email'] = userData['email']?.toString() ?? '';
      fields['password'] = userData['password']?.toString() ?? '';
      fields['fullName'] = userData['fullName']?.toString() ?? '';

      // Format phone number with country code
      String phoneWithCode = '';
      if (userData['countryCode'] != null && userData['phone'] != null) {
        final cleanPhone = userData['phone'].toString().trim();
        final countryCode = userData['countryCode'].toString().trim();
        phoneWithCode = countryCode + cleanPhone;
        print("Formatted phone with code: $phoneWithCode");
      }
      fields['phone'] = phoneWithCode;

      // Add additional emails if they exist
      if (userData['additionalEmails'] != null && userData['additionalEmails'] is List) {
        List<String> additionalEmails = List<String>.from(userData['additionalEmails']);
        fields['additionalEmails'] = jsonEncode(additionalEmails);
      }

      // Add additional phones if they exist
      if (userData['additionalPhones'] != null && userData['additionalPhones'] is List) {
        List<Map<String, String>> additionalPhones = List<Map<String, String>>.from(userData['additionalPhones']);
        fields['additionalPhones'] = jsonEncode(additionalPhones);
      }
      

      // Add company-specific fields (directly, not nested under companyInfo)
      if (userData['companyInfo'] != null) {
        final companyInfo = userData['companyInfo'] as Map<String, dynamic>;
        fields['businessName'] = companyInfo['name']?.toString() ?? '';
        fields['category'] = companyInfo['category']?.toString() ?? '';
        fields['subCategory'] = companyInfo['subCategory']?.toString() ?? '';
        fields['referralCode'] = companyInfo['referralCode']?.toString() ?? '';
      }

      // Always add address/location fields from userData
      fields['country'] = userData['country']?.toString() ?? '';
      fields['district'] = userData['district']?.toString() ?? '';
      fields['city'] = userData['city']?.toString() ?? '';
      fields['street'] = userData['street']?.toString() ?? '';
      fields['postalCode'] = userData['postalCode']?.toString() ?? '';
      fields['lat'] = userData['lat']?.toString() ?? '0';
      fields['lng'] = userData['lng']?.toString() ?? '0';

      // Prepare files
      List<http.MultipartFile> files = [];
      
      // Add logo file if provided
      if (logoFile != null) {
        var stream = http.ByteStream(logoFile.openRead());
        var length = await logoFile.length();

        var multipartFile = http.MultipartFile(
          'logo',
          stream,
          length,
          filename: path.basename(logoFile.path),
          contentType: MediaType('image', _getImageMimeType(logoFile.path)),
        );

        files.add(multipartFile);
      }

      // Print all request fields for debugging
      print("Request fields:");
      fields.forEach((key, value) {
        print("$key: $value");
      });

      // Send the request using custom client
      final streamedResponse = await _makeMultipartRequest(
        'POST',
        uri,
        fields: fields,
        files: files,
      );
      
      var response = await http.Response.fromStream(streamedResponse);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Parse response
      Map<String, dynamic> parsedResponse;
      try {
        parsedResponse = json.decode(response.body);
      } catch (e) {
        print('Failed to parse response: $e');
        parsedResponse = {
          'message': 'Invalid server response: $response.body'
        };
      }

      return {
        'status': response.statusCode,
        'message': parsedResponse['message'] ?? 'Unknown response',
        'data': parsedResponse['data'],
      };
    } catch (e) {
      print('Exception during business signup: $e');
      return {
        'status': 500,
        'message': 'Failed to sign up: $e',
        'data': null,
      };
    }
  }

  // Sign up request for service provider with logo
  static Future<Map<String, dynamic>> signupServiceProviderWithLogo(
      Map<String, dynamic> userData, File? logoFile) async {
    try {
      // Create multipart request using custom client
      final uri = Uri.parse('$baseUrl/api/auth/signup-service-provider-with-logo');
      
      // Prepare headers
      Map<String, String> headers = await _getHeaders();
      headers.remove('Content-Type'); // Let MultipartRequest set this
      
      // Prepare fields
      Map<String, String> fields = {};
      fields['userData'] = jsonEncode(userData);
      
      // Prepare files
      List<http.MultipartFile> files = [];

      // Add logo file if provided
      if (logoFile != null) {
        var stream = http.ByteStream(logoFile.openRead());
        var length = await logoFile.length();

        var multipartFile = http.MultipartFile(
          'logo',
          stream,
          length,
          filename: path.basename(logoFile.path),
          contentType: MediaType('image', _getImageMimeType(logoFile.path)),
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
      
      var responseData = await http.Response.fromStream(streamedResponse);
      var decodedResponse = jsonDecode(responseData.body);

      if (responseData.statusCode == 201 || responseData.statusCode == 200) {
        // Check if the response indicates OTP was sent successfully
        if (decodedResponse['message'] != null && 
            decodedResponse['message'].toString().toLowerCase().contains('otp sent successfully')) {
          return decodedResponse;
        }
        
        // Handle case where token is provided (immediate login)
        if (decodedResponse['data'] != null &&
            decodedResponse['data']['token'] != null) {
          await saveToken(decodedResponse['data']['token']);
        }
        return decodedResponse;
      } else {
        throw Exception(decodedResponse['message'] ?? 'Signup failed');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

// Helper method to determine MIME type from file extension
  static String _getImageMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'jpeg';
      case '.png':
        return 'png';
      case '.gif':
        return 'gif';
      case '.webp':
        return 'webp';
      case '.bmp':
        return 'bmp';
      default:
        return 'octet-stream'; // Default binary type
    }
  }

  // Sign up request for service provider
  static Future<Map<String, dynamic>> signupServiceProvider(
      Map<String, dynamic> userData) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/auth/signup'),
        headers: await _getHeaders(),
        body: jsonEncode(userData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (responseData['data'] != null &&
            responseData['data']['token'] != null) {
          await saveToken(responseData['data']['token']);
        }
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Signup failed');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Store token
  static Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Get current user profile
  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/user/profile'),
        headers: await _getHeaders(),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to get user profile');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/forget-password'),
        headers: await _getHeaders(),
        body: jsonEncode({'email': email}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  static Future<void> resetPassword(String userId,
      String resetToken,
      String newPassword) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'resetToken': resetToken,
          'newPassword': newPassword,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      throw Exception('Failed to reset password: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> getCompaniesWithLocations() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/user/companies'),
        headers: await _getHeaders(),
      );
      print('getCompaniesWithLocations status: \\${response.statusCode}');
      print('getCompaniesWithLocations body: \\${response.body}');
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['data'] ?? []; // Ensure we always return a list
      } else {
        throw Exception('Failed to load companies: \\${response.statusCode}');
      }
    } catch (e) {
      print('Error in getCompaniesWithLocations: \\${e}');
      return []; // Return empty list on error
    }
  }

  // Validate token with server
  static Future<Map<String, dynamic>> validateToken(String token) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/auth/validate-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'valid': true, 'data': responseData};
      } else {
        return {'valid': false, 'message': responseData['message'] ?? 'Token validation failed'};
      }
    } catch (e) {
      return {'valid': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String userId,
    required String otp,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/verify-otp'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'otp': otp,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to verify OTP');
      }
    } catch (e) {
      throw Exception('Failed to verify OTP: ${e.toString()}');
    }
  }

  // In api_service.dart
  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/users/profile'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final userData = responseData['data'];

        print('User profile data received: $userData'); // Debug log
        return userData;
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      print('Error loading profile: $e'); // Debug log
      throw Exception('Failed to load profile: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getCompanyData(String token) async {
    try {
      final url = '${baseUrl}/api/companies/data';
      print('📡 [GET] Fetching company data from: $url');
      print('🔑 Using token: ${token.substring(
          0, 10)}...'); // Log first 10 chars of token for security

      final stopwatch = Stopwatch()
        ..start();
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      stopwatch.stop();
      print('⏱️  Request completed in ${stopwatch.elapsedMilliseconds}ms');
      print('🔄 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Successfully fetched company data');
        print('📊 Data structure:');
        print('  - Company Info: ${responseData['data']['companyInfo'] != null
            ? 'exists'
            : 'null'}');
        print('  - Location: ${responseData['data']['location'] != null
            ? 'exists'
            : 'null'}');
        print('  - Branches: ${responseData['data']['companyInfo']?['branches']
            ?.length ?? 0} branches found');

        return {
          'companyInfo': responseData['data']['companyInfo'] ?? {},
          'location': responseData['data']['location'] ?? {},
        };
      } else {
        final errorResponse = json.decode(response.body);
        print('❌ Failed to load company data: ${response.statusCode}');
        print('🔧 Error details: ${errorResponse['message'] ??
            'No error message'}');
        print('📄 Full response: ${response.body}');
        throw Exception('Failed to load company data: ${response.statusCode}');
      }
    } catch (e) {
      print('‼️ Exception in getCompanyData: $e');
      print('🔄 Attempting to parse error...');
      if (e is http.ClientException) {
        print('🌐 Network error: ${e.message}');
      }
      rethrow;
    }
  }

  //api_service.dart
// Function to upload image and save the branch details to the backend
  // Function to upload image and save the branch details to the backend
  static Future<void> uploadBranchData(Map<String, dynamic> branchData,
      List<File> images,
      List<File> videos,) async {
    try {
      // Make sure latitude and longitude are numbers, not strings
      if (branchData['latitude'] != null) {
        branchData['latitude'] =
        branchData['latitude'] is double ? branchData['latitude'] : double
            .parse(branchData['latitude'].toString());
      }
      if (branchData['longitude'] != null) {
        branchData['longitude'] =
        branchData['longitude'] is double ? branchData['longitude'] : double
            .parse(branchData['longitude'].toString());
      }

      // Fix the URL to match the backend route
      final uri = Uri.parse('$baseUrl/api/companies/branches');

      // Add headers
      Map<String, String> headers = await _getHeaders();

      // Remove file paths from the JSON data to avoid confusion
      var dataCopy = Map<String, dynamic>.from(branchData);
      dataCopy.remove('images'); // Don't send file paths in JSON

      // Extract location components from the location string
      String locationStr = dataCopy['location'] ?? '';
      List<String> addressParts = locationStr.split(', ');

      // Create location data structure that matches the backend model
      Map<String, dynamic> addressData = {
        'country': addressParts.length > 2 ? addressParts.last : '',
        'district': '', // Not available in the current UI
        'city': addressParts.length > 1 ? addressParts[1] : '',
        'street': addressParts.isNotEmpty ? addressParts[0] : '',
        'postalCode': '', // Not available in the current UI
        'lat': branchData['latitude'] ?? 0.0,
        'lng': branchData['longitude'] ?? 0.0
      };

      // Update the data structure to match what the backend expects
      dataCopy['location'] = addressData;

      // Also include the lat and lng at the top level as the backend seems to expect both
      dataCopy['lat'] = branchData['latitude'] ?? 0.0;
      dataCopy['lng'] = branchData['longitude'] ?? 0.0;

      // Remove the original latitude/longitude fields to avoid confusion
      dataCopy.remove('latitude');
      dataCopy.remove('longitude');

      // Prepare fields
      Map<String, String> fields = {};
      fields['data'] = jsonEncode(dataCopy);

      print('Sending branch data: ${jsonEncode(dataCopy)}');

      // Prepare files
      List<http.MultipartFile> files = [];

      // Upload images
      for (var image in images) {
        var extension = image.path
            .split('.')
            .last
            .toLowerCase();
        var contentType = 'image/jpeg'; // Default content type

        if (extension == 'png') {
          contentType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          contentType = 'image/jpeg';
        }

        files.add(await http.MultipartFile.fromPath(
          'images',
          image.path,
          contentType: MediaType.parse(contentType),
        ));
      }

      // Upload videos
      for (var video in videos) {
        var extension = video.path
            .split('.')
            .last
            .toLowerCase();
        var contentType = 'video/mp4'; // Default content type

        if (extension == 'mov') {
          contentType = 'video/quicktime';
        } else if (extension == 'avi') {
          contentType = 'video/x-msvideo';
        }

        files.add(await http.MultipartFile.fromPath(
          'videos',
          video.path,
          contentType: MediaType.parse(contentType),
        ));
      }

      // Send the request with a longer timeout using custom client
      final streamedResponse = await _makeMultipartRequest(
        'POST',
        uri,
        headers: headers,
        fields: fields,
        files: files,
      );
      
      var response = await http.Response.fromStream(streamedResponse);

      if (!kReleaseMode) {
        print('Branch upload response status: \\${response.statusCode}');
        print('Branch upload response body: \\${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (!kReleaseMode) {
          print('Branch data uploaded successfully');
        }
        return responseData['data']; // Return the created branch data
      } else {
        final responseData = jsonDecode(response.body);
        throw Exception(
            responseData['message'] ?? 'Failed to upload branch data');
      }
    } catch (e) {
      print('Error uploading branch data: $e');
      if (!kReleaseMode) {
        print('Error uploading branch data: \\${e}');
      }
      throw Exception('Failed to upload branch data: $e');
    }
  }

  static Future<List<dynamic>> getCompanyBranches(String token) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/companies/branches'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final branches = responseData['data'] ?? [];
        if (!kReleaseMode) {
          print('Retrieved \\${branches.length} branches');
        }

        // Debug print to check video data
        for (var branch in branches) {
          if (!kReleaseMode) {
            print('Branch \\${branch['name']} videos: \\${branch['videos']}');
          }
        }

        return branches;
      } else {
        if (!kReleaseMode) {
          print('Error response: \\${response.body}');
        }
        throw Exception('Failed to load branches: \\${response.statusCode}');
      }
    } catch (e) {
      print('Error getting branches: $e');
      if (!kReleaseMode) {
        print('Error getting branches: $e');
      }
      throw Exception('Network error: $e');
    }
  }

  // Delete a branch
  static Future<bool> deleteBranch(String token, String branchId) async {
    try {
      print('Deleting branch with ID: $branchId');

      final response = await _makeRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/companies/branches/$branchId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Delete branch response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to delete branch');
      }
    } catch (e) {
      print('Error deleting branch: $e');
      throw Exception('Network error: $e');
    }
  }


  static Future<void> updateBranch(String token,
      String branchId,
      Map<String, dynamic> branchData,
      List<File> newImages,
      List<File> newVideos,) async {
    try {
      // Fix the URL to match the backend route
      final uri = Uri.parse('$baseUrl/api/companies/branches/$branchId');

      // Add headers with authentication token
      Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Format data to match the backend expectations
      var dataCopy = Map<String, dynamic>.from(branchData);

      // Convert latitude/longitude to lat/lng
      if (dataCopy.containsKey('latitude')) {
        dataCopy['lat'] = dataCopy['latitude'];
        dataCopy.remove('latitude');
      }
      if (dataCopy.containsKey('longitude')) {
        dataCopy['lng'] = dataCopy['longitude'];
        dataCopy.remove('longitude');
      }

      // Add structured location data
      if (dataCopy.containsKey('location') && dataCopy['location'] is String) {
        String locationStr = dataCopy['location'];
        List<String> addressParts = locationStr.split(', ');

        Map<String, dynamic> address = {
          'street': addressParts.isNotEmpty ? addressParts[0] : '',
          'city': addressParts.length > 1 ? addressParts[1] : '',
          'district': '',
          'country': addressParts.length > 2 ? addressParts.last : '',
          'postalCode': '',
          'lat': dataCopy['lat'] ?? 0.0,
          'lng': dataCopy['lng'] ?? 0.0,
        };

        dataCopy['location'] = address;
      }

      // Prepare fields
      Map<String, String> fields = {};
      fields['data'] = jsonEncode(dataCopy);

      // Prepare files
      List<http.MultipartFile> files = [];

      // Upload any new images
      for (var image in newImages) {
        var extension = image.path
            .split('.')
            .last
            .toLowerCase();
        var contentType = 'image/jpeg';

        if (extension == 'png') {
          contentType = 'image/png';
        }

        files.add(await http.MultipartFile.fromPath(
          'images',
          image.path,
          contentType: MediaType.parse(contentType),
        ));
      }

      for (var video in newVideos) {
        var extension = video.path
            .split('.')
            .last
            .toLowerCase();
        var contentType = 'video/mp4';

        if (extension == 'mov') {
          contentType = 'video/quicktime';
        } else if (extension == 'avi') {
          contentType = 'video/x-msvideo';
        }

        files.add(await http.MultipartFile.fromPath(
          'videos',
          video.path,
          contentType: MediaType.parse(contentType),
        ));
      }

      // Send the request using custom client
      final streamedResponse = await _makeMultipartRequest(
        'PUT',
        uri,
        headers: headers,
        fields: fields,
        files: files,
      );
      
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Failed to update branch: ${response.body}');
      }

      print('Branch updated successfully');
    } catch (e) {
      print('Error updating branch: $e');
      throw Exception('Failed to update branch: $e');
    }
  }


  // Add this method to api_service.dart
  static Future<bool> updateCompanyData(String token,
      Map<String, dynamic> data) async {
    try {
      final response = await _makeRequest(
        'PUT',
        Uri.parse('${baseUrl}/api/companies/data'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Ensure this is correct
        },
        body: jsonEncode(data),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to update: ${response.body}');
      }
    } catch (e) {
      print('Error updating company data: $e');
      rethrow;
    }
  }

  //api_Service.dart
  static Future<List<Map<String, dynamic>>> getAllBranches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse('${baseUrl}/api/all-branches'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('Response body: ${response.body}');
        final responseData = json.decode(response.body);
        if (responseData['status'] == 200) {
          // Return empty list if data is null, otherwise return the data
          if (responseData['data'] == null) {
            print('No branches found - returning empty list');
            return [];
          }
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to fetch branches');
        }
      } else {
        throw Exception('Failed to fetch branches: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting all branches: $e');
      throw Exception('Failed to get branches: $e');
    }
  }

  static String getFullImageUrl(String imageUrl) {
    // Check if the URL is already complete
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // Ensure consistent format
    if (!imageUrl.startsWith('/')) {
      imageUrl = '/$imageUrl';
    }

    // Return the full URL
    return '$baseUrl$imageUrl';
  }

// Helper method to extract first valid image URL from a branch
  static String? getFirstImageUrl(Map<String, dynamic> branch) {
    if (!branch.containsKey('images')) {
      return null;
    }

    dynamic images = branch['images'];
    if (images is List && images.isNotEmpty) {
      return getFullImageUrl(images[0].toString());
    } else if (images is String && images.isNotEmpty) {
      List<String> imageList = images.split(',');
      if (imageList.isNotEmpty) {
        return getFullImageUrl(imageList[0]);
      }
    }

    return null;
  }

// A method to cache images for better performance
  static Future<void> precacheImages(BuildContext context,
      List<Map<String, dynamic>> branches) async {
    for (var branch in branches) {
      String? imageUrl = getFirstImageUrl(branch);
      if (imageUrl != null) {
        try {
          // Use standard HTTP client for secure image loading
          final client = http.Client();
          final response = await client.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            // Create a memory image provider for caching
            final imageProvider = MemoryImage(response.bodyBytes);
            await precacheImage(imageProvider, context);
          }
        } catch (e) {
          print('Failed to precache image: $imageUrl - $e');
        }
      }
    }
  }

  // ApiService:
  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String email,
    required String currentPassword,
  }) async {
    try {
      final payload = {
        'fullName': fullName,
        'email': email,
        'currentPassword': currentPassword,
      };

      print('Sending profile update payload: $payload'); // Debug log

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/users/profile'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      print('Error updating profile: $e'); // Debug log
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto(File imageFile) async {
    try {
      print('Sending profile picture: $imageFile'); // Debug log
      final uri = Uri.parse('$baseUrl/api/upload-user-profile-photo');
      
      // Add headers
      Map<String, String> headers = await _getHeaders();

      // Prepare files
      List<http.MultipartFile> files = [];
      
      // Add image file
      var extension = imageFile.path
          .split('.')
          .last
          .toLowerCase();
      var contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

      files.add(await http.MultipartFile.fromPath(
        'photo',
        imageFile.path,
        contentType: MediaType.parse(contentType),
      ));

      // Send the request using custom client
      final streamedResponse = await _makeMultipartRequest(
        'POST',
        uri,
        headers: headers,
        files: files,
      );
      
      var response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to upload profile photo');
      }
    } catch (e) {
      throw Exception('Failed to upload profile photo: ${e.toString()}');
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/change-password'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }

  // Get user data specifically for regular users (userType = "user")
  static Future<Map<String, dynamic>> getUserData() async {
    try {
      print('ApiService: Fetching regular user data - started');

      // Get the auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('ApiService: Token status: ${token != null ? "exists" : "null"}');

      if (token == null) {
        print('ApiService: Not authenticated - throwing error');
        throw Exception('Not authenticated');
      }

      // Make API request to the user data endpoint
      final url = '${baseUrl}/api/users/get-user-data';
      print('ApiService: Making request to: $url');

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('ApiService: Response status: ${response.statusCode}');

      // Check response status
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('ApiService: User data retrieved successfully');

        if (responseData['status'] == 200) {
          // Store the data locally for offline access
          final userData = responseData['data'] as Map<String, dynamic>;
          prefs.setString('user_data', jsonEncode(userData));

          return userData;
        } else {
          print('ApiService: Error in response: ${responseData['message']}');
          throw Exception(responseData['message'] ?? 'Failed to get user data');
        }
      } else if (response.statusCode == 404) {
        throw Exception('User not found or not a regular user');
      } else {
        print('ApiService: Non-200 status code received');
        throw Exception('Failed to get user data: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService: Error in getUserData: $e');
      throw Exception('Error getting user data: $e');
    }
  }

  static Future<Map<String, dynamic>> updatePersonalInformation({
    required String phone,
    required String dateOfBirth,
    required String gender,
    Map<String, dynamic>? location,
  }) async {
    try {
      final payload = {
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        if (location != null) 'location': location,
      };

      print('Sending personal info update: $payload');

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/users/personal-info'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update local storage with new data
        final prefs = await SharedPreferences.getInstance();
        final currentUserData = await getUserData();

        // Merge updated fields
        final updatedData = {
          ...currentUserData,
          'phone': phone,
          'dateOfBirth': dateOfBirth,
          'gender': gender,
          if (location != null) 'location': location,
        };

        await prefs.setString('user_data', jsonEncode(updatedData));

        return responseData;
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to update personal information');
      }
    } catch (e) {
      print('Error updating personal information: $e');
      throw Exception('Failed to update personal information: ${e.toString()}');
    }
  }

  // Referral System Functions

  /// Get the user's referral data including code, points, and referral count
  static Future<Map<String, dynamic>> getReferralData() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/users/referral-data'),
        headers: await _getHeaders(),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData['data'] ?? {};
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to get referral data');
      }
    } catch (e) {
      throw Exception('Failed to get referral data: ${e.toString()}');
    }
  }

  /// Submit a referral code (used when a new user signs up with a referral code)
  static Future<Map<String, dynamic>> submitReferralCode(
      String referralCode) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/handle-referral'),
        headers: await _getHeaders(),
        body: jsonEncode({'referralCode': referralCode}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData['data'] ?? {};
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to process referral');
      }
    } catch (e) {
      throw Exception('Failed to process referral: ${e.toString()}');
    }
  }

  /// Get the list of available rewards that can be redeemed with points
  static Future<List<dynamic>> getAvailableRewards() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/rewards'),
        headers: await _getHeaders(),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData['data'] ?? [];
      } else {
        throw Exception(responseData['message'] ?? 'Failed to get rewards');
      }
    } catch (e) {
      throw Exception('Failed to get rewards: ${e.toString()}');
    }
  }

  /// Redeem points for a specific reward
  static Future<Map<String, dynamic>> redeemPoints(String rewardId,
      int points) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/rewards/redeem'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'rewardId': rewardId,
          'points': points,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData['data'] ?? {};
      } else {
        throw Exception(responseData['message'] ?? 'Failed to redeem points');
      }
    } catch (e) {
      throw Exception('Failed to redeem points: ${e.toString()}');
    }
  }

  /// Share referral link via platform sharing dialog
  static Future<void> shareReferralLink(String referralLink) async {
    try {
      await Share.share(
        'Join me on Barrem! Use my referral link: $referralLink',
        subject: 'Barrem Referral',
      );
    } catch (e) {
      throw Exception('Failed to share referral link: ${e.toString()}');
    }
  }

  /// Copy referral code or link to clipboard
  static Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      throw Exception('Failed to copy to clipboard: ${e.toString()}');
    }
  }


  //api_service.dart
  static Future<Map<String, dynamic>> getServiceProviderDetails() async {
    try {
      print('ApiService: Fetching service provider details - started');

      // Get the auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('ApiService: Token status: ${token != null ? "exists" : "null"}');

      if (token == null) {
        print('ApiService: Not authenticated - throwing error');
        throw Exception('Not authenticated');
      }

      // Make API request to the service provider details endpoint
      final url = '${baseUrl}/api/service-provider/details'; // Updated to include /api/
      print('ApiService: Making request to: $url');

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('ApiService: Response status: ${response.statusCode}');

      // Check response status
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('ApiService: Service provider data retrieved successfully');

        if (responseData['status'] == 200) {
          // Store the data locally for offline access
          final providerData = responseData['data'] as Map<String, dynamic>;
          prefs.setString('service_provider_data', jsonEncode(providerData));

          return providerData;
        } else {
          print('ApiService: Error in response: ${responseData['message']}');
          throw Exception(
              responseData['message'] ?? 'Failed to get service provider data');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Service provider not found');
      } else if (response.statusCode == 403) {
        throw Exception(
            'Access denied. Only service providers can access this data');
      } else {
        print('ApiService: Non-200 status code received');
        throw Exception(
            'Failed to get service provider data: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService: Error in getServiceProviderDetails: $e');

      // Try to return cached data if available
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString('service_provider_data');
        if (cachedData != null) {
          print('ApiService: Returning cached service provider data');
          return jsonDecode(cachedData);
        }
      } catch (_) {
        // If cache access fails, continue with the original error
      }

      throw Exception('Error getting service provider data: $e');
    }
  }

  // Add these methods to your ApiService class

  static Future<void> clearServiceProviderCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('service_provider_data');
      print('ApiService: Cleared service provider cache');
    } catch (e) {
      print('ApiService: Error clearing cache: $e');
    }
  }


  // Fetch service provider logo
  static Future<String?> getServiceProviderLogo(String providerId) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/service-providers/$providerId/logo'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          return '$baseUrl${responseData['data']['logoPath']}';
        }
      }
      return null;
    } catch (e) {
      print('Error fetching logo for provider $providerId: $e');
      return null;
    }
  }

  //api_service.dart
  static Future<List<dynamic>> getAllServiceProviders() async {
    try {
      print('ApiService: Fetching all service providers - started');
      final url = '${baseUrl}/api/service-providers/all';
      print('ApiService: Making request to: $url');
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
      );
      print('ApiService: Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('ApiService: Service providers data retrieved successfully');
        print('ApiService: Response data structure: $responseData');
        if (responseData['status'] == 200 && responseData['data'] != null) {
          var data = responseData['data'];
          print('ApiService: Data type: ${data.runtimeType}');
          print('ApiService: Data content: $data');
          if (data is Map<String, dynamic> &&
              data.containsKey('serviceProviders')) {
            return data['serviceProviders'] as List<dynamic>;
          } else if (data is List<dynamic>) {
            return data;
          } else {
            return [data];
          }
        } else {
          print('ApiService: Error in response: ${responseData['message']}');
          throw Exception(responseData['message'] ??
              'Failed to get service providers data');
        }
      } else {
        print(
            'ApiService: Non-200 status code received: ${response.statusCode}');
        throw Exception(
            'Failed to get service providers: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService: Error in getAllServiceProviders: $e');
      throw Exception('Error getting service providers: $e');
    }
  }

  // Test connection method
  static Future<bool> testConnection() async {
    try {
      print('Testing connection to: $baseUrl');
      
      // Try to connect to the base URL
      final response = await _makeRequest(
        'GET',
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('Connection test successful: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 404; // 404 is OK for base URL
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // Add this method to your ApiService class to test the connection
  static Future<void> debugApiConnection() async {
    try {
      // First, try a basic GET to the base URL to check if server is reachable
      final baseResponse = await _makeRequest(
        'GET',
        Uri.parse(baseUrl),
      );
      print('Base URL response: ${baseResponse.statusCode}');

      // Now let's try each service provider endpoint to see which one works

      // 1. Try the exact route in the error - without trailing slash
      final url1 = '${baseUrl}/api/service-providers';
      final response1 = await _makeRequest(
        'GET',
        Uri.parse(url1),
      );
      print('URL 1 (${url1}) status: ${response1.statusCode}');

      // 2. Try with trailing slash
      final url2 = '${baseUrl}/api/service-providers/';
      final response2 = await _makeRequest(
        'GET',
        Uri.parse(url2),
      );
      print('URL 2 (${url2}) status: ${response2.statusCode}');

      // 3. Try all providers route
      final url3 = '${baseUrl}/api/service-providers/all';
      final response3 = await _makeRequest(
        'GET',
        Uri.parse(url3),
      );
      print('URL 3 (${url3}) status: ${response3.statusCode}');

      // 4. Check the specific route
      final sampleProviderId = "sample_id"; // Replace with a valid ID if you have one
      final url4 = '${baseUrl}/api/service-providers/${sampleProviderId}';
      final response4 = await _makeRequest(
        'GET',
        Uri.parse(url4),
      );
      print('URL 4 (${url4}) status: ${response4.statusCode}');

      // Print the actual route list from your server
      final routesUrl = '${baseUrl}/api/routes'; // You might need to add this debug endpoint to your backend
      try {
        final routesResponse = await _makeRequest(
          'GET',
          Uri.parse(routesUrl),
        );
        print('Routes response: ${routesResponse.statusCode} - ${routesResponse.body}');
      } catch (e) {
        print('Routes endpoint not available: $e');
      }
    } catch (e) {
      print('Debug connection error: $e');
    }
  }


  // Updated method to get reviews for a service provider
  static Future<List<Review>> getReviewsForProvider(String providerId) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/service-providers/$providerId/reviews'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 200 && responseData['data'] != null) {
          final List<dynamic> reviewsJson = responseData['data'];
          return reviewsJson.map((json) => Review.fromJson(json)).toList();
        }
      }

      print('Error fetching reviews: ${response.statusCode}, ${response.body}');
      return [];
    } catch (e) {
      print('Exception when fetching reviews: $e');
      return [];
    }
  }

  // Updated method to create a review
  static Future<bool> createReview(Review review) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/reviews'),
        headers: await _getHeaders(),
        body: jsonEncode(review.toJson()),
      );

      print('Create review response: ${response.statusCode}, ${response.body}');

      return response.statusCode == 201;
    } catch (e) {
      print('Error creating review: $e');
      return false;
    }
  }

  // Helper method to get auth token
  static Future<String> getAuthToken() async {
    // Implement based on your auth storage mechanism
    // Example using shared preferences:
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  //api_service.dart
  static Future<Map<String, dynamic>> addToFavorites(String branchId,
      String token) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'branchId': branchId,
        }),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Branch added to favorites',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to add to favorites',
        };
      }
    } catch (e) {
      print('Error adding to favorites: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again later.',
      };
    }
  }

  // Remove a branch from favorites
  static Future<Map<String, dynamic>> removeFromFavorites(String branchId,
      String token) async {
    try {
      final response = await _makeRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/users/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'branchId': branchId,
        }),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Branch removed from favorites',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ??
              'Failed to remove from favorites',
        };
      }
    } catch (e) {
      print('Error removing from favorites: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again later.',
      };
    }
  }

  // Get all favorite branches
  static Future<dynamic> getFavoriteBranches(String token) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('${baseUrl}/api/users/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('API Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      // Check if request was successful
      if (response.statusCode == 200) {
        return responseData['data'] ?? [];
      } else {
        print('API Error: ${responseData['message']}');
        return [];
      }
    } catch (e) {
      print('Exception in getFavoriteBranches: $e');
      return [];
    }
  }

  // Check if a branch is in favorites
  static Future<bool> isBranchFavorite(String branchId, String token) async {
    try {
      final favorites = await getFavoriteBranches(token);
      return favorites.any((branch) =>
      branch['branch'] != null &&
          branch['branch']['_id'] == branchId
      );
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // Add to your api_service.dart file
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    // Make sure the path doesn't start with a double slash
    final path = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return '$baseUrl/$path';
  }

  // In api_service.dart
// Add a service provider to favorites
  Future<bool> addServiceProviderToFavorites(String serviceProviderId) async {
    try {
      final headers = await _getAuthToken();

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/favorite-providers'),
        headers: headers,
        body: jsonEncode({
          'serviceProviderId': serviceProviderId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to add to favorites: ${response.body}');
      }
    } catch (e) {
      print('Error adding to favorites: $e');
      return false;
    }
  }

  Future<bool> removeServiceProviderFromFavorites(
      String serviceProviderId) async {
    try {
      final headers = await _getAuthToken();

      // Print the service provider ID being sent
      print('Removing service provider ID: $serviceProviderId');

      // Create the request body
      final body = jsonEncode({
        'serviceProviderId': serviceProviderId,
      });

      // Print the request body for debugging
      print('Request body: $body');

              // Use standard client for DELETE request with body
        final client = http.Client();
        final request = http.Request(
          'DELETE',
          Uri.parse('$baseUrl/api/users/favorite-providers'),
        );

      // Set headers and body
      request.headers.addAll(headers);
      request.body = body;

      // Send the request using custom client
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      print('Remove response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to remove from favorites: ${response.body}');
      }
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }


  Future<bool> isServiceProviderFavorited(String serviceProviderId) async {
    try {
      final headers = await _getAuthToken();

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/users/favorite-providers'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'] is List) {
          List<dynamic> favorites = data['data'];
          return favorites.any((provider) =>
          provider['_id'] == serviceProviderId);
        }
        return false;
      } else {
        throw Exception('Failed to check favorites: ${response.body}');
      }
    } catch (e) {
      print('Error checking favorites: $e');
      return false;
    }
  }

// Toggle favorite status (add or remove)
  Future<bool> toggleFavoriteStatus(String? serviceProviderId,
      bool currentlyFavorited) async {
    if (serviceProviderId == null || serviceProviderId.isEmpty) {
      print('Error: serviceProviderId is null or empty');
      return false;
    }

    if (currentlyFavorited) {
      return await removeServiceProviderFromFavorites(serviceProviderId);
    } else {
      return await addServiceProviderToFavorites(serviceProviderId);
    }
  }

  // In api_service.dart
  // In getFavoriteServiceProviders() in api_service.dart
  Future<dynamic> getFavoriteServiceProviders() async {
    try {
      final headers = await _getAuthToken();

      // Check if headers contains Authorization
      if (headers['Authorization'] == null) {
        print('Error: No Authorization header available');
        return [];
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/users/favorite-providers'),
        headers: headers,
      );

      print('Service Providers Response Raw: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Service Providers Decoded Data: $data');
        // Return the full response - let the calling function handle the structure
        return data;
      } else {
        print('Failed to fetch favorite providers: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching favorite providers: $e');
      return [];
    }
  }

  Future<Map<String, String>> _getAuthToken() async {
    // Get the token from shared preferences or wherever it's stored
    final token = await _getToken(); // Your method to get the token

    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      print('Warning: No token available for API request');
    }

    return headers;
  }

  //  api_service.dart

  static Future<Map<String, dynamic>> getBranchComments(String branchId,
      {int page = 1, int limit = 10}) async {
    try {
      final Uri uri = Uri.parse(
          '$baseUrl/api/branches/$branchId/comments?page=$page&limit=$limit');

      print('Fetching comments from: $uri');

      final response = await _makeRequest(
        'GET',
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // If we received data but no comments yet, return an empty list
        if (responseData['data'] == null ||
            responseData['data']['comments'] == null) {
          return {
            'status': 'success',
            'message': responseData['message'] ?? 'No comments found',
            'data': {
              'comments': [],
              'total': 0,
              'page': page,
              'limit': limit,
            }
          };
        }

        return responseData;
      } else {
        print('Failed to load comments: ${response.statusCode}');
        print('Response body: ${response.body}');

        // Return a formatted error response
        return {
          'status': 'error',
          'message': 'Failed to load comments (Status: ${response.statusCode})',
          'data': {
            'comments': [],
            'total': 0,
            'page': page,
            'limit': limit,
          }
        };
      }
    } catch (e) {
      print('Error loading comments: $e');

      // Return a formatted error response for exceptions
      return {
        'status': 'error',
        'message': 'Error loading comments: $e',
        'data': {
          'comments': [],
          'total': 0,
          'page': page,
          'limit': limit,
        }
      };
    }
  }

// Post a new comment to a branch
  static Future<Map<String, dynamic>> createBranchComment(String branchId,
      String comment, int rating) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final Uri uri = Uri.parse(
          '$baseUrl/api/companies/branches/$branchId/comments');

      print('Posting comment to: $uri');
      print('Comment: $comment, Rating: $rating');

      final response = await _makeRequest(
        'POST',
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'comment': comment,
          'rating': rating,
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        print('Failed to post comment: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
            'Failed to post comment (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Error posting comment: $e');
      throw Exception('Error posting comment: $e');
    }
  }

  static Future<Map<String, dynamic>> replyToBranchComment(String commentId,
      String reply) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final Uri uri = Uri.parse(
          '$baseUrl/api/companies/comments/$commentId/reply');

      print('Posting reply to comment: $uri');
      print('Reply: $reply');

      final response = await _makeRequest(
        'POST',
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'reply': reply,
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        print('Failed to post reply: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
            'Failed to post reply (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Error posting reply: $e');
      throw Exception('Error posting reply: $e');
    }
  }

  static Future<bool> updateServiceProviderSocialLinks({
    required String website,
    required String facebook,
    required String instagram,

  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        debugPrint('No auth token found');
        return false;
      }

      final response = await _makeRequest(
        'PUT',
        Uri.parse('${baseUrl}/api/service-provider/social-links'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'socialLinks': {
            'website': website,
            'facebook': facebook,
            'instagram': instagram,
          }
        }),
      );

      debugPrint('Social links update response: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['status'] == 200;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating social links: $e');
      return false;
    }
  }

  // Add this method to the ApiService class

  /// Sign up request for wholesaler
static Future<Map<String, dynamic>> signupWholesaler(
    Map<String, dynamic> userData) async {
  try {
    // Format phone number if needed
    String phone = userData['phone'].toString();
    if (!phone.startsWith('+')) {
      phone = '+961${phone.startsWith('0') ? phone.substring(1) : phone}';
    }

    // Build the request data according to backend expectations
    final Map<String, dynamic> requestData = {
      'email': userData['email'],
      'password': userData['password'],
      'fullName': userData['fullName'],
      'userType': 'wholesaler',
      'phone': phone,
      'wholesalerData': {
        'businessName': userData['wholesalerInfo']['businessName'],
        'category': userData['wholesalerInfo']['category'],
        'subCategory': userData['wholesalerInfo']['subCategory'] ?? '',
        'phones': userData['wholesalerInfo']['phones'] ?? [phone],
        'emails': userData['wholesalerInfo']['emails'] ?? [userData['email']],
        'contactInfo': {
          'address': {
            'country': userData['location']['country'],
            'district': userData['location']['district'],
            'city': userData['location']['city'],
            'street': userData['location']['street'],
            'postalCode': userData['location']['postalCode'],
            'lat': userData['location']['coordinates']['lat'],
            'lng': userData['location']['coordinates']['lng'],
          },
          'whatsapp': userData['wholesalerInfo']['contactInfo']?['whatsapp'] ?? '',
          'website': userData['wholesalerInfo']['contactInfo']?['website'] ?? '',
          'facebook': userData['wholesalerInfo']['contactInfo']?['facebook'] ?? '',
        },
        'socialMedia': {
          'facebook': userData['wholesalerInfo']['socialMedia']?['facebook'] ?? '',
          'instagram': userData['wholesalerInfo']['socialMedia']?['instagram'] ?? '',
        },
        'referralCode': userData['wholesalerInfo']['referralCode'] ?? '',
      }
    };

    // Log the final request data
    print("Final request data for wholesaler signup:");
    print(jsonEncode(requestData));

    // Make the API request
    final response = await _makeRequest(
      'POST',
      Uri.parse('$baseUrl/api/auth/signup'),
      headers: await _getHeaders(),
      body: jsonEncode(requestData),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'message': responseData['message'] ?? 'Signup successful. Please verify your phone number.',
        'phone': phone,
        'needsVerification': true,
      };
    } else {
      throw Exception(responseData['message'] ?? 'Wholesaler signup failed');
    }
  } catch (e) {
    print('Exception during wholesaler signup: $e');
    throw Exception('Failed to sign up wholesaler: ${e.toString()}');
  }
}

  /// Delete user account
  static Future<bool> deleteUserAccount() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await _makeRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Clear stored data after successful deletion
        await clearToken();
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to delete account');
      }
    } catch (e) {
      print('Error deleting user account: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

    Future<Map<String, dynamic>> smsverifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      // Normalize phone number to E.164 format
      String normalizedPhone = phone.trim();

      // Remove all non-digit characters
      normalizedPhone = normalizedPhone.replaceAll(RegExp(r'[^\d+]'), '');

      // Ensure it starts with country code
      if (!normalizedPhone.startsWith('+')) {
        if (normalizedPhone.startsWith('0')) {
          normalizedPhone = '+961${normalizedPhone.substring(1)}';
        } else if (normalizedPhone.startsWith('961')) {
          normalizedPhone = '+$normalizedPhone';
        } else {
          normalizedPhone = '+961$normalizedPhone';
        }
      }

      print('OTP Verification - Normalized Phone: $normalizedPhone');

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/sms-verify-otp'),
       headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
                'phone': normalizedPhone,
                'otp': otp,
              }),
      );


      print('OTP Verification Response Status: ${response.statusCode}');
      print('OTP Verification Response Body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['data']?['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', responseData['data']['token']);
        }
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP verified successfully',
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'OTP verification failed',
          'status': response.statusCode,
          'error': responseData['error'] ?? 'Unknown error occurred',
        };
      }
    } catch (error) {
      print('OTP Verification Error: $error');
      return {
        'success': false,
        'message': 'Network or server error occurred',
        'error': error.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> resendOtp({
    required String phone,
  }) async {
    try {
      // Get API key or any existing auth tokens if available
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api_key') ?? '';
      final tempToken = prefs.getString('temp_auth_token') ?? '';


      // Build headers with authentication
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $tempToken',  // Use temporary token if available
        'X-API-Key': apiKey,                   // Include API key if your backend expects it
      };

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/resend-otp'),
       headers: {'Content-Type': 'application/json'},
       body: jsonEncode({
          'phone': phone,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to resend OTP',
          'status': response.statusCode,
        };
      }
    } catch (error) {
      return {
        'success': false,
        'message': 'Network or server error occurred',
        'error': error.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>?> getServiceProviderByIdFixed(
      String providerId) async {
    try {
      // Try several possible endpoints
      final List<String> possibleUrls = [
        '${baseUrl}/api/service-providers/${providerId}',
        '${baseUrl}/api/service-providers/${providerId}/',
        '${baseUrl}/api/service-provider/${providerId}',
        '${baseUrl}/service-providers/${providerId}',
      ];

      for (final url in possibleUrls) {
        print('Trying URL: $url');

      

        try {
          final response = await _makeRequest(
        'GET',
        Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
      );

          print('Response for $url: ${response.statusCode}');

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = json.decode(
                response.body);
            print('Success with URL: $url');

            if (responseData['status'] == 200 &&
                responseData.containsKey('data')) {
              return responseData['data'];
            }
          }
        } catch (e) {
          print('Error with $url: $e');
        }
      }

      // If we reach here, none of the URLs worked
      throw Exception('No valid endpoint found for service provider details');
    } catch (e) {
      debugPrint('Exception in getServiceProviderByIdFixed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getServiceProviderById(
  String providerId) async {
  try {
    // Get auth token from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString('auth_token');
    if (authToken == null) {
      debugPrint('No auth token found');
      return null;
    }
    
       

    final url = '${baseUrl}/api/service-providers/$providerId';
    print('ApiService: Making request to: $url');
    
    final response = await _makeRequest(
        'GET',
       Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      );
    
    print('ApiService: Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final dynamic responseData = json.decode(response.body);
      if (responseData['status'] == 200 && responseData.containsKey('data')) {
        // Convert to Map<String, dynamic> using Map.from()
        return Map<String, dynamic>.from(responseData['data']);
      } else {
        debugPrint('API Error: ${responseData['message']}');
        return null;
      }
    } else {
      debugPrint('HTTP Error: ${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    debugPrint('Exception in getServiceProviderById: $e');
    return null;
  }
}

static Future<List<NotificationModel>> fetchNotifications() async {
    try {
      // Get the authentication token
      final token = await AuthManager.getToken();



      // Make the API call
      final response = await _makeRequest(
        'GET',
        Uri.parse('${ApiConstants.baseUrl}/api/users/notifications'),
      headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Check the response status
      if (response.statusCode == 200) {
        // Parse the JSON response
        final Map<String, dynamic> responseBody = json.decode(response.body);

        // Check if data exists and is a list
        if (responseBody['data'] is List) {
          // Convert the list of notifications to NotificationModel objects
          List<NotificationModel> notifications = (responseBody['data'] as List)
              .map((json) => NotificationModel.fromJson(json))
              .toList();

          return notifications;
        } else {
          throw Exception('No notifications found');
        }
      } else {
        // Handle error responses
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      // Catch and rethrow any errors
      throw Exception('Error fetching notifications: $e');
    }
  }

  static Future<Map<String, dynamic>> checkEmailOrPhoneExists({
    String? email,
    String? phone,
  }) async {
    try {
      // Validate that at least one parameter is provided
      if ((email == null || email.trim().isEmpty) && 
          (phone == null || phone.trim().isEmpty)) {
        throw Exception('Either email or phone must be provided');
      }

      // Prepare request body
      final Map<String, dynamic> requestBody = {};
      if (email != null && email.trim().isNotEmpty) {
        requestBody['email'] = email.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        requestBody['phone'] = phone.trim();
      }

      print('Checking existence for: $requestBody');

      final response = await _makeRequest(
          'POST',
        Uri.parse('$baseUrl/api/auth/check-exists'),
                headers: await _getHeaders(),
        body: jsonEncode(requestBody),

        );


      print('Check exists response status: ${response.statusCode}');
      print('Check exists response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Return the existence data
        return {
          'success': true,
          'message': responseData['message'] ?? 'Check complete',
          'data': responseData['data'] ?? {},
        };
      } else {
        throw Exception(responseData['message'] ?? 'Failed to check existence');
      }
    } catch (e) {
      print('Error checking email/phone existence: $e');
      return {
        'success': false,
        'message': 'Error checking existence: ${e.toString()}',
        'data': {
          'userExists': false,
          'companyExists': false,
          'wholesalerExists': false,
          'serviceProviderExists': false,
          'exists': false,
        },
      };
    }
  }

  static Future<bool> updateServiceProviderDescription(
      String description) async {
    try {
      print('ApiService: Updating service provider description');

      // Get the auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        print('ApiService: Not authenticated - throwing error');
        throw Exception('Not authenticated');
      }

      // First get current provider data to ensure we have all necessary fields
      final providerData = await getServiceProviderDetails();

      // Prepare request data with current values plus new description
      final Map<String, dynamic> requestData = {
        'fullName': providerData['fullName'] ?? '',
        'description': description,
      };


      // Make API request to update profile
      final url = '${baseUrl}/api/service-provider/update';
      print('ApiService: Making request to: $url');

      final response = await _makeRequest(
          'PUT',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),

        );

      print('ApiService: Response status: ${response.statusCode}');

      // Check response status
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('ApiService: Description updated successfully');

        // Update cached data
        try {
          final cachedData = prefs.getString('service_provider_data');
          if (cachedData != null) {
            final Map<String, dynamic> data = json.decode(cachedData);
            data['description'] = description;
            prefs.setString('service_provider_data', json.encode(data));
          }
        } catch (e) {
          print('ApiService: Error updating cached data: $e');
        }

        return true;
      } else {
        print(
            'ApiService: Failed to update description: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('ApiService: Error in updateServiceProviderDescription: $e');
      return false;
    }
  }

  // Apple Sign-In request
  // static Future<Map<String, dynamic>> appleLogin(String idToken) async {
  //   try {
  //     final response = await _makeRequest(
  //       'POST',
  //       Uri.parse('${baseUrl}/api/auth/apple-login'),
  //       headers: await _getHeaders(),
  //       body: jsonEncode({'idToken': idToken}),
  //     );
  //     final responseData = jsonDecode(response.body);
  //     if (response.statusCode == 200) {
  //       // Save token if present
  //       if (responseData['data'] != null && responseData['data']['token'] != null) {
  //         final token = responseData['data']['token'];
  //         await saveToken(token);
  //         await AuthManager.saveAuthData(token);
  //       }
  //       return responseData;
  //     } else {
  //       final errorMsg = responseData['message'] ?? 'Apple login failed';
  //       throw Exception(errorMsg);
  //     }
  //   } catch (e) {
  //     print('Apple login error: $e');
  //     throw Exception(e.toString().contains('Exception:')
  //         ? e.toString().split('Exception: ')[1]
  //         : 'Connection error. Please check your network.');
  //   }
  // }
}

