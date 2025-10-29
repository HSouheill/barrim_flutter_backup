// lib/src/services/performance_optimized_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/centralized_token_manager.dart';

/// Performance-optimized API service with caching, request deduplication, and parallel processing
class PerformanceOptimizedApiService {
  static const String baseUrl = 'https://barrim.online';
  
  // Cache configuration
  static const Duration _cacheExpiry = Duration(minutes: 15);
  static const Duration _longCacheExpiry = Duration(hours: 1);
  static const Duration _shortCacheExpiry = Duration(minutes: 5);
  
  // Request deduplication
  static final Map<String, Future<dynamic>> _ongoingRequests = {};
  
  // HTTP client with connection pooling
  static http.Client? _httpClient;
  
  // Cache storage (currently unused but available for future use)
  // static const _secureStorage = FlutterSecureStorage(
  //   aOptions: AndroidOptions(encryptedSharedPreferences: true),
  //   iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  // );
  
  static SharedPreferences? _prefs;
  
  /// Initialize the service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _httpClient = http.Client();
  }
  
  /// Get HTTP client with connection pooling
  static http.Client get _client {
    _httpClient ??= http.Client();
    return _httpClient!;
  }
  
  /// Check network connectivity
  static Future<bool> _isConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.isNotEmpty && results.first != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }
  
  /// Get cached data if valid
  static Future<Map<String, dynamic>?> _getCachedData(String key, Duration maxAge) async {
    try {
      final cached = _prefs?.getString('cache_$key');
      if (cached == null) return null;
      
      final data = json.decode(cached);
      final timestamp = DateTime.parse(data['timestamp']);
      
      if (DateTime.now().difference(timestamp) > maxAge) {
        await _prefs?.remove('cache_$key');
        return null;
      }
      
      return data['data'];
    } catch (e) {
      return null;
    }
  }
  
  /// Cache data with timestamp
  static Future<void> _cacheData(String key, dynamic data) async {
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _prefs?.setString('cache_$key', json.encode(cacheData));
    } catch (e) {
      if (kDebugMode) print('Cache error: $e');
    }
  }
  
  /// Make optimized HTTP request with caching and deduplication
  static Future<T> _makeOptimizedRequest<T>(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Duration? cacheExpiry,
    T Function(Map<String, dynamic>)? fromJson,
    String? cacheKey,
  }) async {
    final requestKey = '$method:$endpoint:${body?.toString() ?? ''}';
    
    // Check for ongoing request (deduplication)
    if (_ongoingRequests.containsKey(requestKey)) {
      return _ongoingRequests[requestKey] as T;
    }
    
    // Check cache if cacheKey is provided
    if (cacheKey != null && cacheExpiry != null) {
      final cached = await _getCachedData(cacheKey, cacheExpiry);
      if (cached != null) {
        if (kDebugMode) print('Cache hit for $cacheKey');
        return fromJson != null ? fromJson(cached) : cached as T;
      }
    }
    
    // Check connectivity
    final isConnected = await _isConnected();
    if (!isConnected) {
      // Try to return cached data even if expired
      if (cacheKey != null) {
        final cached = await _getCachedData(cacheKey, const Duration(days: 30));
        if (cached != null) {
          if (kDebugMode) print('Offline: Using expired cache for $cacheKey');
          return fromJson != null ? fromJson(cached) : cached as T;
        }
      }
      throw Exception('No internet connection');
    }
    
    // Create the request
    final future = _executeRequest<T>(
      method,
      endpoint,
      headers: headers,
      body: body,
      cacheKey: cacheKey,
      cacheExpiry: cacheExpiry,
      fromJson: fromJson,
    );
    
    // Store ongoing request
    _ongoingRequests[requestKey] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      // Remove from ongoing requests
      _ongoingRequests.remove(requestKey);
    }
  }
  
  /// Execute the actual HTTP request
  static Future<T> _executeRequest<T>(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    String? cacheKey,
    Duration? cacheExpiry,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final authHeaders = await CentralizedTokenManager.getAuthHeaders();
    final requestHeaders = {...authHeaders, ...?headers};
    
    // Optimized timeout based on request type
    final timeout = _getTimeoutForEndpoint(endpoint);
    
    http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await _client.get(uri, headers: requestHeaders).timeout(timeout);
        break;
      case 'POST':
        response = await _client.post(uri, headers: requestHeaders, body: body).timeout(timeout);
        break;
      case 'PUT':
        response = await _client.put(uri, headers: requestHeaders, body: body).timeout(timeout);
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: requestHeaders, body: body).timeout(timeout);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      
      // Cache successful responses
      if (cacheKey != null && cacheExpiry != null) {
        await _cacheData(cacheKey, data);
      }
      
      return fromJson != null ? fromJson(data) : data as T;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
  
  /// Get optimized timeout based on endpoint
  static Duration _getTimeoutForEndpoint(String endpoint) {
    if (endpoint.contains('/signup') || endpoint.contains('/upload')) {
      return const Duration(seconds: 30); // Reduced from 60
    } else if (endpoint.contains('/search') || endpoint.contains('/filter')) {
      return const Duration(seconds: 10);
    } else {
      return const Duration(seconds: 15); // Reduced from 30
    }
  }
  
  /// Parallel data fetching for dashboard
  static Future<Map<String, dynamic>> fetchDashboardData() async {
    final futures = await Future.wait([
      fetchCategories(),
      fetchCompanies(),
      fetchBranches(),
      fetchWholesalers(),
    ]);
    
    return {
      'categories': futures[0],
      'companies': futures[1],
      'branches': futures[2],
      'wholesalers': futures[3],
    };
  }
  
  /// Fetch categories with caching
  static Future<List<dynamic>> fetchCategories() async {
    return _makeOptimizedRequest<List<dynamic>>(
      'GET',
      '/api/categories',
      cacheKey: 'categories',
      cacheExpiry: _longCacheExpiry,
      fromJson: (data) => data['data'] as List<dynamic>,
    );
  }
  
  /// Fetch companies with caching
  static Future<List<dynamic>> fetchCompanies() async {
    return _makeOptimizedRequest<List<dynamic>>(
      'GET',
      '/api/user/companies',
      cacheKey: 'companies',
      cacheExpiry: _cacheExpiry,
      fromJson: (data) => data['data'] as List<dynamic>,
    );
  }
  
  /// Fetch branches with caching
  static Future<List<dynamic>> fetchBranches() async {
    return _makeOptimizedRequest<List<dynamic>>(
      'GET',
      '/api/all-branches',
      cacheKey: 'branches',
      cacheExpiry: _cacheExpiry,
      fromJson: (data) => data['data'] as List<dynamic>,
    );
  }
  
  /// Fetch wholesalers with caching
  static Future<List<dynamic>> fetchWholesalers() async {
    return _makeOptimizedRequest<List<dynamic>>(
      'GET',
      '/api/wholesalers',
      cacheKey: 'wholesalers',
      cacheExpiry: _cacheExpiry,
      fromJson: (data) => data['data'] as List<dynamic>,
    );
  }
  
  /// Paginated data fetching
  static Future<Map<String, dynamic>> fetchPaginatedData(
    String endpoint, {
    int page = 1,
    int limit = 20,
    Map<String, String>? filters,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      ...?filters,
    };
    
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParams,
    );
    
    return _makeOptimizedRequest<Map<String, dynamic>>(
      'GET',
      uri.toString(),
      cacheKey: '${endpoint}_page_${page}_limit_$limit',
      cacheExpiry: _shortCacheExpiry,
    );
  }
  
  /// Clear all caches
  static Future<void> clearCache() async {
    try {
      final keys = _prefs?.getKeys().where((key) => key.startsWith('cache_')).toList() ?? [];
      for (final key in keys) {
        _prefs?.remove(key);
      }
      if (kDebugMode) print('Cache cleared: ${keys.length} entries');
    } catch (e) {
      if (kDebugMode) print('Cache clear error: $e');
    }
  }
  
  /// Clear specific cache
  static Future<void> clearCacheForKey(String key) async {
    _prefs?.remove('cache_$key');
  }
  
  /// Close HTTP client
  static void dispose() {
    _httpClient?.close();
    _httpClient = null;
  }
}
