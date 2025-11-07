import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/api_constants.dart';

class ServiceProviderCategoryService {
  static const String _baseUrl = ApiConstants.baseUrl;
  static const String _endpoint = ApiConstants.serviceProviderCategoriesEndpoint;
  
  // Secure storage for tokens
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Headers for API requests
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.read(key: 'auth_token');

    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
      'User-Agent': 'BarrimApp/1.0.12',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
  }

  // Custom HTTP client with proper SSL handling
  static http.Client? _customClient;
  static Future<http.Client> _getCustomClient() async {
    if (_customClient != null) return _customClient!;
    
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
    
    try {
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
    }
  }

  // Get all service provider categories
  static Future<List<ServiceProviderCategory>> getAllServiceProviderCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl$_endpoint');
      final headers = await _getHeaders();
      
      print('ServiceProviderCategoryService: Fetching categories from: $uri');
      
      final response = await _makeRequest('GET', uri, headers: headers);
      
      print('ServiceProviderCategoryService: Response status: ${response.statusCode}');
      print('ServiceProviderCategoryService: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['status'] == 200) {
          // Handle both null and empty array cases gracefully
          final List<dynamic>? categoriesData = responseData['data'];
          
          // Return empty list if data is null or empty array
          if (categoriesData == null || categoriesData.isEmpty) {
            print('ServiceProviderCategoryService: No categories found in response');
            return [];
          }
          
          return categoriesData.map((category) {
            return ServiceProviderCategory.fromJson(category);
          }).toList();
        } else {
          // Only throw error if status is not 200
          throw Exception('Failed to retrieve service provider categories: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception('Failed to retrieve service provider categories: ${errorData['message'] ?? 'HTTP ${response.statusCode}'}');
      }
    } catch (e) {
      print('ServiceProviderCategoryService: Error fetching categories: $e');
      rethrow;
    }
  }
}

class ServiceProviderCategory {
  final String id;
  final String name;
  final String? icon;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ServiceProviderCategory({
    required this.id,
    required this.name,
    this.icon,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ServiceProviderCategory.fromJson(Map<String, dynamic> json) {
    return ServiceProviderCategory(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'],
      description: json['description'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'description': description,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ServiceProviderCategory(id: $id, name: $name, icon: $icon, isActive: $isActive)';
  }
}
