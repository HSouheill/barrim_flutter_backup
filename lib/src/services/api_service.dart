import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/notification_model.dart';
import '../models/review.dart';
import '../utils/api_constants.dart';
import '../utils/auth_manager.dart';
import '../utils/centralized_token_manager.dart';

class ApiService {
  static const String baseUrl = 'https://barrim.online';
  
  // Secure storage for tokens
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // Method to get the appropriate base URL
  static String getBaseUrl() {
    // You can add logic here to switch between URLs if needed
    return baseUrl;
  }

  // Headers for API requests
  static Future<Map<String, String>> _getHeaders() async {
    return await CentralizedTokenManager.getAuthHeaders();
  }

  // Headers for multipart requests (file uploads)
  static Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await CentralizedTokenManager.getToken();

    return {
      'Authorization': token != null ? 'Bearer $token' : '',
      'User-Agent': 'BarrimApp/1.0.12',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
      // Note: Don't set Content-Type for multipart requests
      // The multipart request will set its own content type with boundary
    };
  }

  // Get stored token
  static Future<String?> _getToken() async {
    return await CentralizedTokenManager.getToken();
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // Store token
  static Future<void> saveToken(String token) async {
    await CentralizedTokenManager.saveToken(token);
  }

  // Clear token (for logout)
  static Future<void> clearToken() async {
    await CentralizedTokenManager.clearToken();
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
      // Increase timeout for real devices, especially for signup requests
      final timeoutDuration = uri.path.contains('/signup') 
          ? const Duration(seconds: 60)  // Longer timeout for signup
          : const Duration(seconds: 30); // Standard timeout for other requests
      
      switch (method.toUpperCase()) {
        case 'GET':
          return await client.get(uri, headers: headers).timeout(
            timeoutDuration,
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection.');
            },
          );
        case 'POST':
          return await client.post(uri, headers: headers, body: body).timeout(
            timeoutDuration,
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection.');
            },
          );
        case 'PUT':
          return await client.put(uri, headers: headers, body: body).timeout(
            timeoutDuration,
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection.');
            },
          );
        case 'DELETE':
          return await client.delete(uri, headers: headers, body: body).timeout(
            timeoutDuration,
            onTimeout: () {
              throw Exception('Request timeout. Please check your internet connection.');
            },
          );
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } catch (e) {
      // Enhanced error handling for real devices
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('No address associated with hostname')) {
        throw Exception('Cannot connect to server. Please check:\n1. Your internet connection\n2. Try again in a few moments');
      } else if (e.toString().contains('SSL') || e.toString().contains('certificate')) {
        throw Exception('Connection security error. Please try again.');
      } else if (e.toString().contains('Connection refused') || e.toString().contains('Connection reset')) {
        throw Exception('Server connection error. Please try again.');
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
      String password, {bool rememberMe = false}) async {
    try {
      // Input validation
      if (emailOrPhone.trim().isEmpty) {
        throw Exception('Email or phone number is required');
      }
      if (password.trim().isEmpty) {
        throw Exception('Password is required');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      
      // Sanitize inputs
      final sanitizedEmailOrPhone = emailOrPhone.trim();
      final sanitizedPassword = password.trim();
      
      // Determine if the input is an email or phone number
      final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(sanitizedEmailOrPhone);
      // Updated phone regex to match login page
      final isPhone = RegExp(r'^(\+?[0-9]{8,15}|[0-9]{8,15})$').hasMatch(sanitizedEmailOrPhone.replaceAll(RegExp(r'[\s-]'), ''));

      if (!isEmail && !isPhone) {
        throw Exception('Invalid email or phone number format. For phone numbers, use format: +96170123456 or 70123456');
      }

      // Format phone number if it's a phone login
      String formattedInput = sanitizedEmailOrPhone;
      if (isPhone) {
        // Remove any spaces or special characters
        formattedInput = sanitizedEmailOrPhone.replaceAll(RegExp(r'[\s-]'), '');
        // Add country code if not present and number starts with 0
        if (formattedInput.startsWith('0')) {
          formattedInput = '+961${formattedInput.substring(1)}';
        }
        // Add country code if not present and number doesn't start with +
        else if (!formattedInput.startsWith('+')) {
          formattedInput = '+961$formattedInput';
        }
      }

      // Prepare request body based on input type
      Map<String, dynamic> requestBody = {
        'password': sanitizedPassword,
        'rememberMe': rememberMe, // Add remember me field
      };

      // Add email or phone field based on input type
      if (isEmail) {
        requestBody['email'] = formattedInput;
      } else {
        requestBody['phone'] = formattedInput;
      }

      // Use custom client for handling self-signed certificates
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/login'),
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );


      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Successfully logged in
        if (responseData['data'] != null &&
            responseData['data']['token'] != null) {
          final token = responseData['data']['token'];
          await saveToken(token);
          await AuthManager.saveAuthData(token);

          // Token saved successfully

          // Store user type for future reference
          String userType = responseData['data']['user']['userType'] ?? 'user';
          await _secureStorage.write(key: 'user_type', value: userType);

          // Based on user type, fetch and store appropriate data
          try {
            switch (userType) {
              case 'company':
                final companyData = await getCompanyData(token);
                await _secureStorage.write(key: 'company_data', value: jsonEncode(companyData));
                break;
              case 'wholesaler':
                final userData = await getUserProfile(token);
                await _secureStorage.write(key: 'wholesaler_info',
                    value: jsonEncode(userData['wholesalerInfo'] ?? {}));
                break;
              case 'serviceProvider':
                final userData = await getUserProfile(token);
                await _secureStorage.write(key: 'service_provider_info',
                    value: jsonEncode(userData['serviceProviderInfo'] ?? {}));
                break;
              case 'user':
              // Store basic user profile
                final userData = await getUserProfile(token);
                await _secureStorage.write(key: 'user_data', value: jsonEncode(userData));
                break;
            }
          } catch (e) {
            // Error fetching specific user data on login
          }
        }
        return responseData;
      } else {
        final errorMsg = responseData['message'] ?? 'Login failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception(e.toString().contains('Exception:')
          ? e.toString().split('Exception: ')[1]
          : 'Connection error. Please check your network.');
    }
  }


  // Sign up request for regular user
  static Future<Map<String, dynamic>> signupUser(
      Map<String, dynamic> userData) async {
    try {
      // Prepare location data - use the same structure as wholesaler signup
      Map<String, dynamic> locationData = {};
      if (userData['location'] != null) {
        final location = userData['location'] as Map<String, dynamic>;
        
        // Use coordinates structure like wholesaler signup
        locationData['coordinates'] = {
          'lat': location['lat'],
          'lng': location['lng'],
        };
        
        // Extract address components and flatten them
        if (location['address'] != null) {
          final address = location['address'] as Map<String, dynamic>;
          locationData['country'] = address['country'] ?? '';
          locationData['city'] = address['city'] ?? '';
          locationData['district'] = address['district'] ?? '';
          locationData['governorate'] = address['governorate'] ?? '';
          locationData['street'] = address['street'] ?? '';
          locationData['postalCode'] = address['postalCode'] ?? '';
          locationData['fullAddress'] = address['fullAddress'] ?? '';
        }
      }

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
        'location': locationData,
      };
      
      // Debug print to verify what's being sent to backend
      print('=== API SERVICE SIGNUP DEBUG ===');
      print('Location data being sent: $locationData');
      print('Full request data: $requestData');
      print('================================');
      
      
      // await ApiService.signupBusiness(requestData);

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/signup'),
        headers: await _getHeaders(),
        body: jsonEncode(requestData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Successfully signed up (201 for creation, 200 for OTP sent)
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
      // Enhanced error handling for real devices
      if (e.toString().contains('timeout') || e.toString().contains('timed out')) {
        throw Exception('Connection timeout. Please check your internet connection and try again.');
      } else if (e.toString().contains('Failed host lookup') || e.toString().contains('No address associated')) {
        throw Exception('Cannot connect to server. Please check your internet connection.');
      } else if (e.toString().contains('SSL') || e.toString().contains('certificate')) {
        throw Exception('Connection security error. Please try again.');
      } else if (e.toString().contains('Connection refused') || e.toString().contains('Connection reset')) {
        throw Exception('Server connection error. Please try again.');
      } else if (kDebugMode) {
        throw Exception('Connection error: $e');
      } else {
        throw Exception('Connection error. Please try again.');
      }
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
      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? 'Failed to save location');
      }
    } catch (e) {
      if (kDebugMode) {
        throw Exception('Connection error: $e');
      } else {
        throw Exception('Connection error. Please try again.');
      }
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


      // Send the request using custom client
      final streamedResponse = await _makeMultipartRequest(
        'POST',
        uri,
        fields: fields,
        files: files,
      );
      
      var response = await http.Response.fromStream(streamedResponse);

      // Parse response
      Map<String, dynamic> parsedResponse;
      try {
        parsedResponse = json.decode(response.body);
      } catch (e) {
        parsedResponse = {
          'message': 'Invalid server response'
        };
      }

      return {
        'status': response.statusCode,
        'message': parsedResponse['message'] ?? 'Unknown response',
        'data': parsedResponse['data'],
      };
    } catch (e) {
      return {
        'status': 500,
        'message': 'Failed to sign up',
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
      
      // Prepare headers for multipart request (without Content-Type)
      Map<String, String> headers = await _getMultipartHeaders();
      
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
      if (kDebugMode) {
        throw Exception('Connection error: $e');
      } else {
        throw Exception('Connection error. Please try again.');
      }
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
      if (kDebugMode) {
        throw Exception('Connection error: $e');
      } else {
        throw Exception('Connection error. Please try again.');
      }
    }
  }

  // Store token
  static Future<void> storeToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
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
      if (kDebugMode) {
        throw Exception('Connection error: $e');
      } else {
        throw Exception('Connection error. Please try again.');
      }
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
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['data'] ?? []; // Ensure we always return a list
      } else {
        throw Exception('Failed to load companies: \\${response.statusCode}');
      }
    } catch (e) {
      return []; // Return empty list on error
    }
  }

  // Validate token with server
  static Future<Map<String, dynamic>> validateToken(String token) async {
    try {
      // Basic token validation
      if (token.trim().isEmpty) {
        return {'valid': false, 'message': 'Token is empty'};
      }
      
      // Check token format (basic JWT structure)
      if (!token.contains('.')) {
        return {'valid': false, 'message': 'Invalid token format'};
      }
      
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/auth/validate'),
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
      return {'valid': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String userId,
    required String otp,
  }) async {
    try {
      // Input validation
      if (userId.trim().isEmpty) {
        throw Exception('User ID is required');
      }
      if (otp.trim().isEmpty) {
        throw Exception('OTP is required');
      }
      if (!RegExp(r'^[0-9]{4,8}$').hasMatch(otp.trim())) {
        throw Exception('OTP must be 4-8 digits');
      }
      
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/verify-otp'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userId.trim(),
          'otp': otp.trim(),
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
        return userData;
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      throw Exception('Failed to load profile: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getCompanyData(String token) async {
    try {
      final url = '${baseUrl}/api/companies/data';
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        return {
          'companyInfo': responseData['data']['companyInfo'] ?? {},
          'location': responseData['data']['location'] ?? {},
        };
      } else {
        throw Exception('Failed to load company data: ${response.statusCode}');
      }
    } catch (e) {
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

      // Add headers for multipart request (without Content-Type)
      Map<String, String> headers = await _getMultipartHeaders();

      // Remove file paths from the JSON data to avoid confusion
      var dataCopy = Map<String, dynamic>.from(branchData);
      dataCopy.remove('images'); // Don't send file paths in JSON

      // Extract location components
      String locationStr = (dataCopy['location'] ?? '').toString();
      List<String> addressParts = locationStr.split(', ');

      // Derive address fields
      final derivedStreet = addressParts.isNotEmpty ? addressParts[0] : '';
      final derivedCity = addressParts.length > 1 ? addressParts[1] : '';
      final derivedCountry = addressParts.length > 2 ? addressParts.last : '';

      // Normalize latitude/longitude to double and expose as lat/lng top-level
      double latValue = 0.0;
      double lngValue = 0.0;
      if (dataCopy['latitude'] != null) {
        latValue = double.tryParse(dataCopy['latitude'].toString()) ?? 0.0;
      }
      if (dataCopy['longitude'] != null) {
        lngValue = double.tryParse(dataCopy['longitude'].toString()) ?? 0.0;
      }
      dataCopy['lat'] = latValue;
      dataCopy['lng'] = lngValue;

      // Backward-compatible embedded location (optional for backend)
      Map<String, dynamic> addressData = {
        'country': (dataCopy['country'] ?? derivedCountry).toString(),
        'district': (dataCopy['district'] ?? '').toString(),
        'city': (dataCopy['city'] ?? derivedCity).toString(),
        'street': (dataCopy['street'] ?? derivedStreet).toString(),
        'postalCode': (dataCopy['postalCode'] ?? '').toString(),
        'lat': latValue,
        'lng': lngValue,
      };
      dataCopy['location'] = addressData;

      // Critically: backend expects top-level address fields
      dataCopy['country'] = addressData['country'];
      dataCopy['governorate'] = (dataCopy['governorate'] ?? '').toString();
      dataCopy['district'] = addressData['district'];
      dataCopy['city'] = addressData['city'];

      // Remove the original latitude/longitude fields to avoid confusion
      dataCopy.remove('latitude');
      dataCopy.remove('longitude');

      // Prepare fields
      Map<String, String> fields = {};
      fields['data'] = jsonEncode(dataCopy);

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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['data']; // Return the created branch data
      } else {
        final responseData = jsonDecode(response.body);
        throw Exception(
            responseData['message'] ?? 'Failed to upload branch data');
      }
    } catch (e) {
      if (kDebugMode) {
        throw Exception('Failed to upload branch data: $e');
      } else {
        throw Exception('Failed to upload data. Please try again.');
      }
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

        return branches;
      } else {
        throw Exception('Failed to load branches: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        throw Exception('Network error: $e');
      } else {
        throw Exception('Network error. Please try again.');
      }
    }
  }

  // Delete a branch
  static Future<bool> deleteBranch(String token, String branchId) async {
    try {

      final response = await _makeRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/companies/branches/$branchId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Failed to delete branch');
      }
    } catch (e) {
      if (kDebugMode) {
        throw Exception('Network error: $e');
      } else {
        throw Exception('Network error. Please try again.');
      }
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

      // Add headers for multipart request (without Content-Type)
      Map<String, String> headers = await _getMultipartHeaders();

      // Format data to match the backend expectations
      var dataCopy = Map<String, dynamic>.from(branchData);

      // Convert latitude/longitude to lat/lng
      if (dataCopy.containsKey('latitude')) {
        dataCopy['lat'] = double.tryParse(dataCopy['latitude'].toString()) ?? 0.0;
        dataCopy.remove('latitude');
      }
      if (dataCopy.containsKey('longitude')) {
        dataCopy['lng'] = double.tryParse(dataCopy['longitude'].toString()) ?? 0.0;
        dataCopy.remove('longitude');
      }

      // Add structured location data and top-level address fields when location is a String
      if (dataCopy.containsKey('location') && dataCopy['location'] is String) {
        String locationStr = dataCopy['location'];
        List<String> addressParts = locationStr.split(', ');

        final derivedStreet = addressParts.isNotEmpty ? addressParts[0] : '';
        final derivedCity = addressParts.length > 1 ? addressParts[1] : '';
        final derivedCountry = addressParts.length > 2 ? addressParts.last : '';

        Map<String, dynamic> address = {
          'street': derivedStreet,
          'city': derivedCity,
          'district': '',
          'country': derivedCountry,
          'postalCode': '',
          'lat': dataCopy['lat'] ?? 0.0,
          'lng': dataCopy['lng'] ?? 0.0,
        };

        dataCopy['location'] = address;

        // Ensure backend-visible top-level fields
        dataCopy['country'] = (dataCopy['country'] ?? derivedCountry).toString();
        dataCopy['governorate'] = (dataCopy['governorate'] ?? '').toString();
        dataCopy['district'] = (dataCopy['district'] ?? '').toString();
        dataCopy['city'] = (dataCopy['city'] ?? derivedCity).toString();
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

      if (response.statusCode == 200) {
        return;
      } else {
        throw Exception('Failed to update branch: ${response.statusCode}');
      }
    } catch (e) {
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
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to update');
      }
    } catch (e) {
      rethrow;
    }
  }

  //api_Service.dart
  static Future<List<Map<String, dynamic>>> getAllBranches() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');

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
        final responseData = json.decode(response.body);
        if (responseData['status'] == 200) {
          // Return empty list if data is null, otherwise return the data
          if (responseData['data'] == null) {
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
          // Failed to precache image
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

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/users/profile'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto(File imageFile) async {
    try {
      // Compress the image before upload to avoid "413 Request Entity Too Large" error
      File compressedImage = await _compressImage(imageFile);
      
      // Check if the compressed image is still too large
      final compressedSize = await compressedImage.length();
      if (compressedSize > 2 * 1024 * 1024) { // 2MB limit
        throw Exception('Image is still too large after compression (${(compressedSize / 1024 / 1024).toStringAsFixed(1)}MB). Please try a smaller image.');
      }
      
      final uri = Uri.parse('$baseUrl/api/upload-user-profile-photo');
      
      // Add headers for multipart request (without Content-Type)
      Map<String, String> headers = await _getMultipartHeaders();

      // Prepare files
      List<http.MultipartFile> files = [];
      
      // Add compressed image file
      var extension = compressedImage.path
          .split('.')
          .last
          .toLowerCase();
      var contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

      files.add(await http.MultipartFile.fromPath(
        'photo',
        compressedImage.path,
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
      
      // Check for specific error codes and provide helpful messages
      if (response.statusCode == 413) {
        throw Exception('Profile photo is too large. Please try a smaller image or contact support if the issue persists.');
      }
      
      // Check if response is HTML (error page) instead of JSON
      if (response.body.trim().startsWith('<html') || response.body.trim().startsWith('<!DOCTYPE')) {
        throw Exception('Server returned HTML error page instead of JSON response. This usually indicates an authentication or server error.');
      }
      
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

  // Helper method to compress images
  static Future<File> _compressImage(File imageFile) async {
    try {
      // Read the image file
      final bytes = await imageFile.readAsBytes();
      final originalSize = bytes.length;
      
      // If image is already small enough (under 500KB), return as is
      if (originalSize < 500 * 1024) {
        return imageFile;
      }
      
      // Decode the image
      final image = img.decodeImage(bytes);
      if (image == null) {
        return imageFile;
      }
      
      // Calculate new dimensions - target max 800x800 pixels
      int newWidth = image.width;
      int newHeight = image.height;
      
      if (image.width > 800 || image.height > 800) {
        if (image.width > image.height) {
          newWidth = 800;
          newHeight = (image.height * 800 / image.width).round();
        } else {
          newHeight = 800;
          newWidth = (image.width * 800 / image.height).round();
        }
      }
      
      // Resize the image
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
      
      // Encode as JPEG with quality 85 (good balance between size and quality)
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Create a temporary file for the compressed image
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/compressed_profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      await tempFile.writeAsBytes(compressedBytes);
      
      return tempFile;
      
    } catch (e) {
      // If compression fails, return the original image
      return imageFile;
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
      // Check authentication
      if (!await isAuthenticated()) {
        throw Exception('Authentication required');
      }

      // Make API request to the user data endpoint
      final url = '${baseUrl}/api/users/get-user-data';

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      // Check response status
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['status'] == 200) {
          // Store the data locally for offline access
          final userData = responseData['data'] as Map<String, dynamic>;
          await _secureStorage.write(key: 'user_data', value: jsonEncode(userData));

          return userData;
        } else {
          throw Exception(responseData['message'] ?? 'Failed to get user data');
        }
      } else if (response.statusCode == 404) {
        throw Exception('User not found or not a regular user');
      } else {
        throw Exception('Failed to get user data: ${response.statusCode}');
      }
    } catch (e) {
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

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/users/personal-info'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update local storage with new data
        final currentUserData = await getUserData();

        // Merge updated fields
        final updatedData = {
          ...currentUserData,
          'phone': phone,
          'dateOfBirth': dateOfBirth,
          'gender': gender,
          if (location != null) 'location': location,
        };

        await _secureStorage.write(key: 'user_data', value: jsonEncode(updatedData));

        return responseData;
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to update personal information');
      }
    } catch (e) {
      throw Exception('Failed to update personal information: ${e.toString()}');
    }
  }

  // Referral System Functions

  /// Get the user's referral data including code, points, and referral count
  static Future<Map<String, dynamic>> getReferralData() async {
    try {
      // Check authentication
      if (!await isAuthenticated()) {
        throw Exception('Authentication required');
      }

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
      // Check authentication
      if (!await isAuthenticated()) {
        throw Exception('Authentication required');
      }

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
      // Get the auth token
      final token = await _secureStorage.read(key: 'auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Make API request to the service provider details endpoint
      final url = '${baseUrl}/api/service-provider/details'; // Updated to include /api/

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check response status
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['status'] == 200) {
          // Store the data locally for offline access
          final providerData = responseData['data'] as Map<String, dynamic>;
          
          // Extract the actual service provider data from the nested structure
          Map<String, dynamic> serviceProviderData;
          if (providerData.containsKey('serviceProvider')) {
            // The API returns {category: "...", serviceProvider: {...}}
            serviceProviderData = Map<String, dynamic>.from(providerData['serviceProvider'] as Map<String, dynamic>);
            // Add the category to the service provider data
            if (providerData.containsKey('category')) {
              serviceProviderData['category'] = providerData['category'];
            }
          } else {
            // Direct service provider data
            serviceProviderData = providerData;
          }
          
          await _secureStorage.write(key: 'service_provider_data', value: jsonEncode(serviceProviderData));

          return serviceProviderData;
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to get service provider data');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Service provider not found');
      } else if (response.statusCode == 403) {
        throw Exception(
            'Access denied. Only service providers can access this data');
      } else {
        throw Exception(
            'Failed to get service provider data: ${response.statusCode}');
      }
    } catch (e) {
      // Try to return cached data if available
      try {
        final cachedData = await _secureStorage.read(key: 'service_provider_data');
        if (cachedData != null) {
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
      await _secureStorage.delete(key: 'service_provider_data');
    } catch (e) {
      // Error clearing cache
    }
  }


  // Fetch service provider logo using user ID
  static Future<String?> getServiceProviderLogo(String userId) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/service-providers/$userId/logo'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          return '$baseUrl${responseData['data']['logoPath']}';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  //api_service.dart
  static Future<List<dynamic>> getAllServiceProviders() async {
    try {
      final url = '${baseUrl}/api/service-providers/all';
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          var data = responseData['data'];
          if (data is Map<String, dynamic> &&
              data.containsKey('serviceProviders')) {
            return data['serviceProviders'] as List<dynamic>;
          } else if (data is List<dynamic>) {
            return data;
          } else {
            return [data];
          }
        } else {
          throw Exception(responseData['message'] ??
              'Failed to get service providers data');
        }
      } else {
        throw Exception(
            'Failed to get service providers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting service providers: $e');
    }
  }

  // Test connection method
  static Future<bool> testConnection() async {
    try {
      // Try to connect to the base URL
      final response = await _makeRequest(
        'GET',
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200 || response.statusCode == 404; // 404 is OK for base URL
    } catch (e) {
      return false;
    }
  }



  // Updated method to get reviews for a service provider
  static Future<List<Review>> getReviewsForProvider(String providerId) async {
    try {
      // Try without authentication first (public endpoint)
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/service-providers/$providerId/reviews'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 200 && responseData['data'] != null) {
          final List<dynamic> reviewsJson = responseData['data'];
          
          final reviews = reviewsJson.map((json) {
            try {
              return Review.fromJson(json);
            } catch (e) {
              return null;
            }
          }).where((review) => review != null).cast<Review>().toList();
          
          return reviews;
        }
      } else if (response.statusCode == 401) {
        // If unauthorized, try with authentication
        final authResponse = await _makeRequest(
          'GET',
          Uri.parse('$baseUrl/api/service-providers/$providerId/reviews'),
          headers: await _getHeaders(),
        );
        
        if (authResponse.statusCode == 200) {
          final responseData = jsonDecode(authResponse.body);
          if (responseData['status'] == 200 && responseData['data'] != null) {
            final List<dynamic> reviewsJson = responseData['data'];
            return reviewsJson.map((json) => Review.fromJson(json)).toList();
          }
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // Updated method to create a review with multipart form data
  static Future<bool> createReview(Review review) async {
    try {
      // Prepare headers for multipart request (without Content-Type)
      Map<String, String> headers = await _getMultipartHeaders();
      
      // Prepare fields
      Map<String, String> fields = {
        'serviceProviderId': review.serviceProviderId,
        'rating': review.rating.toString(),
        'comment': review.comment,
      };

      // Add mediaType if present
      if (review.mediaType != null && review.mediaType!.isNotEmpty) {
        fields['mediaType'] = review.mediaType!;
      }

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add media file if present
      if (review.mediaFile != null) {
        final fileStream = http.ByteStream(review.mediaFile!.openRead());
        final fileLength = await review.mediaFile!.length();
        
        final multipartFile = http.MultipartFile(
          'mediaFile',
          fileStream,
          fileLength,
          filename: review.mediaFile!.path.split('/').last,
        );
        
        files.add(multipartFile);
      }

      // Send the request using multipart
      final streamedResponse = await _makeMultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/reviews'),
        headers: headers,
        fields: fields,
        files: files,
      );
      
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // Create a new review with media support
  static Future<Map<String, dynamic>> createReviewWithMedia({
    required String serviceProviderId,
    required int rating,
    required String comment,
    String? mediaType,
    File? mediaFile,
  }) async {
    try {
      // Prepare headers for multipart request (without Content-Type)
      Map<String, String> headers = await _getMultipartHeaders();
      
      // Prepare fields
      Map<String, String> fields = {
        'serviceProviderId': serviceProviderId,
        'rating': rating.toString(),
        'comment': comment,
      };

      // Add mediaType if present
      if (mediaType != null && mediaType.isNotEmpty) {
        fields['mediaType'] = mediaType;
      }

      // Prepare files
      List<http.MultipartFile> files = [];

      // Add media file if present
      if (mediaFile != null) {
        final fileStream = http.ByteStream(mediaFile.openRead());
        final fileLength = await mediaFile.length();
        
        final multipartFile = http.MultipartFile(
          'mediaFile',
          fileStream,
          fileLength,
          filename: mediaFile.path.split('/').last,
        );
        
        files.add(multipartFile);
      }

      // Send the request using multipart
      final streamedResponse = await _makeMultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/reviews'),
        headers: headers,
        fields: fields,
        files: files,
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'status': response.statusCode,
          'message': 'Review created successfully',
          'data': responseData['data'],
        };
      } else {
        return {
          'status': response.statusCode,
          'message': responseData['message'] ?? 'Failed to create review',
          'data': null,
        };
      }
    } catch (e) {
      return {
        'status': 500,
        'message': 'Error creating review: $e',
        'data': null,
      };
    }
  }

  // Post a reply to a review
  static Future<Map<String, dynamic>> postReviewReply({
    required String reviewId,
    required String replyText,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/reviews/$reviewId/reply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await getAuthToken()}',
        },
        body: json.encode({
          'replyText': replyText,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'status': response.statusCode,
          'message': 'Reply posted successfully',
          'data': responseData['data'],
        };
      } else {
        return {
          'status': response.statusCode,
          'message': responseData['message'] ?? 'Failed to post reply',
          'data': null,
        };
      }
    } catch (e) {
      return {
        'status': 500,
        'message': 'Error posting reply: $e',
        'data': null,
      };
    }
  }

  // Get reply for a review
  static Future<Map<String, dynamic>> getReviewReply(String reviewId) async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/reviews/$reviewId/reply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await getAuthToken()}',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'status': response.statusCode,
          'message': 'Reply retrieved successfully',
          'data': responseData['data'],
        };
      } else {
        return {
          'status': response.statusCode,
          'message': responseData['message'] ?? 'Failed to get reply',
          'data': null,
        };
      }
    } catch (e) {
      return {
        'status': 500,
        'message': 'Error getting reply: $e',
        'data': null,
      };
    }
  }

  // Helper method to get auth token
  static Future<String> getAuthToken() async {
    // Use centralized token manager for consistency
    return await CentralizedTokenManager.getToken() ?? '';
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

      final responseData = json.decode(response.body);

      // Check if request was successful
      if (response.statusCode == 200) {
        return responseData['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
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
      return false;
    }
  }

  Future<bool> removeServiceProviderFromFavorites(
      String serviceProviderId) async {
    try {
      final headers = await _getAuthToken();

      // Create the request body
      final body = jsonEncode({
        'serviceProviderId': serviceProviderId,
      });

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

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to remove from favorites: ${response.body}');
      }
    } catch (e) {
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
      return false;
    }
  }

// Toggle favorite status (add or remove)
  Future<bool> toggleFavoriteStatus(String? serviceProviderId,
      bool currentlyFavorited) async {
    if (serviceProviderId == null || serviceProviderId.isEmpty) {
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
        return [];
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/users/favorite-providers'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Return the full response - let the calling function handle the structure
        return data;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, String>> _getAuthToken() async {
    // Use centralized token manager for consistent headers
    return await CentralizedTokenManager.getAuthHeaders();
  }

  //  api_service.dart

  static Future<Map<String, dynamic>> getBranchComments(String branchId,
      {int page = 1, int limit = 10}) async {
    try {
      final Uri uri = Uri.parse(
          '$baseUrl/api/branches/$branchId/comments?page=$page&limit=$limit');


      final response = await _makeRequest(
        'GET',
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );


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

        // Return the response data with consistent status format
        return {
          'status': 'success',
          'message': responseData['message'] ?? 'Comments loaded successfully',
          'data': responseData['data'],
        };
      } else {
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


      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception(
            'Failed to post comment (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error posting comment: $e');
    }
  }

  // Get branch rating
  static Future<Map<String, dynamic>> getBranchRating(String branchId) async {
    try {
      final Uri uri = Uri.parse('$baseUrl/api/branches/$branchId/rating');

      final response = await _makeRequest(
        'GET',
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return {
          'status': 'success',
          'message': responseData['message'] ?? 'Rating loaded successfully',
          'data': responseData['data'],
        };
      } else {
        return {
          'status': 'error',
          'message': 'Failed to load rating (Status: ${response.statusCode})',
          'data': null,
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error loading rating: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> replyToBranchComment(String commentId,
      String reply, {String? token}) async {
    try {
      // Use provided token or fallback to stored token
      final authToken = token ?? await _getToken();
      print('Reply API - Token found: ${authToken != null ? "Yes" : "No"}');
      print('Reply API - Token length: ${authToken?.length ?? 0}');
      if (authToken == null) {
        throw Exception('Authentication required');
      }

      final Uri uri = Uri.parse(
          '$baseUrl/api/companies/comments/$commentId/reply');

      final response = await _makeRequest(
        'POST',
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'reply': reply,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 
            'Failed to post reply (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('timed out')) {
        throw Exception('Connection timeout. Please check your internet connection and try again.');
      } else if (e.toString().contains('Failed host lookup') || e.toString().contains('No address associated')) {
        throw Exception('Cannot connect to server. Please check your internet connection.');
      } else if (e.toString().contains('Connection refused') || e.toString().contains('Connection reset')) {
        throw Exception('Server is not responding. Please try again later.');
      } else {
        throw Exception('Error posting reply: $e');
      }
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


      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['status'] == 200;
      }
      return false;
    } catch (e) {
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
      throw Exception('Failed to delete account: $e');
    }
  }

  static Future<Map<String, dynamic>> smsverifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      // Normalize phone number to E.164 format
      String normalizedPhone = phone.trim();

      // Remove all non-digit characters except +
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

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/sms-verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': normalizedPhone,
          'otp': otp,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Check if the response has the expected structure
        if (responseData['status'] == 200 && responseData['data'] != null) {
          final data = responseData['data'];
          
          // Save token if present
          if (data['token'] != null) {
            await _secureStorage.write(key: 'auth_token', value: data['token']);
          }
          
          // Save refresh token if present
          if (data['refreshToken'] != null) {
            await _secureStorage.write(key: 'refresh_token', value: data['refreshToken']);
          }

          // Store user data based on user type
          if (data['user'] != null) {
            final user = data['user'];
            final userType = user['userType'] ?? 'user';
            
            // Store user type
            await _secureStorage.write(key: 'user_type', value: userType);
            
            // Store user data based on type
            switch (userType) {
              case 'company':
                if (data['company'] != null) {
                  await _secureStorage.write(key: 'company_data', value: jsonEncode(data['company']));
                }
                break;
              case 'wholesaler':
                if (data['wholesaler'] != null) {
                  await _secureStorage.write(key: 'wholesaler_data', value: jsonEncode(data['wholesaler']));
                }
                break;
              case 'serviceProvider':
                if (data['serviceProvider'] != null) {
                  await _secureStorage.write(key: 'service_provider_data', value: jsonEncode(data['serviceProvider']));
                }
                break;
              case 'user':
                await _secureStorage.write(key: 'user_data', value: jsonEncode(user));
                break;
            }
          }

          return {
            'success': true,
            'message': responseData['message'] ?? 'OTP verified successfully',
            'data': data,
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'OTP verification failed',
            'status': responseData['status'] ?? response.statusCode,
          };
        }
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'OTP verification failed',
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

  static Future<Map<String, dynamic>> resendOtp({
    required String phone,
  }) async {
    try {
      // Normalize phone number to E.164 format
      String normalizedPhone = phone.trim();

      // Remove all non-digit characters except +
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

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': normalizedPhone,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP resent successfully',
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

      

        try {
          final response = await _makeRequest(
        'GET',
        Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
      );

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = json.decode(
                response.body);

            if (responseData['status'] == 200 &&
                responseData.containsKey('data')) {
              return responseData['data'];
            }
          }
        } catch (e) {
          // Error with URL
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
    // Get auth token from secure storage
    final String? authToken = await _secureStorage.read(key: 'auth_token');
    if (authToken == null) {
      debugPrint('No auth token found');
      return null;
    }
    
    debugPrint('Fetching service provider by ID: $providerId');

    final url = '${baseUrl}/api/service-providers/$providerId';
    debugPrint('API URL: $url');
    
    final response = await _makeRequest(
        'GET',
       Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      );
    
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final dynamic responseData = json.decode(response.body);
      debugPrint('Parsed response data: $responseData');
      
      if (responseData['status'] == 200 && responseData.containsKey('data')) {
        // Convert to Map<String, dynamic> using Map.from()
        final enhancedData = Map<String, dynamic>.from(responseData['data']);
        debugPrint('Enhanced service provider data: $enhancedData');
        
        // Log key fields for debugging
        debugPrint('Service Provider ID: ${enhancedData['_id']}');
        debugPrint('Service Provider Name: ${enhancedData['fullName'] ?? enhancedData['businessName']}');
        debugPrint('Service Type: ${enhancedData['serviceType']}');
        debugPrint('Available Hours: ${enhancedData['availableHours']}');
        debugPrint('Available Days: ${enhancedData['availableDays']}');
        debugPrint('Years Experience: ${enhancedData['yearsExperience']}');
        debugPrint('Certificate Images: ${enhancedData['certificateImages']}');
        
        return enhancedData;
      } else {
        debugPrint('API Error: ${responseData['message']}');
        return null;
      }
    } else if (response.statusCode == 404) {
      debugPrint('Service provider not found');
      return null;
    } else if (response.statusCode == 400) {
      debugPrint('Invalid service provider ID format');
      return null;
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


      final response = await _makeRequest(
          'POST',
        Uri.parse('$baseUrl/api/auth/check-exists'),
                headers: await _getHeaders(),
        body: jsonEncode(requestBody),

        );



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
      // Get the auth token
      final token = await _secureStorage.read(key: 'auth_token');

      if (token == null) {
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

      final response = await _makeRequest(
          'PUT',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),

        );

      // Check response status
      if (response.statusCode == 200) {
        // Update cached data
        try {
          final cachedData = await _secureStorage.read(key: 'service_provider_data');
          if (cachedData != null) {
            final Map<String, dynamic> data = json.decode(cachedData);
            data['description'] = description;
            await _secureStorage.write(key: 'service_provider_data', value: json.encode(data));
          }
        } catch (e) {
          // Error updating cached data
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
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

  // Get sponsored entities (companies, wholesalers, service providers)
  static Future<List<Map<String, dynamic>>> getSponsoredEntities() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/sponsored-entities'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> sponsoredData = responseData['data'] ?? [];
        
        // Filter entities that have sponsorship: true
        final List<Map<String, dynamic>> sponsoredEntities = sponsoredData
            .where((entity) => entity['sponsorship'] == true)
            .map((entity) => Map<String, dynamic>.from(entity))
            .toList();

        return sponsoredEntities;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Get sponsored companies
  static Future<List<Map<String, dynamic>>> getSponsoredCompanies() async {
    try {
      final companies = await getCompaniesWithLocations();
      
      // Filter companies that have sponsorship: true
      final sponsoredCompanies = companies.where((company) {
        final companyInfo = company['companyInfo'];
        return companyInfo?['sponsorship'] == true;
      }).toList();

      return sponsoredCompanies.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // Get sponsored wholesalers
  static Future<List<Map<String, dynamic>>> getSponsoredWholesalers() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/wholesalers'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> wholesalersData = responseData['data'] ?? [];
        
        // Filter wholesalers that have sponsorship: true
        final List<Map<String, dynamic>> sponsoredWholesalers = wholesalersData
            .where((wholesaler) => wholesaler['sponsorship'] == true)
            .map((wholesaler) => Map<String, dynamic>.from(wholesaler))
            .toList();

        return sponsoredWholesalers;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Get sponsored service providers
  static Future<List<Map<String, dynamic>>> getSponsoredServiceProviders() async {
    try {
      // This would need to be implemented based on your service provider API structure
      // For now, returning empty list - you'll need to implement this based on your API
      return [];
    } catch (e) {
      return [];
    }
  }

  // Get sponsored branches
  static Future<List<Map<String, dynamic>>> getSponsoredBranches() async {
    try {
      final branches = await getAllBranches();
      
      // Filter branches that have sponsorship: true
      final sponsoredBranches = branches.where((branch) {
        return branch['sponsorship'] == true;
      }).toList();

      // Also check for sponsored branches within wholesalers
      try {
        // Import wholesaler service to get wholesalers with sponsored branches
        // For now, we'll return the branches we found
        // You may need to implement this based on your wholesaler API structure
      } catch (e) {
        // Could not check wholesaler branches
      }

      return sponsoredBranches;
    } catch (e) {
      return [];
    }
  }

  // Get all categories from backend with logo data
  static Future<Map<String, Map<String, dynamic>>> getAllCategoriesWithLogos() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/categories'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> categoriesData = responseData['data'] ?? [];
        
        // Convert the backend response to include logo data
        final Map<String, Map<String, dynamic>> categoriesMap = {};
        
        for (var category in categoriesData) {
          if (category['name'] != null) {
            final String categoryName = category['name'];
            
            // Parse subcategories from the backend response
            List<String> subcategories = [];
            if (category['subcategories'] != null) {
              final subcategoriesData = category['subcategories'] as List<dynamic>;
              subcategories = subcategoriesData.map((sub) => sub.toString()).toList();
            }
            
            // Get logo URL for the category
            String? logoUrl;
            if (category['logo'] != null && category['logo'].toString().isNotEmpty) {
              logoUrl = category['logo'].toString();
              // Convert relative paths to full URLs
              if (!logoUrl.startsWith('http')) {
                logoUrl = logoUrl.startsWith('/') ? '$baseUrl$logoUrl' : '$baseUrl/$logoUrl';
              }
            }
            
            // Get color from backend, with fallback to default
            String color = '#2079C2'; // Default fallback color
            if (category['color'] != null && category['color'].toString().isNotEmpty) {
              color = category['color'].toString();
            }
            
            // Get description if available
            String? description;
            if (category['description'] != null) {
              description = category['description'].toString();
            }
            
            categoriesMap[categoryName] = {
              'subcategories': subcategories,
              'logo': logoUrl,
              'description': description,
              'color': color,
              'id': category['id'],
              'createdAt': category['createdAt'],
              'updatedAt': category['updatedAt'],
            };
            
          }
        }

        
        return categoriesMap;
      } else {
        // Failed to fetch categories
        // Return empty map on error
        return {};
      }
    } catch (e) {
      print('Error fetching categories: $e');
      // Return empty map on error
      return {};
    }
  }

  // Get all categories from backend (legacy method for backward compatibility)
  static Future<Map<String, List<String>>> getAllCategories() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/categories'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> categoriesData = responseData['data'] ?? [];
        
        // Convert the backend response to the expected format
        final Map<String, List<String>> categoriesMap = {};
        
        for (var category in categoriesData) {
          if (category['name'] != null) {
            final String categoryName = category['name'];
            
            // Parse subcategories from the backend response
            List<String> subcategories = [];
            if (category['subcategories'] != null) {
              final subcategoriesData = category['subcategories'] as List<dynamic>;
              subcategories = subcategoriesData.map((sub) => sub.toString()).toList();
            }
            
            categoriesMap[categoryName] = subcategories;
            
          }
        }

        return categoriesMap;
      } else {
        // Return empty map on error
        return {};
      }
    } catch (e) {
      // Return empty map on error
      return {};
    }
  }

  // Get all wholesaler categories from backend
  static Future<Map<String, List<String>>> getAllWholesalerCategories() async {
    try {
      final url = '$baseUrl/api/wholesaler-categories';
      
      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> categoriesData = responseData['data'] ?? [];
        
        // Convert the backend response to the expected format
        final Map<String, List<String>> categoriesMap = {};
        
        for (var category in categoriesData) {
          if (category['name'] != null) {
            final String categoryName = category['name'];
            
            // Parse subcategories from the backend response
            List<String> subcategories = [];
            if (category['subcategories'] != null) {
              final subcategoriesData = category['subcategories'] as List<dynamic>;
              subcategories = subcategoriesData.map((sub) => sub.toString()).toList();
            }
            
            categoriesMap[categoryName] = subcategories;
            
            // Debug logging for each category
            print('Parsed wholesaler category: "$categoryName" with ${subcategories.length} subcategories: $subcategories');
          }
        }

        print('Successfully fetched ${categoriesMap.length} wholesaler categories from backend');
        print('Wholesaler Categories: ${categoriesMap.keys.toList()}');
        
        // Debug: Print the final map structure
        categoriesMap.forEach((category, subs) {
          print('Final wholesaler map entry: "$category" -> $subs');
        });
        
        print('=== WHOLESALER CATEGORIES METHOD COMPLETED ===');
        return categoriesMap;
      } else {
        // Failed to fetch wholesaler categories
        print('=== WHOLESALER CATEGORIES METHOD FAILED ===');
        // Return empty map on error
        return {};
      }
    } catch (e) {
      print('Error fetching wholesaler categories: $e');
      print('=== WHOLESALER CATEGORIES METHOD ERROR ===');
      // Return empty map on error
      return {};
    }
  }

  // Voucher System Functions

  /// Get available vouchers for the current user
  static Future<Map<String, dynamic>> getAvailableVouchers() async {
    try {
      // Check authentication
      if (!await isAuthenticated()) {
        throw Exception('Authentication required');
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/vouchers'),
        headers: await _getHeaders(),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData['data'] ?? {};
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to get available vouchers');
      }
    } catch (e) {
      throw Exception('Failed to get available vouchers: ${e.toString()}');
    }
  }

  /// Purchase a voucher with points
  static Future<Map<String, dynamic>> purchaseVoucher(String voucherId) async {
    try {
      // Check authentication
      if (!await isAuthenticated()) {
        throw Exception('Authentication required');
      }

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/vouchers/purchase'),
        headers: await _getHeaders(),
        body: jsonEncode({'voucherId': voucherId}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to purchase voucher');
      }
    } catch (e) {
      throw Exception('Failed to purchase voucher: ${e.toString()}');
    }
  }

  /// Get user's purchased vouchers
  static Future<Map<String, dynamic>> getUserPurchasedVouchers() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/vouchers/my-vouchers'),
        headers: await _getHeaders(),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData['data'] ?? {};
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to get purchased vouchers');
      }
    } catch (e) {
      throw Exception('Failed to get purchased vouchers: ${e.toString()}');
    }
  }

}

