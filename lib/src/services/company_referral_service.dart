import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/services.dart';

class CompanyReferralService {
  final String baseUrl = ApiService.baseUrl;
  final String token;

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

  CompanyReferralService({required this.token});

  // Headers for authenticated requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // Get company referral data
  Future<Map<String, dynamic>> getCompanyReferralData() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/referrals/data'),
        headers: _headers,
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return {
            'success': false,
            'error': 'Empty response body',
          };
        }

        try {
          final data = json.decode(responseBody);
          // Handle both direct data and nested data structures
          final resultData = data is Map<String, dynamic>
              ? (data.containsKey('data') ? data['data'] : data)
              : {};

          return {
            'success': true,
            'data': resultData,
          };
        } catch (parseError) {
          print('JSON parse error: $parseError');
          return {
            'success': false,
            'error': 'Failed to parse response: $parseError',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch referral data: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Exception in getCompanyReferralData: $e');
      return {
        'success': false,
        'error': 'Error fetching referral data: $e',
      };
    }
  }


  // Generate QR code for referral link
  Future<Uint8List> generateReferralQRCode(String referralLink) async {
    try {
      // Based on company_routes.go, this endpoint doesn't need a link parameter
      // as it will use the authenticated company's referral link
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/referrals/qrcode'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to generate QR code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating QR code: $e');
    }
  }

  // Handle company referral during signup
  Future<Map<String, dynamic>> handleCompanyReferral(String referralCode) async {
    // Input validation
    if (referralCode.trim().isEmpty) {
      return {
        'success': false,
        'error': 'Referral code is required',
      };
    }
    
    // Basic referral code format validation
    if (referralCode.trim().length < 3 || referralCode.trim().length > 20) {
      return {
        'success': false,
        'error': 'Invalid referral code format',
      };
    }
    
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/company/handle-referral'),
        headers: _headers,
        body: json.encode({'referralCode': referralCode.trim()}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to process referral: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error processing referral: $e',
      };
    }
  }

  // Share referral code or link
  Future<void> shareReferral({required String code, required String link}) async {
    // Input validation
    if (code.trim().isEmpty) {
      throw Exception('Referral code is required');
    }
    
    if (link.trim().isEmpty) {
      throw Exception('Referral link is required');
    }
    
    // URL validation
    if (!RegExp(r'^https?:\/\/').hasMatch(link.trim())) {
      throw Exception('Invalid referral link format');
    }
    
    // This would integrate with the device's sharing capabilities
    // Implementation depends on the sharing package you use (like share_plus)
    // Placeholder implementation
    try {
      await Clipboard.setData(ClipboardData(text: code.trim()));
      // In a real app, you would trigger the share dialog here
    } catch (e) {
      throw Exception('Error sharing referral');
    }
  }


}