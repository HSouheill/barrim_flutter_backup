import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/services.dart';

class CompanyReferralService {
  final String baseUrl = ApiService.baseUrl;
  final String token;

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

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

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
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/company/handle-referral'),
        headers: _headers,
        body: json.encode({'referralCode': referralCode}),
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
    // This would integrate with the device's sharing capabilities
    // Implementation depends on the sharing package you use (like share_plus)
    // Placeholder implementation
    try {
      await Clipboard.setData(ClipboardData(text: code));
      // In a real app, you would trigger the share dialog here
    } catch (e) {
      throw Exception('Error sharing referral: $e');
    }
  }


}