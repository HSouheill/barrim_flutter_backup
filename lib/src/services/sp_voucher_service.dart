import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/voucher_models.dart';
import 'api_service.dart';

class ServiceProviderVoucherService {
  // Base URL for API calls
  final String baseUrl = ApiService.baseUrl;

  // Debug mode flag
  final bool _debugMode = kDebugMode;

  // --- Custom HTTP client with proper SSL handling ---
  static http.Client? _customClient;
  static Future<http.Client> _getCustomClient() async {
    if (_customClient != null) return _customClient!;
    
    // In production, use standard HTTP client for proper SSL validation
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
        return await client.delete(uri, headers: headers);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

  // Get the auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        // Fallback to secure storage (primary token storage elsewhere in app)
        try {
          const secureStorage = FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );
          final secureToken = await secureStorage.read(key: 'auth_token');
          if (secureToken == null || secureToken.isEmpty) {
            _logDebug('Auth token is null or empty');
            return null;
          }
          return secureToken;
        } catch (e) {
          _logDebug('Error reading token from secure storage: $e');
          return null;
        }
      }

      return token;
    } catch (e) {
      _logDebug('Error retrieving auth token: $e');
      return null;
    }
  }

  // Log debug messages
  void _logDebug(String message) {
    if (_debugMode && !kReleaseMode) {
      debugPrint('🔍 ServiceProviderVoucherService: $message');
    }
  }

  // Get available vouchers for service provider
  Future<VoucherResult<List<ServiceProviderVoucher>>> getAvailableVouchers() async {
    try {
      _logDebug('Fetching available vouchers...');
      final token = await _getAuthToken();
      if (token == null) {
        return VoucherResult.error('Authentication token not found. Please log in again.');
      }

      final Uri endpoint = Uri.parse('$baseUrl/api/service-providers/vouchers/available');
      _logDebug('Sending GET request to: $endpoint');

      final response = await _makeRequest(
        'GET',
        endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _logDebug('Request timed out');
          throw Exception('Connection timed out. Please check your internet connection.');
        },
      );

      _logDebug('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);

          if (responseData['status'] == 200 && responseData['data'] != null) {
            final data = responseData['data'];
            final List<dynamic> vouchersJson = data['vouchers'] ?? [];
            
            final List<ServiceProviderVoucher> vouchers = vouchersJson
                .map((json) => ServiceProviderVoucher.fromJson(json))
                .toList();

            _logDebug('Successfully parsed ${vouchers.length} vouchers');
            return VoucherResult.success(vouchers);
          } else {
            final message = responseData['message'] ?? 'Failed to load vouchers';
            _logDebug('API returned error: $message');
            return VoucherResult.error(message);
          }
        } catch (e) {
          _logDebug('Error parsing response: $e');
          return VoucherResult.error('Error parsing server response. Please try again later.');
        }
      } else if (response.statusCode == 401) {
        _logDebug('Authentication failed (401)');
        return VoucherResult.error('Session expired. Please log in again.');
      } else if (response.statusCode >= 500) {
        _logDebug('Server error (${response.statusCode})');
        return VoucherResult.error('Server is currently unavailable. Please try again later.');
      } else {
        _logDebug('HTTP error: ${response.statusCode}');
        return VoucherResult.error('Failed to load vouchers: ${response.statusCode}');
      }
    } catch (e) {
      _logDebug('Exception caught: $e');
      if (e.toString().contains('SocketException')) {
        return VoucherResult.error('No internet connection. Please check your network settings.');
      }
      return VoucherResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Purchase a voucher
  Future<VoucherResult<bool>> purchaseVoucher(String voucherId) async {
    try {
      _logDebug('Purchasing voucher: $voucherId');
      final token = await _getAuthToken();
      if (token == null) {
        return VoucherResult.error('Authentication token not found. Please log in again.');
      }

      final Uri endpoint = Uri.parse('$baseUrl/api/service-providers/vouchers/purchase');
      _logDebug('Sending POST request to: $endpoint');

      final request = VoucherPurchaseRequest(voucherId: voucherId);

      final response = await _makeRequest(
        'POST',
        endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _logDebug('Request timed out');
          throw Exception('Connection timed out. Please check your internet connection.');
        },
      );

      _logDebug('Purchase response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);

          if (responseData['status'] == 200) {
            _logDebug('Voucher purchased successfully');
            return VoucherResult.success(true);
          } else {
            final message = responseData['message'] ?? 'Failed to purchase voucher';
            _logDebug('API returned error: $message');
            return VoucherResult.error(message);
          }
        } catch (e) {
          _logDebug('Error parsing purchase response: $e');
          return VoucherResult.error('Error parsing server response. Please try again later.');
        }
      } else if (response.statusCode == 400) {
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ?? 'Invalid purchase request';
          _logDebug('Invalid purchase request: $errorMessage');
          return VoucherResult.error(errorMessage);
        } catch (e) {
          return VoucherResult.error('Invalid purchase request');
        }
      } else if (response.statusCode == 401) {
        _logDebug('Authentication failed (401)');
        return VoucherResult.error('Session expired. Please log in again.');
      } else if (response.statusCode == 409) {
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ?? 'You have already purchased this voucher';
          _logDebug('Conflict error: $errorMessage');
          return VoucherResult.error(errorMessage);
        } catch (e) {
          return VoucherResult.error('You have already purchased this voucher');
        }
      } else if (response.statusCode >= 500) {
        _logDebug('Server error (${response.statusCode})');
        return VoucherResult.error('Server is currently unavailable. Please try again later.');
      } else {
        _logDebug('HTTP error: ${response.statusCode}');
        return VoucherResult.error('Failed to purchase voucher: ${response.statusCode}');
      }
    } catch (e) {
      _logDebug('Exception caught: $e');
      if (e.toString().contains('SocketException')) {
        return VoucherResult.error('No internet connection. Please check your network settings.');
      }
      return VoucherResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Get purchased vouchers for service provider
  Future<VoucherResult<List<ServiceProviderVoucherPurchase>>> getPurchasedVouchers() async {
    try {
      _logDebug('Fetching purchased vouchers...');
      final token = await _getAuthToken();
      if (token == null) {
        return VoucherResult.error('Authentication token not found. Please log in again.');
      }

      final Uri endpoint = Uri.parse('$baseUrl/api/service-providers/vouchers/purchased');
      _logDebug('Sending GET request to: $endpoint');

      final response = await _makeRequest(
        'GET',
        endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _logDebug('Request timed out');
          throw Exception('Connection timed out. Please check your internet connection.');
        },
      );

      _logDebug('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);

          if (responseData['status'] == 200 && responseData['data'] != null) {
            // Backend returns list under data.vouchers with nested 'purchase'
            final List<dynamic> vouchersArray = responseData['data']['vouchers'] ?? [];

            final List<ServiceProviderVoucherPurchase> purchases = vouchersArray
                .map((item) => ServiceProviderVoucherPurchase.fromJson(item['purchase'] ?? {}))
                .toList();

            _logDebug('Successfully parsed ${purchases.length} purchased vouchers');
            return VoucherResult.success(purchases);
          } else {
            final message = responseData['message'] ?? 'Failed to load purchased vouchers';
            _logDebug('API returned error: $message');
            return VoucherResult.error(message);
          }
        } catch (e) {
          _logDebug('Error parsing response: $e');
          return VoucherResult.error('Error parsing server response. Please try again later.');
        }
      } else if (response.statusCode == 401) {
        _logDebug('Authentication failed (401)');
        return VoucherResult.error('Session expired. Please log in again.');
      } else if (response.statusCode >= 500) {
        _logDebug('Server error (${response.statusCode})');
        return VoucherResult.error('Server is currently unavailable. Please try again later.');
      } else {
        _logDebug('HTTP error: ${response.statusCode}');
        return VoucherResult.error('Failed to load purchased vouchers: ${response.statusCode}');
      }
    } catch (e) {
      _logDebug('Exception caught: $e');
      if (e.toString().contains('SocketException')) {
        return VoucherResult.error('No internet connection. Please check your network settings.');
      }
      return VoucherResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Use a voucher
  Future<VoucherResult<bool>> useVoucher(String purchaseId) async {
    try {
      _logDebug('Using voucher purchase: $purchaseId');
      final token = await _getAuthToken();
      if (token == null) {
        return VoucherResult.error('Authentication token not found. Please log in again.');
      }

      final Uri endpoint = Uri.parse('$baseUrl/api/service-providers/vouchers/$purchaseId/use');
      _logDebug('Sending PUT request to: $endpoint');

      final response = await _makeRequest(
        'PUT',
        endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _logDebug('Request timed out');
          throw Exception('Connection timed out. Please check your internet connection.');
        },
      );

      _logDebug('Use voucher response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);

          if (responseData['status'] == 200) {
            _logDebug('Voucher used successfully');
            return VoucherResult.success(true);
          } else {
            final message = responseData['message'] ?? 'Failed to use voucher';
            _logDebug('API returned error: $message');
            return VoucherResult.error(message);
          }
        } catch (e) {
          _logDebug('Error parsing use voucher response: $e');
          return VoucherResult.error('Error parsing server response. Please try again later.');
        }
      } else if (response.statusCode == 400) {
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ?? 'Invalid voucher usage request';
          _logDebug('Invalid use request: $errorMessage');
          return VoucherResult.error(errorMessage);
        } catch (e) {
          return VoucherResult.error('Invalid voucher usage request');
        }
      } else if (response.statusCode == 401) {
        _logDebug('Authentication failed (401)');
        return VoucherResult.error('Session expired. Please log in again.');
      } else if (response.statusCode == 404) {
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ?? 'Voucher purchase not found';
          _logDebug('Not found error: $errorMessage');
          return VoucherResult.error(errorMessage);
        } catch (e) {
          return VoucherResult.error('Voucher purchase not found');
        }
      } else if (response.statusCode >= 500) {
        _logDebug('Server error (${response.statusCode})');
        return VoucherResult.error('Server is currently unavailable. Please try again later.');
      } else {
        _logDebug('HTTP error: ${response.statusCode}');
        return VoucherResult.error('Failed to use voucher: ${response.statusCode}');
      }
    } catch (e) {
      _logDebug('Exception caught: $e');
      if (e.toString().contains('SocketException')) {
        return VoucherResult.error('No internet connection. Please check your network settings.');
      }
      return VoucherResult.error('An unexpected error occurred: ${e.toString()}');
    }
  }
}
