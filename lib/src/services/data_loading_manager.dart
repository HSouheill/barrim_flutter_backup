// lib/src/services/data_loading_manager.dart
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'performance_optimized_api_service.dart';

/// Manages data loading with smart caching, offline support, and loading states
class DataLoadingManager extends ChangeNotifier {
  static final DataLoadingManager _instance = DataLoadingManager._internal();
  factory DataLoadingManager() => _instance;
  DataLoadingManager._internal();
  
  // Loading states for different data types
  final Map<String, bool> _loadingStates = {};
  final Map<String, String?> _errorStates = {};
  final Map<String, dynamic> _cachedData = {};
  
  // Connectivity
  bool _isOnline = true;
  Connectivity? _connectivity;
  
  /// Initialize the manager
  Future<void> initialize() async {
    await PerformanceOptimizedApiService.initialize();
    _connectivity = Connectivity();
    _connectivity!.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _onConnectivityChanged(results.isNotEmpty ? results.first : ConnectivityResult.none);
    });
    _isOnline = await _isConnected();
  }
  
  /// Check if currently online
  Future<bool> _isConnected() async {
    try {
      final results = await _connectivity?.checkConnectivity();
      return results != null && results.isNotEmpty && results.first != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }
  
  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    if (!wasOnline && _isOnline) {
      // Came back online - refresh critical data
      _refreshCriticalData();
    }
    
    notifyListeners();
  }
  
  /// Get loading state for a data type
  bool isLoading(String dataType) => _loadingStates[dataType] ?? false;
  
  /// Get error state for a data type
  String? getError(String dataType) => _errorStates[dataType];
  
  /// Get cached data
  T? getCachedData<T>(String dataType) => _cachedData[dataType] as T?;
  
  /// Check if data is cached
  bool hasCachedData(String dataType) => _cachedData.containsKey(dataType);
  
  /// Load data with smart caching and error handling
  Future<T?> loadData<T>(
    String dataType,
    Future<T> Function() loader, {
    bool forceRefresh = false,
    Duration? cacheExpiry,
  }) async {
    // Check if already loading
    if (isLoading(dataType)) {
      return getCachedData<T>(dataType);
    }
    
    // Check cache first (unless force refresh)
    if (!forceRefresh && hasCachedData(dataType)) {
      return getCachedData<T>(dataType);
    }
    
    // Set loading state
    _setLoadingState(dataType, true);
    _clearError(dataType);
    
    try {
      final data = await loader();
      _cachedData[dataType] = data;
      return data;
    } catch (e) {
      _setError(dataType, e.toString());
      
      // Return cached data if available and offline
      if (!_isOnline && hasCachedData(dataType)) {
        if (kDebugMode) print('Offline: Using cached data for $dataType');
        return getCachedData<T>(dataType);
      }
      
      return null;
    } finally {
      _setLoadingState(dataType, false);
    }
  }
  
  /// Load multiple data types in parallel
  Future<Map<String, dynamic>> loadMultipleData(
    Map<String, Future<dynamic> Function()> loaders, {
    bool forceRefresh = false,
  }) async {
    final futures = <String, Future<dynamic>>{};
    
    for (final entry in loaders.entries) {
      final dataType = entry.key;
      final loader = entry.value;
      
      // Check cache first
      if (!forceRefresh && hasCachedData(dataType)) {
        futures[dataType] = Future.value(getCachedData(dataType));
      } else {
        futures[dataType] = loadData(dataType, loader, forceRefresh: forceRefresh);
      }
    }
    
    final results = <String, dynamic>{};
    for (final entry in futures.entries) {
      try {
        results[entry.key] = await entry.value;
      } catch (e) {
        results[entry.key] = null;
      }
    }
    
    return results;
  }
  
  /// Refresh critical data when coming back online
  Future<void> _refreshCriticalData() async {
    if (kDebugMode) print('Refreshing critical data after reconnection');
    
    // Refresh user data, categories, and other critical data
    final criticalDataTypes = ['user', 'categories', 'companies'];
    
    for (final dataType in criticalDataTypes) {
      if (hasCachedData(dataType)) {
        // Trigger refresh in background
        loadData(dataType, () async {
          // This will be implemented based on your specific data loaders
          return null;
        }, forceRefresh: true);
      }
    }
  }
  
  /// Set loading state
  void _setLoadingState(String dataType, bool loading) {
    _loadingStates[dataType] = loading;
    notifyListeners();
  }
  
  /// Set error state
  void _setError(String dataType, String error) {
    _errorStates[dataType] = error;
    notifyListeners();
  }
  
  /// Clear error state
  void _clearError(String dataType) {
    _errorStates.remove(dataType);
    notifyListeners();
  }
  
  /// Clear all cached data
  Future<void> clearCache() async {
    _cachedData.clear();
    await PerformanceOptimizedApiService.clearCache();
    notifyListeners();
  }
  
  /// Clear specific cached data
  void clearCachedData(String dataType) {
    _cachedData.remove(dataType);
    PerformanceOptimizedApiService.clearCacheForKey(dataType);
    notifyListeners();
  }
  
  /// Get loading progress for multiple data types
  double getLoadingProgress(List<String> dataTypes) {
    if (dataTypes.isEmpty) return 1.0;
    
    final loadingCount = dataTypes.where((type) => isLoading(type)).length;
    return 1.0 - (loadingCount / dataTypes.length);
  }
  
  /// Check if any data is loading
  bool get isAnyLoading => _loadingStates.values.any((loading) => loading);
  
  /// Check if all specified data types are loaded
  bool areAllLoaded(List<String> dataTypes) {
    return dataTypes.every((type) => hasCachedData(type) && !isLoading(type));
  }
  
  /// Get online status
  bool get isOnline => _isOnline;
  
  @override
  void dispose() {
    PerformanceOptimizedApiService.dispose();
    super.dispose();
  }
}
