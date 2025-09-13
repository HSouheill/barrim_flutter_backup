import 'dart:convert';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;

class CompanyVoucherService {
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

  CompanyVoucherService({required this.token});

  // Headers for authenticated requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // Get available vouchers for company
  Future<Map<String, dynamic>> getAvailableVouchers() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/companies/vouchers/available'),
        headers: _headers,
      );

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
          return {
            'success': true,
            'data': data['data'],
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
          'error': 'Failed to fetch vouchers: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Exception in getAvailableVouchers: $e');
      return {
        'success': false,
        'error': 'Error fetching vouchers: $e',
      };
    }
  }

  // Purchase voucher for company
  Future<Map<String, dynamic>> purchaseVoucher(String voucherId) async {
    try {
      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/companies/vouchers/purchase'),
        headers: _headers,
        body: json.encode({'voucherId': voucherId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to purchase voucher: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Exception in purchaseVoucher: $e');
      return {
        'success': false,
        'error': 'Error purchasing voucher: $e',
      };
    }
  }

  // Get purchased vouchers for company
  Future<Map<String, dynamic>> getPurchasedVouchers() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/companies/vouchers/purchased'),
        headers: _headers,
      );

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
          return {
            'success': true,
            'data': data['data'],
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
          'error': 'Failed to fetch purchased vouchers: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Exception in getPurchasedVouchers: $e');
      return {
        'success': false,
        'error': 'Error fetching purchased vouchers: $e',
      };
    }
  }
}
