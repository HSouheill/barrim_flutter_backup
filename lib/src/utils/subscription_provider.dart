// lib/providers/subscription_provider.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/wholesaler_subscription_service.dart';

enum SubscriptionLoadingState {
  idle,
  loading,
  success,
  error,
}

class SubscriptionProvider with ChangeNotifier {
  final WholesalerSubscriptionService _subscriptionService = WholesalerSubscriptionService();
  String? _branchId;

  // State variables
  SubscriptionLoadingState _loadingState = SubscriptionLoadingState.idle;
  String? _errorMessage;

  // Subscription data
  List<SubscriptionPlan> _availablePlans = [];
  SubscriptionRemainingTimeData? _remainingTimeData;

  // Request state
  bool _isRequestingSubscription = false;
  bool _isCancellingSubscription = false;

  // Getters
  SubscriptionLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  List<SubscriptionPlan> get availablePlans => _availablePlans;
  SubscriptionRemainingTimeData? get remainingTimeData => _remainingTimeData;
  bool get isRequestingSubscription => _isRequestingSubscription;
  bool get isCancellingSubscription => _isCancellingSubscription;
  bool get isLoading => _loadingState == SubscriptionLoadingState.loading;
  bool get hasError => _loadingState == SubscriptionLoadingState.error;
  String? get branchId => _branchId;

  // Setters
  void setBranchId(String branchId) {
    _branchId = branchId;
    notifyListeners();
  }

  // Convenience getters
  bool get hasActiveSubscription => _safeBoolConversion(_remainingTimeData?.hasActiveSubscription);

  String get subscriptionStatus => 'none'; // No current subscription data available

  SubscriptionPlan? get currentPlan => null; // No current subscription data available

  String? get formattedRemainingTime => _remainingTimeData?.remainingTime?.formatted;

  String? get subscriptionProgress => _remainingTimeData?.remainingTime?.percentageUsed;

  DateTime? get subscriptionEndDate => _remainingTimeData?.remainingTime?.endDate;

  bool get isExpiringSoon {
    final days = _remainingTimeData?.remainingTime?.days ?? 0;
    return hasActiveSubscription && days <= 7;
  }

  // Runtime error handling for UI rendering
  T _safeGetValue<T>(T Function() getter, T fallback, String context) {
    try {
      return getter();
    } catch (e) {
      print('SubscriptionProvider - Runtime error in $context: $e');
      _handleTypeConversionError(e, context);
      return fallback;
    }
  }

  // Safe UI getters with fallback values
  List<SubscriptionPlan> get uiAvailablePlans => _safeGetValue(
    () => _availablePlans,
    [],
    'getting available plans for UI'
  );

  bool get uiHasActiveSubscription => _safeGetValue(
    () => hasActiveSubscription,
    false,
    'getting hasActiveSubscription for UI'
  );

  String? get uiFormattedRemainingTime => _safeGetValue(
    () => formattedRemainingTime,
    null,
    'getting formattedRemainingTime for UI'
  );

  String? get uiSubscriptionProgress => _safeGetValue(
    () => subscriptionProgress,
    null,
    'getting subscriptionProgress for UI'
  );

  DateTime? get uiSubscriptionEndDate => _safeGetValue(
    () => subscriptionEndDate,
    null,
    'getting subscriptionEndDate for UI'
  );

  bool get uiIsExpiringSoon => _safeGetValue(
    () => isExpiringSoon,
    false,
    'getting isExpiringSoon for UI'
  );

  // Data validation and cleaning methods
  void _validateAndCleanData() {
    try {
      print('SubscriptionProvider - Validating and cleaning data...');
      
      // Validate plans data
      if (_availablePlans.isNotEmpty) {
        for (int i = 0; i < _availablePlans.length; i++) {
          final plan = _availablePlans[i];
          if (plan.isActive != null && plan.isActive is! bool) {
            print('SubscriptionProvider - Fixing plan $i isActive type: ${plan.isActive.runtimeType} -> bool');
            // Create a new plan with corrected data
            _availablePlans[i] = SubscriptionPlan(
              id: plan.id,
              title: plan.title,
              price: plan.price,
              duration: plan.duration,
              type: plan.type,
              benefits: plan.benefits,
              createdAt: plan.createdAt,
              updatedAt: plan.updatedAt,
              isActive: _safeBoolConversion(plan.isActive),
            );
          }
        }
      }
      
      // Validate remaining time data
      if (_remainingTimeData != null) {
        if (_remainingTimeData!.hasActiveSubscription != null && 
            _remainingTimeData!.hasActiveSubscription is! bool) {
          print('SubscriptionProvider - Fixing hasActiveSubscription type: ${_remainingTimeData!.hasActiveSubscription.runtimeType} -> bool');
          _remainingTimeData = SubscriptionRemainingTimeData(
            hasActiveSubscription: _safeBoolConversion(_remainingTimeData!.hasActiveSubscription),
            remainingTime: _remainingTimeData!.remainingTime,
          );
        }
      }
      
      print('SubscriptionProvider - Data validation and cleaning completed');
    } catch (e) {
      print('SubscriptionProvider - Error during data validation: $e');
      _handleTypeConversionError(e, 'data validation');
    }
  }

  // Safe data access methods to prevent runtime type errors
  List<SubscriptionPlan> get safeAvailablePlans {
    try {
      return _availablePlans;
    } catch (e) {
      print('SubscriptionProvider - Error accessing available plans: $e');
      _handleTypeConversionError(e, 'accessing available plans');
      return [];
    }
  }

  SubscriptionRemainingTimeData? get safeRemainingTimeData {
    try {
      return _remainingTimeData;
    } catch (e) {
      print('SubscriptionProvider - Error accessing remaining time data: $e');
      _handleTypeConversionError(e, 'accessing remaining time data');
      return null;
    }
  }

  // Safe convenience getters with error handling
  bool get safeHasActiveSubscription {
    try {
      return hasActiveSubscription;
    } catch (e) {
      print('SubscriptionProvider - Error getting hasActiveSubscription: $e');
      _handleTypeConversionError(e, 'getting hasActiveSubscription');
      return false;
    }
  }

  String? get safeFormattedRemainingTime {
    try {
      return formattedRemainingTime;
    } catch (e) {
      print('SubscriptionProvider - Error getting formattedRemainingTime: $e');
      _handleTypeConversionError(e, 'getting formattedRemainingTime');
      return null;
    }
  }

  String? get safeSubscriptionProgress {
    try {
      return subscriptionProgress;
    } catch (e) {
      print('SubscriptionProvider - Error getting subscriptionProgress: $e');
      _handleTypeConversionError(e, 'getting subscriptionProgress');
      return null;
    }
  }

  DateTime? get safeSubscriptionEndDate {
    try {
      return subscriptionEndDate;
    } catch (e) {
      print('SubscriptionProvider - Error getting subscriptionEndDate: $e');
      _handleTypeConversionError(e, 'getting subscriptionEndDate');
      return null;
    }
  }

  bool get safeIsExpiringSoon {
    try {
      return isExpiringSoon;
    } catch (e) {
      print('SubscriptionProvider - Error getting isExpiringSoon: $e');
      _handleTypeConversionError(e, 'getting isExpiringSoon');
      return false;
    }
  }

  // Helper method to safely convert boolean values
  bool _safeBoolConversion(dynamic value) {
    if (value == null) return false;
    
    if (value is bool) {
      return value;
    }
    
    if (value is String) {
      final str = value.toLowerCase();
      return str == 'true' || str == '1' || str == 'yes';
    }
    
    if (value is num) {
      return value != 0;
    }
    
    return false;
  }

  // Retry mechanism for data loading
  Future<void> retryDataLoading() async {
    try {
      print('SubscriptionProvider - Retrying data loading...');
      clearError();
      await refreshAllData();
    } catch (e) {
      print('SubscriptionProvider - Error during retry: $e');
      _handleTypeConversionError(e, 'retry data loading');
    }
  }

  // Enhanced clear error method
  void clearError() {
    _errorMessage = null;
    if (_loadingState == SubscriptionLoadingState.error) {
      _setLoadingState(SubscriptionLoadingState.idle);
    }
  }

  // Success response handling
  void _handleSubscriptionSuccess() {
    print('SubscriptionProvider - Handling subscription success');
    _setLoadingState(SubscriptionLoadingState.success);
    _errorMessage = null;
    notifyListeners();
  }

  // Enhanced error handler that provides better user feedback
  void _handleTypeConversionError(dynamic error, String context) {
    print('SubscriptionProvider - Type conversion error in $context: $error');
    print('SubscriptionProvider - Error type: ${error.runtimeType}');
    
    String userMessage;
    if (error.toString().contains("type 'String' is not a subtype of type 'bool'") ||
        error.toString().contains("type 'int' is not a subtype of type 'bool'") ||
        error.toString().contains("type 'double' is not a subtype of type 'bool'")) {
      userMessage = 'Data type mismatch in server response. Please try again or contact support.';
    } else {
      userMessage = 'An unexpected error occurred: $error';
    }
    
    _setError(userMessage);
    
    // Only reset state for critical errors, not for data refresh issues
    if (context.contains('plans casting') || context.contains('remaining time data casting')) {
      _resetOnError();
    }
  }

  // Reset provider state when errors occur
  void _resetOnError() {
    print('SubscriptionProvider - Resetting provider state due to error');
    _availablePlans = [];
    _remainingTimeData = null;
    _loadingState = SubscriptionLoadingState.error;
    notifyListeners();
  }

  // Methods
  void _setLoadingState(SubscriptionLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _setLoadingState(SubscriptionLoadingState.error);
  }

  /// Initialize subscription data
  Future<void> initialize() async {
    try {
      _setLoadingState(SubscriptionLoadingState.loading);
      await refreshAllData();
      _setLoadingState(SubscriptionLoadingState.success);
    } catch (e) {
      print('SubscriptionProvider - Error in initialize: $e');
      _handleTypeConversionError(e, 'initialize');
    }
  }

  /// Refresh all subscription-related data
  Future<void> refreshAllData() async {
    try {
      print('SubscriptionProvider - Starting refreshAllData...');
      
      print('SubscriptionProvider - Calling getAvailablePlans...');
      final plansFuture = _subscriptionService.getAvailablePlans();
      

      print('SubscriptionProvider - Calling getWholesalerSubscriptionRemainingTime...');
      if (_branchId == null) {
        throw Exception('Branch ID is required. Call setBranchId() first.');
      }
      final remainingTimeFuture = _subscriptionService.getWholesalerSubscriptionRemainingTime(_branchId!);
      
      final futures = await Future.wait([
        plansFuture,
        remainingTimeFuture,
      ]);

      print('SubscriptionProvider - All futures completed successfully');
      
      // Safely cast and handle type conversion issues
      try {
        print('SubscriptionProvider - Attempting to cast plans data...');
        print('SubscriptionProvider - Plans data type: ${futures[0].runtimeType}');
        print('SubscriptionProvider - Plans data: ${futures[0]}');
        
        _availablePlans = futures[0] as List<SubscriptionPlan>;
        print('SubscriptionProvider - Plans loaded successfully: ${_availablePlans.length}');
        
        // Log plan details for debugging
        for (int i = 0; i < _availablePlans.length; i++) {
          final plan = _availablePlans[i];
          print('Plan $i: ID=${plan.id}, Title=${plan.title}, isActive=${plan.isActive} (type: ${plan.isActive.runtimeType})');
        }
      } catch (e) {
        print('SubscriptionProvider - Error casting plans: $e');
        print('SubscriptionProvider - Plans error type: ${e.runtimeType}');
        print('SubscriptionProvider - Plans error details: ${e.toString()}');
        _handleTypeConversionError(e, 'plans casting');
        _availablePlans = [];
      }
      
      try {
        print('SubscriptionProvider - Attempting to cast remaining time data...');
        print('SubscriptionProvider - Remaining time data type: ${futures[1].runtimeType}');
        print('SubscriptionProvider - Remaining time data: ${futures[1]}');
        
        _remainingTimeData = futures[1] as SubscriptionRemainingTimeData?;
        print('SubscriptionProvider - Remaining time data loaded: ${_remainingTimeData != null ? "exists" : "null"}');
        if (_remainingTimeData != null) {
          print('hasActiveSubscription: ${_remainingTimeData!.hasActiveSubscription} (type: ${_remainingTimeData!.hasActiveSubscription.runtimeType})');
        }
      } catch (e) {
        print('SubscriptionProvider - Error casting remaining time data: $e');
        print('SubscriptionProvider - Remaining time error type: ${e.runtimeType}');
        print('SubscriptionProvider - Remaining time error details: ${e.toString()}');
        _handleTypeConversionError(e, 'remaining time data casting');
        _remainingTimeData = null;
      }

      print('SubscriptionProvider - Data loaded:');
      print('  - Available plans: ${_availablePlans.length}');
      print('  - Remaining time: ${_remainingTimeData != null ? "exists" : "null"}');

      // Validate and clean the data to prevent type conversion issues
      _validateAndCleanData();

      notifyListeners();
    } catch (e) {
      print('SubscriptionProvider - Error in refreshAllData: $e');
      _handleTypeConversionError(e, 'refreshAllData');
    }
  }

  /// Load available subscription plans
  Future<void> loadAvailablePlans() async {
    try {
      _setLoadingState(SubscriptionLoadingState.loading);
      _availablePlans = await _subscriptionService.getAvailablePlans();
      _setLoadingState(SubscriptionLoadingState.success);
    } catch (e) {
      print('SubscriptionProvider - Error in loadAvailablePlans: $e');
      _handleTypeConversionError(e, 'loadAvailablePlans');
    }
  }

  /// Load remaining time data
  Future<void> loadRemainingTime() async {
    try {
      if (_branchId == null) {
        throw Exception('Branch ID is required. Call setBranchId() first.');
      }
      _remainingTimeData = await _subscriptionService.getWholesalerSubscriptionRemainingTime(_branchId!);
      notifyListeners();
    } catch (e) {
      print('SubscriptionProvider - Error in loadRemainingTime: $e');
      _handleTypeConversionError(e, 'loadRemainingTime');
    }
  }

  /// Request a new subscription
  Future<bool> requestSubscription({
    required String planId,
    File? paymentProofImage,
  }) async {
    try {
      if (_branchId == null || _branchId!.isEmpty) {
        throw Exception('Branch ID is required. Please select a branch first.');
      }

      print('SubscriptionProvider - Requesting subscription for plan: $planId, branch: $_branchId');

      _isRequestingSubscription = true;
      notifyListeners();

      try {
        final result = await _subscriptionService.createWholesalerSubscription(
          planId: planId,
          branchId: _branchId!,
          imageFile: paymentProofImage,
        );

        print('SubscriptionProvider - Subscription request successful: ${result.toJson()}');
        print('SubscriptionProvider - Refreshing data...');

        // Try to refresh data, but don't fail if it doesn't work
        try {
          await refreshAllData();
          print('SubscriptionProvider - Data refresh successful');
        } catch (refreshError) {
          print('SubscriptionProvider - Data refresh failed, but subscription was successful: $refreshError');
          // Don't fail the subscription request if refresh fails
          // Just log the error and continue
        }

        _isRequestingSubscription = false;
        notifyListeners();

        return true;
      } catch (serviceError) {
        print('SubscriptionProvider - Service error: $serviceError');
        print('SubscriptionProvider - Service error type: ${serviceError.runtimeType}');
        
        // Check if it's a ConflictException (409 error)
        print('SubscriptionProvider - Checking for ConflictException in: ${serviceError.toString()}');
        if (serviceError.toString().contains('ConflictException') || 
            serviceError.toString().contains('Conflict')) {
          print('SubscriptionProvider - Detected ConflictException, setting error message');
          _isRequestingSubscription = false;
          _setError('A subscription request has already been sent for this branch. Please wait for approval.');
          return false;
        }
        
        // Check if it's a type conversion error
        if (serviceError.toString().contains("type 'String' is not a subtype of type 'bool'") ||
            serviceError.toString().contains("Data type mismatch")) {
          throw Exception('Data type mismatch in server response. Please try again or contact support.');
        }
        
        // Re-throw other service errors
        rethrow;
      }
    } catch (e) {
      print('SubscriptionProvider - Error in requestSubscription: $e');
      _isRequestingSubscription = false;
      
      // Handle specific type conversion errors
      String errorMessage = 'Failed to request subscription';
      if (e.toString().contains("type 'String' is not a subtype of type 'bool'") ||
          e.toString().contains("Data type mismatch")) {
        errorMessage = 'Failed to request subscription: Data type mismatch. Please try again or contact support.';
      } else {
        errorMessage = 'Failed to request subscription: $e';
      }
      
      _setError(errorMessage);
      return false;
    }
  }

  /// Cancel current subscription
  Future<bool> cancelSubscription() async {
    try {
      if (_branchId == null || _branchId!.isEmpty) {
        throw Exception('Branch ID is required. Please select a branch first.');
      }

      _isCancellingSubscription = true;
      notifyListeners();

      try {
        final success = await _subscriptionService.cancelWholesalerSubscription(_branchId!);

        if (success) {
          await refreshAllData();
        }

        _isCancellingSubscription = false;
        notifyListeners();

        return success;
      } catch (serviceError) {
        print('SubscriptionProvider - Service error in cancelSubscription: $serviceError');
        _handleTypeConversionError(serviceError, 'cancelSubscription service call');
        rethrow;
      }
    } catch (e) {
      print('SubscriptionProvider - Error in cancelSubscription: $e');
      _isCancellingSubscription = false;
      _handleTypeConversionError(e, 'cancelSubscription');
      return false;
    }
  }

  /// Get a specific plan by ID
  SubscriptionPlan? getPlanById(String planId) {
    try {
      return _availablePlans.firstWhere((plan) => plan.id == planId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a plan is currently subscribed
  bool isPlanActive(String planId) {
    return hasActiveSubscription; // Simplified since we no longer have current subscription details
  }

  /// Get plans by type (if you have different types)
  List<SubscriptionPlan> getPlansByType(String type) {
    return _availablePlans.where((plan) => plan.type == type).toList();
  }

  /// Filter active plans only
  List<SubscriptionPlan> getActivePlans() {
    return _availablePlans.where((plan) {
      // Handle different types of isActive values from backend
      if (plan.isActive == null) return false;
      
      // If it's already a boolean, use it directly
      if (plan.isActive is bool) {
        return plan.isActive as bool;
      }
      
      // If it's a string, convert it to boolean
      if (plan.isActive is String) {
        final isActiveStr = plan.isActive.toString().toLowerCase();
        return isActiveStr == 'true' || isActiveStr == '1' || isActiveStr == 'yes';
      }
      
      // If it's a number, treat 1 as true, 0 as false
      if (plan.isActive is num) {
        return (plan.isActive as num) != 0;
      }
      
      return false;
    }).toList();
  }

  /// Sort plans by price
  List<SubscriptionPlan> getPlansSortedByPrice({bool ascending = true}) {
    final sortedPlans = List<SubscriptionPlan>.from(_availablePlans);
    sortedPlans.sort((a, b) {
      final priceA = a.price ?? 0;
      final priceB = b.price ?? 0;
      return ascending ? priceA.compareTo(priceB) : priceB.compareTo(priceA);
    });
    return sortedPlans;
  }

  /// Sort plans by duration
  List<SubscriptionPlan> getPlansSortedByDuration({bool ascending = true}) {
    final sortedPlans = List<SubscriptionPlan>.from(_availablePlans);
    sortedPlans.sort((a, b) {
      final durationA = a.duration ?? 0;
      final durationB = b.duration ?? 0;
      return ascending ? durationA.compareTo(durationB) : durationB.compareTo(durationA);
    });
    return sortedPlans;
  }

  /// Dispose method
  @override
  void dispose() {
    super.dispose();
  }
}

// Extension for easy access to subscription provider
extension SubscriptionContext on BuildContext {
  SubscriptionProvider get subscriptionProvider =>
      Provider.of<SubscriptionProvider>(this, listen: false);

  SubscriptionProvider watchSubscriptionProvider() =>
      Provider.of<SubscriptionProvider>(this, listen: true);
}