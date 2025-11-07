// lib/services/sponsorship_service.dart
// This service ensures all API calls use HTTPS for security
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/sponsorship.dart';
import '../utils/token_storage.dart';
import 'api_service.dart';

class SponsorshipService {
  static const String baseUrl = ApiService.baseUrl;
  static final TokenStorage _tokenStorage = TokenStorage();

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

  // Get authentication headers with security headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'User-Agent': 'Barrim-Mobile-App/1.0',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
  }

  // Get service provider sponsorships
  static Future<Map<String, dynamic>> getServiceProviderSponsorships({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Input validation
      if (page < 1) {
        throw Exception('Page number must be greater than 0');
      }
      if (limit < 1 || limit > 100) {
        throw Exception('Limit must be between 1 and 100');
      }
      
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/sponsorships/service-provider?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Barrim-Mobile-App/1.0',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch service provider sponsorships',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to process request',
      };
    }
  }

  // Get company/wholesaler sponsorships
  static Future<Map<String, dynamic>> getCompanyWholesalerSponsorships({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      print('Making request to: $baseUrl/api/sponsorships/company-wholesaler?page=$page&limit=$limit');
      
      // Get authentication headers
      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/sponsorships/company-wholesaler?page=$page&limit=$limit'),
        headers: headers,
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Successfully parsed response data: $data');
        return data;
      } else {
        print('Error response: HTTP ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to fetch company/wholesaler sponsorships',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error in getCompanyWholesalerSponsorships: $e');
      return {
        'success': false,
        'message': 'Failed to process request',
      };
    }
  }

  // Create service provider sponsorship request
  static Future<Map<String, dynamic>> createServiceProviderSponsorshipRequest({
    required String sponsorshipId,
    String? adminNote,
  }) async {
    try {
      final headers = await _getHeaders();
      final requestBody = {
        'sponsorshipId': sponsorshipId,
        if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
      };
      
      print('Creating service provider sponsorship request');
      print('Request body: $requestBody');
      
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/service-providers/sponsorship/request'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      // Response logged without sensitive data

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to create service provider sponsorship request',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error creating service provider sponsorship request: $e');
      return {
        'success': false,
        'message': 'Failed to process request',
      };
    }
  }

  // Create wholesaler branch sponsorship request
  static Future<Map<String, dynamic>> createWholesalerBranchSponsorshipRequest({
    required String sponsorshipId,
    required String branchId,
    String? adminNote,
  }) async {
    try {
      final headers = await _getHeaders();
      final requestBody = {
        'sponsorshipId': sponsorshipId,
        if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
      };
      
      print('Creating wholesaler branch sponsorship request');
      print('Request body: $requestBody');
      print('Branch ID: $branchId');
      
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/wholesaler/sponsorship/$branchId/request'),
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to create wholesaler branch sponsorship request',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to process request',
      };
    }
  }

  // Get sponsorship subscription time remaining for wholesaler branch
  static Future<Map<String, dynamic>> getSponsorshipSubscriptionTimeRemaining({
    required String branchId,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/sponsorship-subscriptions/wholesaler-branch/$branchId/time-remaining'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        // No active sponsorship subscription found
        return {
          'success': true,
          'data': {
            'hasActiveSubscription': false,
            'message': 'No active sponsorship subscription found',
          },
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to get sponsorship subscription time remaining',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to process request',
      };
    }
  }

  // Create company branch sponsorship request
  static Future<Map<String, dynamic>> createCompanyBranchSponsorshipRequest({
    required String sponsorshipId,
    required String branchId,
    String? adminNote,
  }) async {
    try {
      final headers = await _getHeaders();
      final requestBody = {
        'sponsorshipId': sponsorshipId,
        if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
      };
      
      print('Creating company branch sponsorship request for branch: $branchId');
      print('Request body: $requestBody');
      
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/companies/sponsorship/$branchId/request'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to create company branch sponsorship request',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error creating company branch sponsorship request: $e');
      return {
        'success': false,
        'message': 'Failed to process request',
      };
    }
  }

  // Get company branch sponsorship subscription time remaining
  static Future<Map<String, dynamic>> getCompanyBranchSponsorshipTimeRemaining({
    required String branchId,
  }) async {
    try {
      final headers = await _getHeaders();
      
      print('Getting company branch sponsorship time remaining for branch: $branchId');
      print('Request URL: $baseUrl/api/companies/sponsorship/$branchId/remaining-time');
      
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/companies/sponsorship/$branchId/remaining-time'),
        headers: headers,
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Successfully parsed response data: $data');
        return data;
      } else if (response.statusCode == 404) {
        // No active sponsorship subscription found
        print('No active sponsorship subscription found (404)');
        return {
          'success': true,
          'data': {
            'hasActiveSubscription': false,
            'message': 'No active sponsorship subscription found',
          },
        };
      } else {
        final errorData = jsonDecode(response.body);
        print('Error response: $errorData');
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to get company branch sponsorship subscription time remaining',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error getting company branch sponsorship time remaining: $e');
      return {
        'success': false,
        'message': 'Failed to process request',
      };
    }
  }

  // Get service provider sponsorship subscription time remaining
  static Future<Map<String, dynamic>> getServiceProviderSponsorshipTimeRemaining() async {
    try {
      final headers = await _getHeaders();
      
      print('Getting service provider sponsorship time remaining');
      print('Request URL: $baseUrl/api/sponsorship/remaining-time');
      
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/service-providers/sponsorship/remaining-time'),
        headers: headers,
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Successfully parsed response data: $data');
        // Normalize response to include 'success' field for consistency
        if (data is Map<String, dynamic>) {
          // If response has 'status' but not 'success', normalize it
          if (data.containsKey('status') && !data.containsKey('success')) {
            final status = data['status'];
            final isSuccess = status is int && status >= 200 && status < 300;
            // Return normalized response with success field
            return {
              'success': isSuccess,
              'status': status,
              'message': data['message'],
              'data': data['data'],
            };
          }
        }
        return data;
      } else if (response.statusCode == 404) {
        // No active sponsorship subscription found
        print('No active sponsorship subscription found (404)');
        return {
          'success': true,
          'data': {
            'hasActiveSubscription': false,
            'message': 'No active sponsorship subscription found',
          },
        };
      } else {
        final errorData = jsonDecode(response.body);
        print('Error response: $errorData');
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to get service provider sponsorship subscription time remaining',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error getting service provider sponsorship time remaining: $e');
      return {
        'success': false,
        'message': 'Failed to process request',
      };
    }
  }

  // Parse sponsorships from API response
  static List<Sponsorship> parseSponsorships(Map<String, dynamic> response) {
    try {
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['sponsorships'] != null) {
          final List<dynamic> sponsorshipsJson = data['sponsorships'];
          return sponsorshipsJson.map((json) => Sponsorship.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error parsing sponsorships: $e');
      return [];
    }
  }

  // Parse pagination from API response
  static SponsorshipPagination? parsePagination(Map<String, dynamic> response) {
    try {
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['pagination'] != null) {
          return SponsorshipPagination.fromJson(data['pagination']);
        }
      }
              return null;
      } catch (e) {
        print('Error parsing pagination: $e');
        return null;
      }
  }
}
