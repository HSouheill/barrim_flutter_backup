import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../headers/service_provider_header.dart';
import '../../../headers/sidebar.dart';
import '../../../../../../src/services/service_provider_services.dart' as sp_services;
import '../../../../../../src/services/service_provider_subscription_service.dart';
import '../../../../../../src/services/sponsorship_service.dart';
import '../../../../../../src/models/service_provider.dart';
import '../../../../../../src/models/subscription.dart' as subscription_models;
import '../../../../../../src/models/sponsorship.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:async';

class ServiceproviderSubscription extends StatefulWidget {
  const ServiceproviderSubscription({Key? key}) : super(key: key);

  @override
  State<ServiceproviderSubscription> createState() => _ServiceproviderSubscriptionState();
}

class _ServiceproviderSubscriptionState extends State<ServiceproviderSubscription> with TickerProviderStateMixin, WidgetsBindingObserver {
  final sp_services.ServiceProviderService _serviceProviderService = sp_services
      .ServiceProviderService();
  final ServiceProviderSubscriptionService _subscriptionService = ServiceProviderSubscriptionService();
  bool _isSidebarOpen = false;
  bool _isLoading = true;
  List<subscription_models.SubscriptionPlan> _subscriptionPlans = [];
  dynamic _currentSubscription;
  String? _error;
  ServiceProvider? _serviceProvider;

  // Animation controller for circular progress
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  
  // New state variables for remaining time
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  AnimationController? _pulseAnimationController;
  Animation<double>? _pulseAnimation;
  subscription_models.SubscriptionRemainingTimeData? _remainingTimeData;
  
  // Countdown timer state
  String _currentTimeDisplay = '';
  DateTime? _subscriptionEndDate;
  
  // Payment status polling timer
  Timer? _paymentStatusPollTimer;
  String? _currentPaymentRequestId;
  int? _currentPaymentExternalId;
  
  // Sponsorship payment tracking
  String? _currentSponsorshipPaymentRequestId;

  
  // Sponsorship state
  List<Sponsorship> _sponsorships = [];
  bool _isLoadingSponsorships = false;
  String? _sponsorshipError;
  SponsorshipPagination? _sponsorshipPagination;
  String? _selectedSponsorshipId;
  bool _isSubmittingSponsorship = false;
  
  // Sponsorship subscription state (separate from regular subscription)
  SponsorshipSubscriptionTimeRemainingData? _sponsorshipSubscriptionData;
  Timer? _sponsorshipCountdownTimer;
  String _sponsorshipCurrentTimeDisplay = '';
  DateTime? _sponsorshipEndDate;
  
  // Subscription plan state
  bool _isSubmittingSubscription = false;

  @override
  void initState() {
    super.initState();
    
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize pulse animation controller
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController!,
      curve: Curves.easeInOut,
    ));
    
    // Start pulse animation
    _pulseAnimationController?.repeat(reverse: true);
    
    _fetchServiceProvider();
    _loadSubscriptionData();
    _loadSponsorships();
    _loadSponsorshipSubscriptionData();
    
    // Set up periodic refresh for subscription status
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _loadSubscriptionData();
      _loadSponsorshipSubscriptionData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _sponsorshipCountdownTimer?.cancel();
    _paymentStatusPollTimer?.cancel(); // Cancel payment polling timer
    _progressAnimationController.dispose();
    _pulseAnimationController?.dispose();
    
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Clear payment tracking
    _currentPaymentRequestId = null;
    _currentPaymentExternalId = null;
    _currentSponsorshipPaymentRequestId = null;
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // Pause the countdown timer when app is in background
        _stopCountdownTimer();
        _stopSponsorshipCountdownTimer();
        break;
      case AppLifecycleState.resumed:
        // Resume the countdown timer when app comes to foreground
        if (_remainingTimeData?.hasActiveSubscription == true) {
          _startCountdownTimer();
        }
        // Resume sponsorship countdown timer if active
        if (_sponsorshipSubscriptionData?.hasActiveSubscription == true) {
          _startSponsorshipCountdownTimer();
        }
        // Refresh subscription data when app resumes (e.g., after payment redirect)
        _loadSubscriptionData();
        _loadSponsorshipSubscriptionData();
        // Resume payment polling if it was active (after returning from payment)
        if (_currentPaymentRequestId != null) {
          // Restart polling if it was interrupted
          if (_paymentStatusPollTimer == null || !_paymentStatusPollTimer!.isActive) {
            _pollPaymentStatus(
              requestId: _currentPaymentRequestId,
              externalId: _currentPaymentExternalId,
            );
          }
        }
        // Resume sponsorship payment polling if it was active
        if (_currentSponsorshipPaymentRequestId != null) {
          if (_paymentStatusPollTimer == null || !_paymentStatusPollTimer!.isActive) {
            _pollSponsorshipPaymentStatus(
              requestId: _currentSponsorshipPaymentRequestId,
            );
          }
        }
        break;
      default:
        break;
    }
  }
  
  // Helper method to get current request ID (if available)
  String? _getCurrentRequestId() {
    return _currentPaymentRequestId;
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🟢 Service Provider Subscription Page: Loading subscription data...');
      final plansResponse = await ServiceProviderSubscriptionService
          .getSubscriptionPlans();
      print('🟢 Service Provider Subscription Page: Plans response success: ${plansResponse.success}');
      print('🟢 Service Provider Subscription Page: Plans response message: ${plansResponse.message}');
      print('🟢 Service Provider Subscription Page: Plans data length: ${plansResponse.data?.length ?? 0}');
      
      if (plansResponse.data != null) {
        print('🟢 Service Provider Subscription Page: Plans data: ${plansResponse.data!.map((p) => '${p.title} (${p.id})').join(', ')}');
      }
      
      final statusResponse = await ServiceProviderSubscriptionService
          .getSubscriptionStatus();
      print('Status response: success=${statusResponse.success}, message=${statusResponse.message}');
      
      final timeRemainingResponse = await ServiceProviderSubscriptionService
          .getSubscriptionTimeRemaining();
      print('Time remaining response: success=${timeRemainingResponse.success}, message=${timeRemainingResponse.message}');

      if (mounted) {
        setState(() {
          if (plansResponse.success && plansResponse.data != null) {
            _subscriptionPlans = plansResponse.data!;
            print('🟢 Service Provider Subscription Page: Loaded ${_subscriptionPlans.length} subscription plans');
            // Debug: Print each plan details
            for (var plan in _subscriptionPlans) {
              print('🟢 Plan: ${plan.title}, Type: ${plan.type}, Price: ${plan.price}, ID: ${plan.id}');
              print('🟢   Benefits: ${plan.benefitsText}');
            }
          } else {
            _error = plansResponse.message ?? 'Failed to load subscription plans';
            print('❌ Service Provider Subscription Page: Failed to load subscription plans: ${plansResponse.message}');
          }
          if (statusResponse.success) {
            _currentSubscription = statusResponse.data;
          }
          if (timeRemainingResponse.success && timeRemainingResponse.data != null) {
            // Parse the remaining time data to match the new structure
            // Parse inside setState to ensure state is updated
            final remainingTimeData = timeRemainingResponse.data!;
            final hasActiveSubscription = remainingTimeData['hasActiveSubscription'] ?? false;
            
            if (hasActiveSubscription && remainingTimeData['remainingTime'] != null) {
              final remainingTime = remainingTimeData['remainingTime'] as Map<String, dynamic>;
              
              _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
                hasActiveSubscription: hasActiveSubscription,
                remainingTime: subscription_models.SubscriptionRemainingTime(
                  days: remainingTime['days'],
                  hours: remainingTime['hours'],
                  minutes: remainingTime['minutes'],
                  formatted: remainingTime['formatted'],
                  percentageUsed: remainingTime['percentageUsed'],
                  endDate: remainingTime['endDate'] != null ? DateTime.parse(remainingTime['endDate']) : null,
                ),
              );
              
              // Start animation when time remaining is loaded
              _progressAnimationController.forward(from: 0.0);
              
              // Start countdown timer
              if (_remainingTimeData!.remainingTime?.endDate != null) {
                _setSubscriptionEndDate(_remainingTimeData!.remainingTime!.endDate);
              }
            } else {
              _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
                hasActiveSubscription: false,
                remainingTime: null,
              );
            }
          } else {
            print('🔵 No time remaining data or response not successful');
            _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
              hasActiveSubscription: false,
              remainingTime: null,
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSponsorshipSubscriptionData() async {
    try {
      // print('🟢 Loading sponsorship subscription data...');
      final response = await SponsorshipService.getServiceProviderSponsorshipTimeRemaining();
      
      print('🟢 Sponsorship subscription response: $response');
      print('🟢 Sponsorship subscription success: ${response['success']}');
      print('🟢 Sponsorship subscription status: ${response['status']}');
      print('🟢 Sponsorship subscription data: ${response['data']}');
      
      // Check for success field or status 200
      final isSuccess = response['success'] == true || 
                       (response['status'] != null && response['status'] >= 200 && response['status'] < 300);
      
      if (mounted && isSuccess) {
        final data = response['data'];
        if (data != null) {
          // Parse sponsorship subscription data
          _parseSponsorshipSubscriptionData(data);
          // print('🟢 Sponsorship subscription data parsed successfully');
        } else {
          // print('⚠️ Sponsorship subscription data is null');
        }
      } else {
        // print('⚠️ Sponsorship subscription response not successful: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // print('❌ Error loading sponsorship subscription data: $e');
    }
  }

  void _parseSponsorshipSubscriptionData(Map<String, dynamic> data) {
    try {
      // Debug logging for raw sponsorship data
      // print('=== RAW SPONSORSHIP SUBSCRIPTION DATA ===');
      // print('Raw data: $data');
      // print('hasActiveSubscription: ${data['hasActiveSubscription']}');
      // print('timeRemaining: ${data['timeRemaining']}');
      // print('subscription: ${data['subscription']}');
      // print('sponsorship: ${data['sponsorship']}');
      // print('entityInfo: ${data['entityInfo']}');
      // print('==========================================');
      
      final hasActiveSubscription = data['hasActiveSubscription'] ?? false;
      
      if (hasActiveSubscription && data['timeRemaining'] != null) {
        final timeRemaining = data['timeRemaining'] as Map<String, dynamic>;
        
        // Create sponsorship subscription remaining time data
        final remainingTime = SponsorshipSubscriptionTimeRemaining(
          days: timeRemaining['days'] ?? 0,
          hours: timeRemaining['hours'] ?? 0,
          minutes: timeRemaining['minutes'] ?? 0,
          seconds: timeRemaining['seconds'] ?? 0,
          formatted: timeRemaining['formatted'] ?? '',
          percentageUsed: timeRemaining['percentageUsed'] ?? '0%',
          startDate: timeRemaining['startDate'] != null ? DateTime.parse(timeRemaining['startDate']) : null,
          endDate: timeRemaining['endDate'] != null ? DateTime.parse(timeRemaining['endDate']) : null,
        );
        
        // Update state with sponsorship subscription data (separate from regular subscription)
        setState(() {
          _sponsorshipSubscriptionData = SponsorshipSubscriptionTimeRemainingData(
            hasActiveSubscription: hasActiveSubscription,
            timeRemaining: remainingTime,
            subscription: data['subscription'] != null ? SponsorshipSubscription.fromJson(data['subscription']) : null,
            sponsorship: data['sponsorship'] != null ? Sponsorship.fromJson(data['sponsorship']) : null,
            entityInfo: data['entityInfo'] != null ? SponsorshipSubscriptionEntityInfo.fromJson(data['entityInfo']) : null,
            message: data['message'],
          );
        });
        
        // Start countdown timer if we have active sponsorship
        if (hasActiveSubscription && remainingTime.endDate != null) {
          _setSponsorshipEndDate(remainingTime.endDate);
        } else {
          _stopSponsorshipCountdownTimer();
        }
      } else {
        // No active sponsorship subscription
        setState(() {
          _sponsorshipSubscriptionData = SponsorshipSubscriptionTimeRemainingData(
            hasActiveSubscription: false,
            timeRemaining: null,
            subscription: null,
            sponsorship: null,
            entityInfo: null,
            message: data['message'],
          );
        });
        _stopSponsorshipCountdownTimer();
      }
    } catch (e) {
      print('Error parsing sponsorship subscription data: $e');
      setState(() {
        _sponsorshipSubscriptionData = SponsorshipSubscriptionTimeRemainingData(
          hasActiveSubscription: false,
          timeRemaining: null,
          subscription: null,
          sponsorship: null,
          entityInfo: null,
          message: null,
        );
      });
      _stopSponsorshipCountdownTimer();
    }
  }

  void _parseRemainingTimeData(Map<String, dynamic> data) {
    try {
      print('🔵 Parsing remaining time data: $data');
      final hasActiveSubscription = data['hasActiveSubscription'] ?? false;
      print('🔵 hasActiveSubscription: $hasActiveSubscription');
      
      if (hasActiveSubscription && data['remainingTime'] != null) {
        final remainingTime = data['remainingTime'] as Map<String, dynamic>;
        print('🔵 remainingTime data: $remainingTime');
        
        final remainingTimeData = subscription_models.SubscriptionRemainingTime(
          days: remainingTime['days'],
          hours: remainingTime['hours'],
          minutes: remainingTime['minutes'],
          formatted: remainingTime['formatted'],
          percentageUsed: remainingTime['percentageUsed'],
          endDate: remainingTime['endDate'] != null ? DateTime.parse(remainingTime['endDate']) : null,
        );
        
        print('🔵 Created remainingTimeData: days=${remainingTimeData.days}, hours=${remainingTimeData.hours}, formatted=${remainingTimeData.formatted}');
        
        // Use setState to ensure proper state update
        setState(() {
          _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
            hasActiveSubscription: hasActiveSubscription,
            remainingTime: remainingTimeData,
          );
        });
        
        print('🔵 Set _remainingTimeData: $_remainingTimeData');
        
        // Start countdown timer if we have remaining time data
        if (hasActiveSubscription) {
          _startCountdownTimer();
          // Set subscription end date for countdown timer
          if (remainingTimeData.endDate != null) {
            _setSubscriptionEndDate(remainingTimeData.endDate);
          }
        } else {
          _stopCountdownTimer();
        }
      } else {
        print('🔵 No active subscription or remainingTime is null');
        setState(() {
          _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
            hasActiveSubscription: false,
            remainingTime: null,
          );
        });
        _stopCountdownTimer();
      }
    } catch (e) {
      print('❌ Error parsing remaining time data: $e');
      setState(() {
        _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
          hasActiveSubscription: false,
          remainingTime: null,
        );
      });
      _stopCountdownTimer();
    }
  }

  void _startCountdownTimer() {
    // Cancel existing timer if any
    _countdownTimer?.cancel();
    
    // Start new countdown timer that updates every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTimeData?.remainingTime != null && mounted) {
        // Update the remaining time data with current time
        _updateRemainingTime();
      } else {
        // Stop timer if no remaining time data or widget is disposed
        timer.cancel();
      }
    });
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
  }

  void _updateRemainingTime() {
    if (_remainingTimeData?.remainingTime == null) return;
    
    final remaining = _remainingTimeData!.remainingTime!;
    final endDate = remaining.endDate;
    
    if (endDate != null) {
      final now = DateTime.now();
      final difference = endDate.difference(now);
      
      if (difference.isNegative) {
        // Subscription has expired
        _stopCountdownTimer();
        return;
      }
      
      // Calculate the remaining time values
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;
      
      // Create formatted string similar to the screenshot (1M:12D:1H format)
      String formatted = '';
      if (days >= 30) {
        final months = days ~/ 30;
        final remainingDays = days % 30;
        if (months > 0) {
          formatted += '${months}M:';
        }
        if (remainingDays > 0) {
          formatted += '${remainingDays}D:';
        }
      } else if (days > 0) {
        formatted += '${days}D:';
      }
      if (hours > 0) {
        formatted += '${hours}H';
      } else if (formatted.isEmpty) {
        // If no days or hours, show minutes only
        formatted += '${minutes}M';
      }
      
      // Update countdown display with seconds
      String timeDisplay = '';
      if (days > 0) {
        timeDisplay += '${days}d ';
      }
      if (hours > 0 || days > 0) {
        timeDisplay += '${hours.toString().padLeft(2, '0')}h ';
      }
      if (minutes > 0 || hours > 0 || days > 0) {
        timeDisplay += '${minutes.toString().padLeft(2, '0')}m ';
      }
      timeDisplay += '${seconds.toString().padLeft(2, '0')}s';
      
      setState(() {
        _currentTimeDisplay = timeDisplay.trim();
      });
      
      // Calculate percentage used
      final totalDuration = _currentSubscription?.plan?.duration ?? 30;
      final usedDays = totalDuration - days;
      final percentageUsed = ((usedDays / totalDuration) * 100).clamp(0, 100);
      
      // Create new remaining time instance with updated values
      final updatedRemainingTime = subscription_models.SubscriptionRemainingTime(
        days: days,
        hours: hours,
        minutes: minutes,
        formatted: formatted,
        percentageUsed: '${percentageUsed.toStringAsFixed(1)}%',
        endDate: endDate,
      );
      
      // Update the remaining time data
      setState(() {
        _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
          hasActiveSubscription: _remainingTimeData!.hasActiveSubscription,
          remainingTime: updatedRemainingTime,
        );
      });
    }
  }

  void _setSubscriptionEndDate(DateTime? endDate) {
    _subscriptionEndDate = endDate;
    if (endDate != null) {
      _startCountdownTimer();
    } else {
      _stopCountdownTimer();
    }
  }

  // Sponsorship subscription countdown timer methods
  void _startSponsorshipCountdownTimer() {
    // Cancel existing timer if any
    _sponsorshipCountdownTimer?.cancel();
    
    // Start new countdown timer that updates every second
    _sponsorshipCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sponsorshipSubscriptionData?.timeRemaining != null && mounted) {
        // Update the remaining time data with current time
        _updateSponsorshipRemainingTime();
      } else {
        // Stop timer if no remaining time data or widget is disposed
        timer.cancel();
      }
    });
  }

  void _stopSponsorshipCountdownTimer() {
    _sponsorshipCountdownTimer?.cancel();
  }

  void _updateSponsorshipRemainingTime() {
    if (_sponsorshipSubscriptionData?.timeRemaining == null) return;
    
    final remaining = _sponsorshipSubscriptionData!.timeRemaining!;
    final endDate = remaining.endDate;
    
    if (endDate != null) {
      final now = DateTime.now();
      final difference = endDate.difference(now);
      
      if (difference.isNegative) {
        // Sponsorship subscription has expired
        _stopSponsorshipCountdownTimer();
        return;
      }
      
      // Calculate the remaining time values
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;
      
      // Create formatted string similar to the screenshot (1M:12D:1H format)
      String formatted = '';
      if (days >= 30) {
        final months = days ~/ 30;
        final remainingDays = days % 30;
        if (months > 0) {
          formatted += '${months}M:';
        }
        if (remainingDays > 0) {
          formatted += '${remainingDays}D:';
        }
      } else if (days > 0) {
        formatted += '${days}D:';
      }
      if (hours > 0) {
        formatted += '${hours}H';
      } else if (formatted.isEmpty) {
        // If no days or hours, show minutes only
        formatted += '${minutes}M';
      }
      
      // Update countdown display with seconds
      String timeDisplay = '';
      if (days > 0) {
        timeDisplay += '${days}d ';
      }
      if (hours > 0 || days > 0) {
        timeDisplay += '${hours.toString().padLeft(2, '0')}h ';
      }
      if (minutes > 0 || hours > 0 || days > 0) {
        timeDisplay += '${minutes.toString().padLeft(2, '0')}m ';
      }
      timeDisplay += '${seconds.toString().padLeft(2, '0')}s';
      
      setState(() {
        _sponsorshipCurrentTimeDisplay = timeDisplay.trim();
      });
      
      // Calculate percentage used
      final totalDuration = _sponsorshipSubscriptionData?.subscription?.startDate != null && 
                          _sponsorshipSubscriptionData?.subscription?.endDate != null
          ? _sponsorshipSubscriptionData!.subscription!.endDate!.difference(
              _sponsorshipSubscriptionData!.subscription!.startDate!
            ).inDays
          : (_sponsorshipSubscriptionData?.sponsorship?.duration ?? 30); // Fallback to sponsorship duration
      final usedDays = totalDuration - days;
      final percentageUsed = ((usedDays / totalDuration) * 100).clamp(0, 100);
      
      // Create new remaining time instance with updated values
      final updatedRemainingTime = SponsorshipSubscriptionTimeRemaining(
        days: days,
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        formatted: formatted,
        percentageUsed: '${percentageUsed.toStringAsFixed(1)}%',
        startDate: remaining.startDate,
        endDate: endDate,
      );
      
      // Update the sponsorship subscription data
      setState(() {
        _sponsorshipSubscriptionData = SponsorshipSubscriptionTimeRemainingData(
          hasActiveSubscription: _sponsorshipSubscriptionData!.hasActiveSubscription,
          timeRemaining: updatedRemainingTime,
          subscription: _sponsorshipSubscriptionData!.subscription,
          sponsorship: _sponsorshipSubscriptionData!.sponsorship,
          entityInfo: _sponsorshipSubscriptionData!.entityInfo,
          message: _sponsorshipSubscriptionData!.message,
        );
      });
    }
  }

  void _setSponsorshipEndDate(DateTime? endDate) {
    _sponsorshipEndDate = endDate;
    if (endDate != null) {
      _startSponsorshipCountdownTimer();
    } else {
      _stopSponsorshipCountdownTimer();
    }
  }

  Future<void> _loadSponsorships() async {
    setState(() {
      _isLoadingSponsorships = true;
      _sponsorshipError = null;
    });

    try {
      final response = await SponsorshipService.getServiceProviderSponsorships(
        page: 1,
        limit: 20,
      );

      if (mounted) {
        // Debug: Print raw API response
        print('=== SPONSORSHIPS API RESPONSE ===');
        print('Raw response: $response');
        print('Success: ${response['success']}');
        print('Message: ${response['message']}');
        print('Data length: ${response['data']?.length ?? 0}');
        print('Pagination: ${response['pagination']}');
        print('================================');
        
        final sponsorships = SponsorshipService.parseSponsorships(response);
        setState(() {
          _sponsorships = sponsorships;
          _sponsorshipPagination = SponsorshipService.parsePagination(response);
          _sponsorshipError = response['success'] == true ? null : response['message'];
          _isLoadingSponsorships = false;
        });
        
        // Debug: Print detailed sponsorship information
        print('=== PARSED SPONSORSHIPS ===');
        print('Total sponsorships loaded: ${sponsorships.length}');
        print('Pagination info: $_sponsorshipPagination');
        
        for (var i = 0; i < sponsorships.length; i++) {
          final sponsorship = sponsorships[i];
          print('--- Sponsorship $i ---');
          print('  ID: ${sponsorship.id}');
          print('  Title: ${sponsorship.title}');
          print('  Price: ${sponsorship.price}');
          print('  Duration: ${sponsorship.duration} days');
          print('  Discount: ${sponsorship.discount}');
          print('  Start Date: ${sponsorship.startDate}');
          print('  End Date: ${sponsorship.endDate}');
          print('  Created By: ${sponsorship.createdBy}');
          print('  Created At: ${sponsorship.createdAt}');
          print('  Updated At: ${sponsorship.updatedAt}');
          print('  ID Length: ${sponsorship.id?.length ?? 0}');
          print('  Is Valid ObjectID: ${sponsorship.id?.length == 24 ? "Yes" : "No"}');
        }
        print('============================');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sponsorshipError = 'Failed to load sponsorships: ${e.toString()}';
          _isLoadingSponsorships = false;
        });
      }
    }
  }

  Future<void> _fetchServiceProvider() async {
    try {
      final provider = await _serviceProviderService.getServiceProviderData();
      if (mounted) {
        setState(() {
          _serviceProvider = provider;
        });
        // Debug: Print service provider ID
        print('ServiceProvider ID: ${provider.id}');
        print('ServiceProvider ID length: ${provider.id.length}');
      }
    } catch (e) {
      // Optionally handle error
      print('Error fetching service provider: $e');
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _closeSidebar() {
    setState(() {
      _isSidebarOpen = false;
    });
  }
  

  

  
  Future<void> _submitSubscriptionRequestDirectly(subscription_models.SubscriptionPlan plan) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 20),
                const Text(
                  'Checking balance...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Check Whish account balance before creating subscription
      final balanceResponse = await ServiceProviderSubscriptionService.checkWhishAccountBalance();
      
      // Update loading dialog message
      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      'Initiating payment...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
      
      if (balanceResponse.success && balanceResponse.data != null) {
        final balance = balanceResponse.data!;
        final subscriptionPrice = plan.price ?? 0;
        
        // Check if balance is sufficient
        if (balance < subscriptionPrice) {
          // Close loading dialog
          if (mounted) {
            Navigator.of(context).pop();
          }
          
          // Show insufficient funds error
          _showInsufficientFundsDialog(
            balance: balance,
            requiredAmount: subscriptionPrice,
            planTitle: plan.title ?? 'Unknown Plan',
          );
          return;
        }
      } else {
        // If balance check fails, log warning but continue with payment
        // (balance check might not be critical in all cases)
        print('⚠️ Warning: Could not verify account balance: ${balanceResponse.message}');
      }
      
      final response = await ServiceProviderSubscriptionService.createSubscriptionRequest(
        planId: plan.id!,
        // paymentProofImage: null, // Optional: Add file picker for payment proof
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (response.success && response.data != null) {
        final subscriptionRequest = response.data!;
        
        // Check if we have a collectUrl for Whish payment
        if (subscriptionRequest.collectUrl != null && subscriptionRequest.collectUrl!.isNotEmpty) {
          // Show payment dialog with Whish payment URL
          _showWhishPaymentDialog(
            collectUrl: subscriptionRequest.collectUrl!,
            planTitle: plan.title ?? 'Unknown Plan',
            planPrice: '\$${plan.price?.toStringAsFixed(2) ?? '0.00'}',
            requestId: subscriptionRequest.id,
            externalId: subscriptionRequest.externalId,
          );
        } else {
          // Fallback to old success dialog (in case backend doesn't return collectUrl)
          _showSuccessDialog();
        }
      } else {
        // Handle specific error cases
        if (mounted) {
          // Check if it's a 409 Conflict error (pending subscription request)
          if (response.statusCode == 409) {
            _showExistingSubscriptionDialog();
          } else {
            // Show error message for other errors
            final errorMessage = response.message ?? 'Failed to submit subscription request';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send subscription request: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmittingSubscription = false;
      });
    }
  }
  
  LinearGradient _getPlanGradient(String planType) {
    switch (planType) {
      case 'monthly':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A), // Dark blue
            Color(0xFF3B82F6), // Medium blue
          ],
        );
      case 'sixMonths':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E40AF), // Dark blue
            Color(0xFF2563EB), // Medium blue
          ],
        );
      case 'yearly':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Very dark blue/black
            Color(0xFF1E293B), // Dark blue
          ],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2079C2),
            Color(0xFF3B82F6),
          ],
        );
    }
  }
  
  void _showSubscriptionSelectionDialog(subscription_models.SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.card_membership,
                color: const Color(0xFF2079C2),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Select ${plan.title}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have selected the ${plan.title} subscription plan.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Price: \$${plan.price?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2079C2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Duration: ${plan.duration ?? 0} days',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Benefits:',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...plan.benefitsText.split('\n')
                  .where((b) => b.isNotEmpty)
                  .map((benefit) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.grey)),
                            Expanded(child: Text(benefit)),
                          ],
                        ),
                      ))
                  .toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${plan.title} plan selected!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2079C2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Select Plan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          Column(
            children: [
              ServiceProviderHeader(
                serviceProvider: _serviceProvider,
                isLoading: _isLoading,
                onLogoNavigation: () {
                  // Navigate back to the previous screen
                  Navigator.of(context).pop();
                },
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading subscriptions',
                        style: TextStyle(color: Colors.red),
                      ),
                      TextButton(
                        onPressed: _loadSubscriptionData,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
                    : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSectionTitle('Service Provider Subscriptions'),
                          ),
                         
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Current subscription status with circular progress
                      // if (_currentSubscription != null)
                      //   _buildCurrentSubscriptionStatus(),

                      // const SizedBox(height: 24),

                      // Subscription plans grid
                      if (_subscriptionPlans.isNotEmpty)
                        _buildSubscriptionPlansGrid()
                      else if (_error != null)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading subscription plans',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadSubscriptionData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2079C2),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Loading subscription plans...',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 40),

                      // Time Remaining Section
                      _buildRemainingTimeWidget(),

                      const SizedBox(height: 40),

                      // Sponsorship Subscription Status Section
                      _buildSponsorshipSubscriptionWidget(),

                      const SizedBox(height: 40),

                      // Sponsorship Section
                      _buildSponsorshipSection(),

                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sidebar overlay
          if (_isSidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Stack(
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Sidebar(
                        onCollapse: _closeSidebar,
                        parentContext: context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  

    Widget _buildCircularTimeProgress(int remainingDays) {
    // Get total days from current subscription plan
    final int totalDays = _currentSubscription?.plan?.duration ?? 30; // Fallback to 30 if no plan
    final double progress = remainingDays / totalDays;
    final String timeText = _formatTimeRemaining(remainingDays);

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          child: Stack(
            children: [
              // Background circle
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade200),
                ),
              ),
              // Progress circle
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress * _progressAnimation.value,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(progress),
                  ),
                ),
              ),
              // Center text
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getProgressColor(progress),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   'Time Left',
                      //   style: TextStyle(
                      //     fontSize: 12,
                      //     color: Colors.grey.shade600,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeRemaining(int remainingDays) {
    if (remainingDays >= 30) {
      final months = remainingDays ~/ 30;
      final days = remainingDays % 30;
      return '${months}M:${days}D';
    } else if (remainingDays >= 1) {
      return '${remainingDays}D';
    } else {
      return '< 1D';
    }
  }

  Color _getProgressColor(double progress) {
    if (progress > 0.5) {
      return const Color(0xFF0094FF); // Blue for healthy time remaining
    } else if (progress > 0.2) {
      return Colors.orange; // Orange for moderate time remaining
    } else {
      return Colors.red; // Red for low time remaining
    }
  }

  Widget _buildSubscriptionPlansGrid() {
    // print('Building subscription plans grid with ${_subscriptionPlans.length} plans');
    // print('Plans: ${_subscriptionPlans.map((p) => '${p.title} (${p.id})').join(', ')}');
    
    if (_subscriptionPlans.isEmpty) {
      return const Center(
        child: Text('No subscription plans available'),
      );
    }

    // If there's only one plan, display it full width
    if (_subscriptionPlans.length == 1) {
      return _buildSubscriptionCard(
        _subscriptionPlans.first,
        _getPlanType(_subscriptionPlans.first),
        isFullWidth: true,
      );
    }

    // Group plans by title or type (monthly, 6 months, yearly)
    final monthlyPlans = _subscriptionPlans.where((p) {
      final title = p.title?.toLowerCase() ?? '';
      final type = p.type?.toLowerCase() ?? '';
      return title.contains('monthly') || type.contains('monthly');
    }).toList();
    
    final sixMonthPlans = _subscriptionPlans.where((p) {
      final title = p.title?.toLowerCase() ?? '';
      final type = p.type?.toLowerCase() ?? '';
      return title.contains('6') || 
             title.contains('six') || 
             type.contains('6') ||
             type.contains('six');
    }).toList();
    
    final yearlyPlans = _subscriptionPlans.where((p) {
      final title = p.title?.toLowerCase() ?? '';
      final type = p.type?.toLowerCase() ?? '';
      return title.contains('yearly') || 
             title.contains('annual') ||
             type.contains('yearly') ||
             type.contains('annual');
    }).toList();
    
    // Get all plans that don't match any category
    final otherPlans = _subscriptionPlans.where((p) {
      return !monthlyPlans.contains(p) && 
             !sixMonthPlans.contains(p) && 
             !yearlyPlans.contains(p);
    }).toList();
    
    // print('Filtered plans - Monthly: ${monthlyPlans.length}, 6 Months: ${sixMonthPlans.length}, Yearly: ${yearlyPlans.length}, Other: ${otherPlans.length}');

    return Column(
      children: [
        // Monthly and 6-month plans row (top row)
        if (monthlyPlans.isNotEmpty || sixMonthPlans.isNotEmpty)
          Row(
            children: [
              if (monthlyPlans.isNotEmpty)
                Expanded(
                  child: _buildSubscriptionCard(
                    monthlyPlans.first,
                    'monthly',
                  ),
                ),
              if (monthlyPlans.isNotEmpty && sixMonthPlans.isNotEmpty)
                const SizedBox(width: 16),
              if (sixMonthPlans.isNotEmpty)
                Expanded(
                  child: _buildSubscriptionCard(
                    sixMonthPlans.first,
                    'sixMonths',
                  ),
                ),
            ],
          ),

        if (monthlyPlans.isNotEmpty || sixMonthPlans.isNotEmpty)
          const SizedBox(height: 20),

        // Yearly plan (bottom center)
        if (yearlyPlans.isNotEmpty)
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.6, // 60% of screen width
              child: _buildSubscriptionCard(
                yearlyPlans.first,
                'yearly',
                isFullWidth: true,
              ),
            ),
          ),

        if (yearlyPlans.isNotEmpty && otherPlans.isNotEmpty)
          const SizedBox(height: 20),

        // Display other plans that don't match the standard categories
        if (otherPlans.isNotEmpty)
          ...otherPlans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildSubscriptionCard(
                  plan,
                  _getPlanType(plan),
                  isFullWidth: true,
                ),
              )).toList(),

        // Fallback: If no plans matched any category, display all plans in a grid
        if (monthlyPlans.isEmpty && sixMonthPlans.isEmpty && yearlyPlans.isEmpty && otherPlans.isEmpty && _subscriptionPlans.isNotEmpty)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: _subscriptionPlans.map((plan) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.45,
                child: _buildSubscriptionCard(
                  plan,
                  _getPlanType(plan),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _getPlanType(subscription_models.SubscriptionPlan plan) {
    final title = plan.title?.toLowerCase() ?? '';
    final type = plan.type?.toLowerCase() ?? '';
    
    if (title.contains('monthly') || type.contains('monthly')) {
      return 'monthly';
    } else if (title.contains('6') || title.contains('six') || type.contains('6') || type.contains('six')) {
      return 'sixMonths';
    } else if (title.contains('yearly') || title.contains('annual') || type.contains('yearly') || type.contains('annual')) {
      return 'yearly';
    } else {
      return 'default';
    }
  }

  Widget _buildSubscriptionCard(subscription_models.SubscriptionPlan plan,
      String planType, {
        bool isFullWidth = false,
      }) {
    final benefits = plan.benefitsText.split('\n')
        .where((b) => b.isNotEmpty)
        .toList();

    return Container(
      width: isFullWidth ? double.infinity : null,
      constraints: isFullWidth ? null : const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        gradient: _getPlanGradient(planType),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                _getSubscriptionImage(plan.title ?? ''),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Container(
                    color: Colors.grey.withOpacity(0.1),
                    child: const Center(
                      child: Icon(
                        Icons.card_membership,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Decorative elements based on plan type
            if (planType == 'monthly')
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            if (planType == 'sixMonths')
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 80,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            if (planType == 'yearly')
              Positioned(
                top: 15,
                left: 15,
                child: Container(
                  width: 100,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            if (planType == 'yearly')
              Positioned(
                bottom: 30,
                right: 20,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (planType == 'yearly')
              Positioned(
                bottom: 50,
                right: 40,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Dark overlay for better text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    plan.title ?? 'Unknown Plan',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Benefits list
                  ...benefits.map((benefit) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(
                                color: Colors.white, fontSize: 16)),
                            Expanded(
                              child: Text(
                                benefit,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),

                  const SizedBox(height: 20),

                                        // Join button
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _submitSubscriptionRequestDirectly(plan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2079C2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Join for only \$${plan.price?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),


                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2079C2),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingTimeWidget() {
    // print('🔵 Building remaining time widget - _remainingTimeData: $_remainingTimeData');
    // print('🔵 hasActiveSubscription: ${_remainingTimeData?.hasActiveSubscription}');
    
    if (_remainingTimeData == null || _remainingTimeData!.hasActiveSubscription != true) {
      print('🔵 Skipping regular subscription widget - no active subscription');
      return const SizedBox.shrink();
    }
    
    final remaining = _remainingTimeData!.remainingTime;
    if (remaining == null) return const SizedBox.shrink();
    
    final percentUsed = double.tryParse((remaining.percentageUsed ?? '0').replaceAll('%', '')) ?? 0;
    final percentLeft = 1 - (percentUsed / 100);
    
    return Container(
      child: Column(
        children: [
          // Section title - clearly labeled as subscription plan
          _buildSectionTitle('Subscription Plan Time Left'),
          const SizedBox(height: 24),
          
          // Main time remaining widget
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Circular progress indicator with time
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade200),
                        ),
                      ),
                      // Progress circle
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: percentLeft * _progressAnimation.value,
                          strokeWidth: 12,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(percentLeft),
                          ),
                        ),
                      ),
                      // Center time display
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentTimeDisplay.isNotEmpty 
                                ? _currentTimeDisplay 
                                : (remaining.formatted ?? '0D:0H'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              color: Color(0xFF2079C2),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorshipSubscriptionWidget() {
        // print('🟢 Building sponsorship subscription widget - _sponsorshipSubscriptionData: $_sponsorshipSubscriptionData');
        // print('🟢 hasActiveSubscription: ${_sponsorshipSubscriptionData?.hasActiveSubscription}');
        
    // Check if there's active sponsorship subscription data
    if (_sponsorshipSubscriptionData == null || !_sponsorshipSubscriptionData!.hasActiveSubscription) {
      // print('🟢 Skipping sponsorship subscription widget - no active sponsorship');
      return const SizedBox.shrink();
    }
    
    return Container(
      child: Column(
        children: [
          // Section title
          _buildSectionTitle('Sponsorship Subscription'),
          const SizedBox(height: 24),
          
          // Sponsorship subscription content
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildActiveSponsorshipStatus(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSponsorshipStatus() {
    final remaining = _sponsorshipSubscriptionData?.timeRemaining;
    
    // Debug logging for sponsorship data
    // print('=== SPONSORSHIP DATA DEBUG ===');
    // print('_sponsorshipSubscriptionData: $_sponsorshipSubscriptionData');
    // print('remaining: $remaining');
    // if (remaining != null) {
    //   print('remaining.days: ${remaining.days}');
    //   print('remaining.hours: ${remaining.hours}');
    //   print('remaining.minutes: ${remaining.minutes}');
    //   print('remaining.formatted: ${remaining.formatted}');
    //   print('remaining.percentageUsed: ${remaining.percentageUsed}');
    //   print('remaining.endDate: ${remaining.endDate}');
    // }
    // print('==============================');
    
    if (remaining == null) return const SizedBox.shrink();

    final percentUsed = double.tryParse((remaining.percentageUsed ?? '0').replaceAll('%', '')) ?? 0;
    final percentLeft = 1 - (percentUsed / 100);
    
    return Column(
      children: [
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Active Sponsorship',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        
        // Time remaining display with countdown
        Text(
          _sponsorshipCurrentTimeDisplay.isNotEmpty 
              ? _sponsorshipCurrentTimeDisplay 
              : (remaining.formatted ?? '0D:0H'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 32,
            color: Color(0xFF2079C2),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Time Remaining',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        SizedBox(height: 20),
        
        // Progress bar
        LinearProgressIndicator(
          value: percentLeft,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          minHeight: 8,
        ),
        SizedBox(height: 8),
        Text(
          '${percentUsed.toStringAsFixed(1)}% used',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }


  Widget _buildSponsorshipSection() {
    return Column(
      children: [
        _buildSectionTitle('Sponsorship'),
        const SizedBox(height: 24),
        
                
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sponsor as a Worker',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2079C2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Boost your visibility with sponsorship options tailored for workers. Choose your duration, set your budget, and enjoy the flexibility to pause or resume anytime!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Dynamic sponsorships from API
              if (_isLoadingSponsorships)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_sponsorshipError != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          'Error loading sponsorships',
                          style: TextStyle(color: Colors.red),
                        ),
                        TextButton(
                          onPressed: _loadSponsorships,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_sponsorships.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'No sponsorships available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                )
              else
                _buildSponsorshipsGrid(),
              
              const SizedBox(height: 24),
              
              // Get Sponsored button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(70),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF0094FF), Color(0xFF05055A), Color(0xFF0094FF)],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _selectedSponsorshipId != null 
                      ? () => _submitSponsorshipRequest()
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(70),
                      ),
                    ),
                    child: _isSubmittingSponsorship
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Submitting...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Text(
                            'Get Sponsored Now!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSponsorshipsGrid() {
    if (_sponsorships.isEmpty) {
      return const SizedBox.shrink();
    }

    // Display sponsorships in a row similar to the screenshot
    return Row(
      children: _sponsorships.take(4).toList().asMap().entries.map((entry) {
        final index = entry.key;
        final sponsorship = entry.value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _buildSponsorshipCard(sponsorship, index: index),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSponsorshipCard(Sponsorship sponsorship, {bool isFullWidth = false, int? index}) {
    final price = sponsorship.price ?? 0.0;
    final duration = sponsorship.duration ?? 0;
    final sponsorshipId = sponsorship.id ?? '';
    
    // Create a unique identifier using both ID and index
    final uniqueId = '$sponsorshipId-$index';
    
    // Determine if this should be highlighted (similar to "1 Year" in screenshot)
    final bool isHighlighted = duration >= 365; // 1 year or more
    final bool isSelected = _selectedSponsorshipId == uniqueId;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedSponsorshipId == uniqueId) {
            // If clicking the same card, deselect it
            _selectedSponsorshipId = null;
          } else {
            // If clicking a different card, select it
            _selectedSponsorshipId = uniqueId;
          }
        });
      },
      child: Container(
        width: isFullWidth ? double.infinity : null,
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? const Color(0xFF2079C2) 
            : (isHighlighted ? const Color(0xFF2079C2) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? const Color(0xFF2079C2) 
              : (isHighlighted ? const Color(0xFF2079C2) : Colors.grey.shade300),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getDurationText(duration),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: (isSelected || isHighlighted) ? Colors.white : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: (isSelected || isHighlighted) ? Colors.white : const Color(0xFF2079C2),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getDurationText(int days) {
    if (days >= 365) {
      return '1 Year';
    } else if (days >= 180) {
      return '6 Months';
    } else if (days >= 90) {
      return '3 Months';
    } else if (days >= 60) {
      return '2 Months';
    } else if (days >= 30) {
      return '1 Month';
    } else if (days >= 15) {
      return '15 Days';
    } else {
      return '${days} Days';
    }
  }

  Widget _buildDurationOption(String duration, String price, bool isSelected) {
    return Expanded(
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2079C2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2079C2) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              duration,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF2079C2),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSponsorshipRequest() async {
    if (_selectedSponsorshipId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a sponsorship first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Extract the original sponsorship ID from the unique ID (remove the index part)
    final originalSponsorshipId = _selectedSponsorshipId!.split('-')[0];
    
    // Validate that we have a valid sponsorship ID
    if (originalSponsorshipId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid sponsorship selected. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate that the sponsorship ID is a valid MongoDB ObjectID (24 characters)
    if (originalSponsorshipId.length != 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid sponsorship ID format. Expected 24 characters, got ${originalSponsorshipId.length}.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingSponsorship = true;
    });

    // Validate service provider ID exists and is valid
    if (_serviceProvider?.id == null || _serviceProvider!.id!.isEmpty) {
      setState(() {
        _isSubmittingSponsorship = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Service provider ID not found. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate that the service provider ID is a valid MongoDB ObjectID (24 characters)
    if (_serviceProvider!.id!.length != 24) {
      setState(() {
        _isSubmittingSponsorship = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Invalid service provider ID format. Expected 24 characters, got ${_serviceProvider!.id!.length}.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Debug: Print the values being sent
      print('Submitting sponsorship request:');
      print('  sponsorshipId: $originalSponsorshipId');
      print('  entityType: service_provider');
      print('  entityId: ${_serviceProvider!.id}');
      print('  entityName: Service Provider');
      
      final response = await SponsorshipService.createServiceProviderSponsorshipRequest(
        sponsorshipId: originalSponsorshipId,
        adminNote: null, // Optional: Add a text field for admin note if needed
      );

      if (mounted) {
        setState(() {
          _isSubmittingSponsorship = false;
        });

        // Debug: Print full response
        print('Full response: $response');
        
        // Check both 'status' (as number 200-299 or true) and 'success' for compatibility
        final status = response['status'];
        final success = response['success'];
        final isSuccess = (status is int && status >= 200 && status < 300) || 
                         status == true || 
                         success == true;
        
        print('Status check: status=$status, success=$success, isSuccess=$isSuccess');
        
        if (isSuccess) {
          // Check if we have a collectUrl or paymentUrl for Whish payment
          final paymentUrl = response['data']?['collectUrl'] ?? 
                            response['data']?['paymentUrl'] ?? 
                            response['collectUrl'] ?? 
                            response['paymentUrl'];
          final requestId = response['data']?['requestId']?.toString() ?? 
                           response['requestId']?.toString();
          
          print('Payment URL extracted: $paymentUrl');
          print('Request ID extracted: $requestId');
          
          if (paymentUrl != null && paymentUrl.toString().isNotEmpty) {
            try {
              // Navigate directly to Whish payment URL
              final Uri paymentUri = Uri.parse(paymentUrl.toString());
              print('Parsed payment URI: $paymentUri');
              
              final canLaunch = await canLaunchUrl(paymentUri);
              print('Can launch URL: $canLaunch');
              
              if (canLaunch) {
                await launchUrl(
                  paymentUri,
                  mode: LaunchMode.externalApplication,
                );
                print('✅ Successfully launched payment URL');
                
                // Store payment info for resume handling
                _currentSponsorshipPaymentRequestId = requestId;
                
                // Start polling for payment status
                _pollSponsorshipPaymentStatus(requestId: requestId);
              } else {
                print('❌ Cannot launch URL: $paymentUri');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open payment page. Please check your internet connection.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              print('❌ Error launching URL: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error opening payment page: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } else {
            print('❌ No payment URL found in response');
            // Fallback to old success dialog (in case backend doesn't return paymentUrl)
            // Get selected sponsorship for details
            final selectedSponsorship = _sponsorships.firstWhere(
              (s) => s.id == originalSponsorshipId,
              orElse: () => Sponsorship(),
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Sponsorship request sent successfully!'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            
            // Show success dialog with sponsorship details
            _showSponsorshipSuccessDialog(selectedSponsorship);
          }
          
          // Reset selection
          setState(() {
            _selectedSponsorshipId = null;
          });
          
          // Refresh sponsorship subscription data to show updated status
          _loadSponsorshipSubscriptionData();
        } else {
          // Check if it's an existing request error
          final errorMessage = response['message']?.toString().toLowerCase() ?? '';
          if (errorMessage.contains('already') || 
              errorMessage.contains('pending') || 
              errorMessage.contains('active') ||
              errorMessage.contains('exists')) {
            _showExistingSponsorshipDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? 'Failed to submit sponsorship request'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        setState(() {
          _isSubmittingSponsorship = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSponsorshipSuccessDialog(Sponsorship sponsorship) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Request Sent!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your sponsorship request has been sent to the admin team.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 12),
              // Show sponsorship details
              if (sponsorship.id != null && sponsorship.id!.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Details:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.card_giftcard, color: Colors.blue[600], size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sponsorship.title ?? 'Unknown Package',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.attach_money, color: Colors.green[600], size: 16),
                          SizedBox(width: 8),
                          Text(
                            '\$${(sponsorship.price ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.schedule, color: Colors.orange[600], size: 16),
                          SizedBox(width: 8),
                          Text(
                            '${sponsorship.duration ?? 0} days',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The admin team will review your request and contact you soon.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showExistingSponsorshipDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Sponsorship Already Exists',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You already have an active sponsorship for this package.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSponsorshipDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Sponsorship Request'),
          content: const Text(
            'Your sponsorship request has been sent to the Barrim team. We will contact you shortly with more details.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Join Barrim'),
          content: const Text(
            'Thank you for your interest! Our team will contact you shortly with more details about joining Barrim.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showWhishPaymentDialog({
    required String collectUrl,
    required String planTitle,
    required String planPrice,
    String? requestId,
    int? externalId,
  }) {
    // Service provider brand colors
    const Color primaryBlue = Color(0xFF2079C2);
    const Color navyBlue = Color(0xFF10105D);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2079C2), // #2079C2
                  Color(0xFF1F4889), // #1F4889
                  Color(0xFF10105D), // #10105D
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section with gradient background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.payment,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Complete Payment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content section with white background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You will be redirected to Whish Money to complete your payment.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      // Show testing note in debug mode
                      if (kDebugMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Testing mode: Using Whish Sandbox',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryBlue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.card_membership, color: primaryBlue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  planTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.attach_money, color: primaryBlue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  planPrice,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: navyBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'After payment, you will be redirected back to the app.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                // Close dialog first
                                Navigator.of(context).pop();
                                
                                // Open Whish payment URL
                                final Uri paymentUri = Uri.parse(collectUrl);
                                if (await canLaunchUrl(paymentUri)) {
                                  await launchUrl(
                                    paymentUri,
                                    mode: LaunchMode.externalApplication, // Open in browser
                                  );
                                  
                                  // Store payment info for resume handling
                                  _currentPaymentRequestId = requestId;
                                  _currentPaymentExternalId = externalId;
                                  
                                  // Start polling for payment status
                                  _pollPaymentStatus(requestId: requestId, externalId: externalId);
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not open payment page. Please check your internet connection.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Proceed to Payment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pollPaymentStatus({String? requestId, int? externalId}) {
    // Cancel existing timer if any
    _paymentStatusPollTimer?.cancel();
    
    int pollCount = 0;
    const maxPolls = 60; // Poll for up to 5 minutes (60 * 5 seconds)
    
    _paymentStatusPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      pollCount++;
      
      if (pollCount >= maxPolls) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment verification timed out. Please check your subscription status.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      // Reload subscription data to check for updates
      await _loadSubscriptionData();
      
      // Check if subscription is now active
      if (_remainingTimeData?.hasActiveSubscription == true) {
        timer.cancel();
        _currentPaymentRequestId = null;
        _currentPaymentExternalId = null;
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Payment successful! Your subscription is now active.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          
          // Refresh UI
          _loadSubscriptionData();
          _loadSponsorshipSubscriptionData();
        }
      }
    });
  }
  
  void _showWhishSponsorshipPaymentDialog({
    required String collectUrl,
    required String sponsorshipTitle,
    required String sponsorshipPrice,
    String? requestId,
  }) {
    // Service provider brand colors
    const Color primaryBlue = Color(0xFF2079C2);
    const Color navyBlue = Color(0xFF10105D);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2079C2),
                  Color(0xFF1F4889),
                  Color(0xFF10105D),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section with gradient background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.payment,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Complete Payment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content section with white background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You will be redirected to Whish Money to complete your sponsorship payment.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (kDebugMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Testing mode: Using Whish Sandbox',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryBlue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.card_giftcard, color: primaryBlue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  sponsorshipTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.attach_money, color: primaryBlue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  sponsorshipPrice,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: navyBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'After payment, you will be redirected back to the app.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                // Close dialog first
                                Navigator.of(context).pop();
                                
                                // Open Whish payment URL
                                final Uri paymentUri = Uri.parse(collectUrl);
                                if (await canLaunchUrl(paymentUri)) {
                                  await launchUrl(
                                    paymentUri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  
                                  // Store payment info for resume handling
                                  _currentSponsorshipPaymentRequestId = requestId;
                                  
                                  // Start polling for payment status
                                  _pollSponsorshipPaymentStatus(requestId: requestId);
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not open payment page. Please check your internet connection.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Proceed to Payment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _pollSponsorshipPaymentStatus({String? requestId}) {
    // Cancel existing timer if any
    _paymentStatusPollTimer?.cancel();
    
    int pollCount = 0;
    const maxPolls = 60; // Poll for up to 5 minutes (60 * 5 seconds)
    
    _paymentStatusPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      pollCount++;
      
      if (pollCount >= maxPolls) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment verification timed out. Please check your sponsorship status.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      // Reload sponsorship subscription data to check for updates
      try {
        await _loadSponsorshipSubscriptionData();
        
        // Check if sponsorship subscription is now active
        if (_remainingTimeData?.hasActiveSubscription == true) {
          timer.cancel();
          _currentSponsorshipPaymentRequestId = null;
          
          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Payment successful! Your sponsorship is now active.'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
            
            // Refresh UI
            _loadSponsorshipSubscriptionData();
            _loadSponsorships();
          }
        }
      } catch (e) {
        print('Error polling sponsorship payment status: $e');
        // Continue polling even if there's an error
      }
    });
  }

  // Helper method to get subscription image
  String _getSubscriptionImage(String title) {
    if (title.toLowerCase().contains('monthly')) {
      return 'assets/images/monthly_subscription.png';
    } else if (title.toLowerCase().contains('6') ||
        title.toLowerCase().contains('six')) {
      return 'assets/images/6months_subscription.png';
    } else if (title.toLowerCase().contains('yearly') ||
        title.toLowerCase().contains('annual')) {
      return 'assets/images/yearly_subscription.png';
    }
    return 'assets/images/monthly_subscription.png'; // Default fallback
  }

  void _showSubscriptionDialog(
      subscription_models.SubscriptionPlan plan) async {
    // Check if user already subscribed this month
    final lastSubscriptionMonth = await _getLastSubscriptionMonth();
    final now = DateTime.now();
    final currentMonthYear = DateFormat('yyyy-MM').format(now);

    if (lastSubscriptionMonth == currentMonthYear) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Subscription Limit'),
            content: const Text(
                'You can only subscribe to a plan once per month.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Create subscription request using the service
      final response = await ServiceProviderSubscriptionService
          .createSubscriptionRequest(
        planId: plan.id ?? '',
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.success) {
        // Save the current month and year
        await _setLastSubscriptionMonth(currentMonthYear);

        // Show success dialog
        _showSuccessDialog();
      } else {
        // Check if it's a duplicate subscription error
        final errorMessage = response.message?.toLowerCase() ?? '';
        if (errorMessage.contains('already have') || 
            errorMessage.contains('pending subscription') ||
            errorMessage.contains('active subscription') ||
            errorMessage.contains('conflict') ||
            errorMessage.contains('duplicate')) {
          _showExistingSubscriptionDialog();
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to create subscription request'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Check if it's a duplicate subscription error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('already have') || 
          errorString.contains('pending subscription') ||
          errorString.contains('active subscription') ||
          errorString.contains('conflict') ||
          errorString.contains('duplicate')) {
        _showExistingSubscriptionDialog();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send subscription request: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show insufficient funds dialog when account balance is less than subscription price
  void _showInsufficientFundsDialog({
    required double balance,
    required double requiredAmount,
    required String planTitle,
  }) {
    final shortfall = requiredAmount - balance;
    final formattedBalance = ServiceProviderSubscriptionService.formatPrice(balance);
    final formattedRequired = ServiceProviderSubscriptionService.formatPrice(requiredAmount);
    final formattedShortfall = ServiceProviderSubscriptionService.formatPrice(shortfall);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange[600]!,
                  Colors.orange[700]!,
                  Colors.red[700]!,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Insufficient Funds',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Content section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Whish account balance is insufficient to complete this subscription.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      // Balance details card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subscription Plan:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  planTitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Required Amount:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  formattedRequired,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Current Balance:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  formattedBalance,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Shortfall:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                                Text(
                                  formattedShortfall,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please add funds to your Whish account to proceed with this subscription.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExistingSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Subscription Request Already Sent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have already sent a subscription request. Please wait for the approval or check your current subscription status.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'What you can do:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Check your subscription status\n• Wait for approval\n• Contact support if needed',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xFF0094FF),
                  Color(0xFF05055A),
                  Color(0xFF0094FF),
                ],
              ),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your request has been sent to Barrim team',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Contact us on ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      TextSpan(
                        text: '+961 81004114',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final Uri launchUri = Uri(
                                scheme: 'tel', path: '+96181004114');
                            if (await canLaunchUrl(launchUri)) {
                              await launchUrl(launchUri);
                            }
                          },
                      ),
                      const TextSpan(
                        text: ' for more information about the payment',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _loadSubscriptionData(); // Refresh subscription data
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF05055A),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to get the month and year of the last successful subscription request
  Future<String?> _getLastSubscriptionMonth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sp_subscription_month');
  }

  // Helper method to save the current month and year as the last subscription request date
  Future<void> _setLastSubscriptionMonth(String monthYear) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sp_subscription_month', monthYear);
  }
}