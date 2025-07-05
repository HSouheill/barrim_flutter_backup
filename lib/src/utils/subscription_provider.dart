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

  // State variables
  SubscriptionLoadingState _loadingState = SubscriptionLoadingState.idle;
  String? _errorMessage;

  // Subscription data
  List<SubscriptionPlan> _availablePlans = [];
  CurrentWholesalerSubscriptionData? _currentSubscription;
  SubscriptionRemainingTimeData? _remainingTimeData;

  // Request state
  bool _isRequestingSubscription = false;
  bool _isCancellingSubscription = false;

  // Getters
  SubscriptionLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  List<SubscriptionPlan> get availablePlans => _availablePlans;
  CurrentWholesalerSubscriptionData? get currentSubscription => _currentSubscription;
  SubscriptionRemainingTimeData? get remainingTimeData => _remainingTimeData;
  bool get isRequestingSubscription => _isRequestingSubscription;
  bool get isCancellingSubscription => _isCancellingSubscription;
  bool get isLoading => _loadingState == SubscriptionLoadingState.loading;
  bool get hasError => _loadingState == SubscriptionLoadingState.error;

  // Convenience getters
  bool get hasActiveSubscription => _remainingTimeData?.hasActiveSubscription ?? false;

  String get subscriptionStatus => _currentSubscription?.subscription?.status ?? 'none';

  SubscriptionPlan? get currentPlan => _currentSubscription?.plan;

  String? get formattedRemainingTime => _remainingTimeData?.remainingTime?.formatted;

  String? get subscriptionProgress => _remainingTimeData?.remainingTime?.percentageUsed;

  DateTime? get subscriptionEndDate => _remainingTimeData?.remainingTime?.endDate;

  bool get isExpiringSoon {
    final days = _remainingTimeData?.remainingTime?.days ?? 0;
    return hasActiveSubscription && days <= 7;
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

  void clearError() {
    _errorMessage = null;
    if (_loadingState == SubscriptionLoadingState.error) {
      _setLoadingState(SubscriptionLoadingState.idle);
    }
  }

  /// Initialize subscription data
  Future<void> initialize() async {
    try {
      _setLoadingState(SubscriptionLoadingState.loading);
      await refreshAllData();
      _setLoadingState(SubscriptionLoadingState.success);
    } catch (e) {
      _setError('Failed to initialize subscription data: $e');
    }
  }

  /// Refresh all subscription-related data
  Future<void> refreshAllData() async {
    try {
      final futures = await Future.wait([
        _subscriptionService.getAvailablePlans(),
        _subscriptionService.getCurrentWholesalerSubscription(),
        _subscriptionService.getWholesalerSubscriptionRemainingTime(),
      ]);

      _availablePlans = futures[0] as List<SubscriptionPlan>;
      _currentSubscription = futures[1] as CurrentWholesalerSubscriptionData?;
      _remainingTimeData = futures[2] as SubscriptionRemainingTimeData?;

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Load available subscription plans
  Future<void> loadAvailablePlans() async {
    try {
      _setLoadingState(SubscriptionLoadingState.loading);
      _availablePlans = await _subscriptionService.getAvailablePlans();
      _setLoadingState(SubscriptionLoadingState.success);
    } catch (e) {
      _setError('Failed to load subscription plans: $e');
    }
  }

  /// Load current subscription
  Future<void> loadCurrentSubscription() async {
    try {
      _setLoadingState(SubscriptionLoadingState.loading);
      _currentSubscription = await _subscriptionService.getCurrentWholesalerSubscription();
      _setLoadingState(SubscriptionLoadingState.success);
    } catch (e) {
      _setError('Failed to load current subscription: $e');
    }
  }

  /// Load remaining time data
  Future<void> loadRemainingTime() async {
    try {
      _remainingTimeData = await _subscriptionService.getWholesalerSubscriptionRemainingTime();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load remaining time: $e');
      }
    }
  }

  /// Request a new subscription
  Future<bool> requestSubscription({
    required String planId,
    File? paymentProofImage,
  }) async {
    try {
      _isRequestingSubscription = true;
      notifyListeners();

      await _subscriptionService.createWholesalerSubscription(
        planId: planId,
        imageFile: paymentProofImage,
      );

      // Refresh data after successful request
      await refreshAllData();

      _isRequestingSubscription = false;
      notifyListeners();

      return true;
    } catch (e) {
      _isRequestingSubscription = false;
      _setError('Failed to request subscription: $e');
      return false;
    }
  }

  /// Cancel current subscription
  Future<bool> cancelSubscription() async {
    try {
      _isCancellingSubscription = true;
      notifyListeners();

      final success = await _subscriptionService.cancelWholesalerSubscription();

      if (success) {
        await refreshAllData();
      }

      _isCancellingSubscription = false;
      notifyListeners();

      return success;
    } catch (e) {
      _isCancellingSubscription = false;
      _setError('Failed to cancel subscription: $e');
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
    return hasActiveSubscription &&
        _currentSubscription?.subscription?.planId == planId;
  }

  /// Get plans by type (if you have different types)
  List<SubscriptionPlan> getPlansByType(String type) {
    return _availablePlans.where((plan) => plan.type == type).toList();
  }

  /// Filter active plans only
  List<SubscriptionPlan> getActivePlans() {
    return _availablePlans.where((plan) => plan.isActive == true).toList();
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