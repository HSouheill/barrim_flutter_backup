// lib/services/company_service.dart
// This service ensures all API calls use HTTPS for security
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_model.dart';
import '../models/api_response.dart' as api;
import '../utils/api_constants.dart';
import '../utils/token_manager.dart';

class CompanyService {
  final TokenManager _tokenManager = TokenManager();
  final String _baseUrl = ApiConstants.baseUrl;

  // Validate that all URLs are using HTTPS
  bool _validateHttpsUrl(String url) {
    if (!url.startsWith('https://')) {
      print('CompanyService: WARNING - Non-HTTPS URL detected: $url');
      return false;
    }
    return true;
  }

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

  // Get the company profile data
  Future<Company> getCompanyData() async {
    if (!kReleaseMode) {
      print('CompanyService: getCompanyData called');
    }

    try {
      final token = await _tokenManager.getToken();
      if (!kReleaseMode) {
        print('CompanyService: Token retrieved: ${token?.isNotEmpty == true ? 'Token exists' : 'No token'}');
      }

      final url = '$_baseUrl/api/companies/data';
      if (!kReleaseMode) {
        print('CompanyService: Making request to: $url');
      }
      
      // Ensure HTTPS is being used
      if (!_validateHttpsUrl(url)) {
        throw Exception('Cannot get company data with non-HTTPS URL');
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = api.ApiResponse<Map<String, dynamic>>.fromJson(responseData);

        if (apiResponse.success || apiResponse.status == 200) {
          if (apiResponse.data == null) {
            throw Exception(apiResponse.getEmptyDataMessage('company'));
          }
          final company = Company.fromJson(apiResponse.data!);
          return company;
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        // Failed to load company data
        throw Exception('Failed to load company data');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('CompanyService: Exception caught: $e');
      }
      throw Exception('Error in getCompanyData: $e');
    }
  }

  // Update company profile with JSON data (no file upload)
  Future<Company> updateCompanyProfile({
    String? businessName,
    String? email,
    String? currentPassword,
    String? newPassword,
    String? fullName,
    String? phone,
    String? website,
    String? whatsApp,
    String? facebook,
    String? instagram,
  }) async {
    final token = await _tokenManager.getToken();

    // Input validation
    if (email != null && email.trim().isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
        throw Exception('Invalid email format');
      }
    }
    
    if (phone != null && phone.trim().isNotEmpty) {
      if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phone.replaceAll(RegExp(r'[\s-]'), ''))) {
        throw Exception('Invalid phone number format');
      }
    }
    
    if (website != null && website.trim().isNotEmpty) {
      if (!RegExp(r'^https?:\/\/').hasMatch(website.trim())) {
        throw Exception('Website must start with http:// or https://');
      }
    }
    
    if (newPassword != null && newPassword.trim().isNotEmpty) {
      if (newPassword.length < 6) {
        throw Exception('New password must be at least 6 characters long');
      }
    }

    // Build request body with only non-null values
    final Map<String, dynamic> requestBody = {};

    if (businessName != null) requestBody['businessName'] = businessName.trim();
    if (email != null) requestBody['email'] = email.trim();
    if (currentPassword != null) requestBody['currentPassword'] = currentPassword.trim();
    if (newPassword != null) requestBody['newPassword'] = newPassword.trim();
    if (fullName != null) requestBody['fullName'] = fullName.trim();
    if (phone != null) requestBody['phone'] = phone.trim();
    if (website != null) requestBody['website'] = website.trim();
    if (whatsApp != null) requestBody['whatsapp'] = whatsApp.trim();
    if (facebook != null) requestBody['facebook'] = facebook.trim();
    if (instagram != null) requestBody['instagram'] = instagram.trim();

    final url = '$_baseUrl/api/companies/profile';
    
    // Ensure HTTPS is being used
    if (!_validateHttpsUrl(url)) {
      throw Exception('Cannot update company profile with non-HTTPS URL');
    }
    
    final response = await _makeRequest(
      'PUT',
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Company.fromJson(data['data']);
    } else {
      throw Exception('Failed to update company profile');
    }
  }

  // Update company profile with multipart form (with optional file upload)
  Future<Company> updateCompanyProfileWithLogo({
    String? businessName,
    String? email,
    String? currentPassword,
    String? newPassword,
    String? fullName,
    String? phone,
    String? website,
    String? whatsApp,
    String? facebook,
    String? instagram,
    File? logoFile,
  }) async {
    final token = await _tokenManager.getToken();

    final url = '$_baseUrl/api/companies/profile';
    
    // Ensure HTTPS is being used
    if (!_validateHttpsUrl(url)) {
      throw Exception('Cannot update company profile with logo using non-HTTPS URL');
    }
    
    // Create multipart request
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse(url),
    );

    // Add authorization header
    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    // Add text fields if they're not null
    if (businessName != null) request.fields['businessName'] = businessName;
    if (email != null) request.fields['email'] = email;
    if (currentPassword != null) request.fields['currentPassword'] = currentPassword;
    if (newPassword != null) request.fields['newPassword'] = newPassword;
    if (fullName != null) request.fields['fullName'] = fullName;
    if (phone != null) request.fields['phone'] = phone;
    if (website != null) request.fields['website'] = website;
    if (whatsApp != null) request.fields['whatsapp'] = whatsApp;
    if (facebook != null) request.fields['facebook'] = facebook;
    if (instagram != null) request.fields['instagram'] = instagram;

    // Add logo file if provided
    if (logoFile != null) {
      final fileExtension = logoFile.path.split('.').last.toLowerCase();
      final contentType = _getContentType(fileExtension);

      request.files.add(
        await http.MultipartFile.fromPath(
          'logo',
          logoFile.path,
          contentType: contentType,
        ),
      );
    }

    // Send the request
    final client = await _getCustomClient();
    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Company.fromJson(data['data']);
    } else {
      throw Exception('Failed to update company profile with logo');
    }
  }

  // Upload logo only
  Future<String> uploadCompanyLogo(File logoFile) async {
    final token = await _tokenManager.getToken();

    // Input validation
    if (!await logoFile.exists()) {
      throw Exception('Logo file does not exist');
    }
    
    final fileSize = await logoFile.length();
    if (fileSize > 5 * 1024 * 1024) { // 5MB limit
      throw Exception('Logo file is too large. Maximum size is 5MB');
    }
    
    final fileExtension = logoFile.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
      throw Exception('Invalid file format. Only JPG, PNG, and GIF are allowed');
    }

    final url = '$_baseUrl/api/companies/logo';
    
    // Ensure HTTPS is being used
    if (!_validateHttpsUrl(url)) {
      throw Exception('Cannot upload company logo using non-HTTPS URL');
    }
    
    // Create multipart request
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(url),
    );

    // Add authorization header
    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    // Add logo file
    final logoFileExtension = logoFile.path.split('.').last.toLowerCase();
    final contentType = _getContentType(logoFileExtension);

    request.files.add(
      await http.MultipartFile.fromPath(
        'logo',
        logoFile.path,
        contentType: contentType,
      ),
    );

    // Send the request
    final client = await _getCustomClient();
    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data['data']['logoUrl'];
    } else {
      throw Exception('Failed to upload logo');
    }
  }

  // Helper method to determine content type based on file extension
  MediaType _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  // Get all branches
  Future<List<Map<String, dynamic>>> getAllBranches() async {
    try {
      final token = await _tokenManager.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final url = '${_baseUrl}/api/all-branches';
      if (!kReleaseMode) {
        print('Fetching branches from URL: $url');
      }
      
      // Ensure HTTPS is being used
      if (!_validateHttpsUrl(url)) {
        throw Exception('Cannot get all branches using non-HTTPS URL');
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = api.ApiResponse<List<dynamic>>.fromJson(responseData);

        if (apiResponse.success || apiResponse.status == 200) {
          if (apiResponse.data == null) {
            throw Exception(apiResponse.getEmptyDataMessage('branches'));
          }
          final branches = List<Map<String, dynamic>>.from(apiResponse.data!);
          return branches;
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('Failed to fetch branches');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error in getAllBranches: $e');
      }
      throw Exception('Failed to get branches: $e');
    }
  }

  // Function to get a specific branch by ID
  Future<Map<String, dynamic>> getBranchById(String branchId) async {
    // Input validation
    if (branchId.trim().isEmpty) {
      throw Exception('Branch ID is required');
    }
    
    // Basic ID format validation (assuming MongoDB ObjectId format)
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(branchId.trim())) {
      throw Exception('Invalid branch ID format');
    }

    try {
      final token = await _tokenManager.getToken();
      if (!kReleaseMode) {
        print('CompanyService: Token retrieved: ${token?.isNotEmpty == true ? 'Token exists' : 'No token'}');
      }

      final url = '$_baseUrl/api/companies/branches/$branchId';
      if (!kReleaseMode) {
        print('CompanyService: Making request to: $url');
      }
      
      // Ensure HTTPS is being used
      if (!_validateHttpsUrl(url)) {
        throw Exception('Cannot get branch by ID using non-HTTPS URL');
      }

      final response = await _makeRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final apiResponse = api.ApiResponse<Map<String, dynamic>>.fromJson(responseData);

        if (apiResponse.success || apiResponse.status == 200) {
          if (apiResponse.data == null) {
            throw Exception(apiResponse.getEmptyDataMessage('branch'));
          }
          return apiResponse.data!;
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        // Failed to load branch data
        throw Exception('Failed to load branch data');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('CompanyService: Exception caught: $e');
      }
      throw Exception('Error in getBranchById: $e');
    }
  }
}

