import 'package:flutter/material.dart';
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


  
  // Sponsorship state
  List<Sponsorship> _sponsorships = [];
  bool _isLoadingSponsorships = false;
  String? _sponsorshipError;
  SponsorshipPagination? _sponsorshipPagination;
  String? _selectedSponsorshipId;
  bool _isSubmittingSponsorship = false;
  
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
    _progressAnimationController.dispose();
    _pulseAnimationController?.dispose();
    
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // Pause the countdown timer when app is in background
        _stopCountdownTimer();
        break;
      case AppLifecycleState.resumed:
        // Resume the countdown timer when app comes to foreground
        if (_remainingTimeData?.hasActiveSubscription == true) {
          _startCountdownTimer();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Loading subscription data...');
      final plansResponse = await ServiceProviderSubscriptionService
          .getSubscriptionPlans();
      print('Plans response: success=${plansResponse.success}, message=${plansResponse.message}');
      
      final statusResponse = await ServiceProviderSubscriptionService
          .getSubscriptionStatus();
      print('Status response: success=${statusResponse.success}, message=${statusResponse.message}');
      
      final timeRemainingResponse = await ServiceProviderSubscriptionService
          .getSubscriptionTimeRemaining();
      print('Time remaining response: success=${timeRemainingResponse.success}, message=${timeRemainingResponse.message}');

      if (mounted) {
        setState(() {
          if (plansResponse.success) {
            _subscriptionPlans = plansResponse.data ?? [];
            print('Loaded subscription plans: ${_subscriptionPlans.length}');
            // Debug: Print each plan details
            for (var plan in _subscriptionPlans) {
              print('Plan: ${plan.title}, Type: ${plan.type}, Price: ${plan.price}, ID: ${plan.id}');
              print('  Benefits: ${plan.benefitsText}');
            }
          } else {
            _error = plansResponse.message;
            print('Failed to load subscription plans: ${plansResponse.message}');
          }
          if (statusResponse.success) {
            _currentSubscription = statusResponse.data;
          }
          if (timeRemainingResponse.success && timeRemainingResponse.data != null) {
            // Parse the remaining time data to match the new structure
            _parseRemainingTimeData(timeRemainingResponse.data!);
            // Start animation when time remaining is loaded
            _progressAnimationController.forward(from: 0.0);
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
      final response = await SponsorshipService.getServiceProviderSponsorshipTimeRemaining();
      
      if (mounted && response['success'] == true) {
        final data = response['data'];
        if (data != null) {
          // Parse sponsorship subscription data
          _parseSponsorshipSubscriptionData(data);
        }
      }
    } catch (e) {
      print('Error loading sponsorship subscription data: $e');
    }
  }

  void _parseSponsorshipSubscriptionData(Map<String, dynamic> data) {
    try {
      final hasActiveSubscription = data['hasActiveSubscription'] ?? false;
      
      if (hasActiveSubscription && data['timeRemaining'] != null) {
        final timeRemaining = data['timeRemaining'] as Map<String, dynamic>;
        
        // Create sponsorship subscription remaining time data
        final sponsorshipRemainingTimeData = SponsorshipSubscriptionTimeRemainingData(
          hasActiveSubscription: hasActiveSubscription,
          timeRemaining: SponsorshipSubscriptionTimeRemaining(
            days: timeRemaining['days'] ?? 0,
            hours: timeRemaining['hours'] ?? 0,
            minutes: timeRemaining['minutes'] ?? 0,
            seconds: timeRemaining['seconds'] ?? 0,
            formatted: timeRemaining['formatted'] ?? '',
            percentageUsed: timeRemaining['percentageUsed'] ?? '0%',
            startDate: timeRemaining['startDate'] != null ? DateTime.parse(timeRemaining['startDate']) : null,
            endDate: timeRemaining['endDate'] != null ? DateTime.parse(timeRemaining['endDate']) : null,
          ),
          subscription: data['subscription'] != null ? SponsorshipSubscription.fromJson(data['subscription']) : null,
          sponsorship: data['sponsorship'] != null ? Sponsorship.fromJson(data['sponsorship']) : null,
          entityInfo: data['entityInfo'] != null ? SponsorshipSubscriptionEntityInfo.fromJson(data['entityInfo']) : null,
          message: data['message'],
        );
        
        // Update state with sponsorship data
        setState(() {
          // You can add a new state variable for sponsorship subscription data
          // For now, we'll use the existing _remainingTimeData structure
          if (sponsorshipRemainingTimeData.timeRemaining != null) {
            _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
              hasActiveSubscription: hasActiveSubscription,
              remainingTime: subscription_models.SubscriptionRemainingTime(
                days: sponsorshipRemainingTimeData.timeRemaining!.days,
                hours: sponsorshipRemainingTimeData.timeRemaining!.hours,
                minutes: sponsorshipRemainingTimeData.timeRemaining!.minutes,
                formatted: sponsorshipRemainingTimeData.timeRemaining!.formatted,
                percentageUsed: sponsorshipRemainingTimeData.timeRemaining!.percentageUsed,
                endDate: sponsorshipRemainingTimeData.timeRemaining!.endDate,
              ),
            );
          }
        });
        
        // Start countdown timer if we have active sponsorship
        if (hasActiveSubscription) {
          _startCountdownTimer();
          if (sponsorshipRemainingTimeData.timeRemaining?.endDate != null) {
            _setSubscriptionEndDate(sponsorshipRemainingTimeData.timeRemaining!.endDate);
          }
        } else {
          _stopCountdownTimer();
        }
      } else {
        // No active sponsorship subscription
        setState(() {
          _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
            hasActiveSubscription: false,
            remainingTime: null,
          );
        });
        _stopCountdownTimer();
      }
    } catch (e) {
      print('Error parsing sponsorship subscription data: $e');
      setState(() {
        _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
          hasActiveSubscription: false,
          remainingTime: null,
        );
      });
      _stopCountdownTimer();
    }
  }

  void _parseRemainingTimeData(Map<String, dynamic> data) {
    try {
      final hasActiveSubscription = data['hasActiveSubscription'] ?? false;
      
      if (hasActiveSubscription && data['remainingTime'] != null) {
        final remainingTime = data['remainingTime'] as Map<String, dynamic>;
        
        final remainingTimeData = subscription_models.SubscriptionRemainingTime(
          days: remainingTime['days'],
          hours: remainingTime['hours'],
          minutes: remainingTime['minutes'],
          formatted: remainingTime['formatted'],
          percentageUsed: remainingTime['percentageUsed'],
          endDate: remainingTime['endDate'] != null ? DateTime.parse(remainingTime['endDate']) : null,
        );
        
        _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
          hasActiveSubscription: hasActiveSubscription,
          remainingTime: remainingTimeData,
        );
        
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
        _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
          hasActiveSubscription: false,
          remainingTime: null,
        );
        _stopCountdownTimer();
      }
    } catch (e) {
      print('Error parsing remaining time data: $e');
      _remainingTimeData = subscription_models.SubscriptionRemainingTimeData(
        hasActiveSubscription: false,
        remainingTime: null,
      );
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
        final sponsorships = SponsorshipService.parseSponsorships(response);
        setState(() {
          _sponsorships = sponsorships;
          _sponsorshipPagination = SponsorshipService.parsePagination(response);
          _sponsorshipError = response['success'] == true ? null : response['message'];
          _isLoadingSponsorships = false;
        });
        
        // Debug: Print sponsorship IDs
        print('Loaded ${sponsorships.length} sponsorships:');
        for (var i = 0; i < sponsorships.length; i++) {
          final sponsorship = sponsorships[i];
          print('  Sponsorship $i: ID=${sponsorship.id}, Length=${sponsorship.id?.length ?? 0}');
        }
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
    setState(() {
      _isSubmittingSubscription = true;
    });

    try {
      final response = await ServiceProviderSubscriptionService.createSubscriptionRequest(
        planId: plan.id!,
        // paymentProofImage: null, // Optional: Add file picker for payment proof
      );

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${plan.title} subscription request submitted successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Failed to submit subscription request'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
                          IconButton(
                            onPressed: _loadSubscriptionData,
                            icon: Icon(Icons.refresh, color: Colors.blue),
                            tooltip: 'Refresh subscription plans',
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
    print('Building subscription plans grid with ${_subscriptionPlans.length} plans');
    print('Plans: ${_subscriptionPlans.map((p) => '${p.title} (${p.id})').join(', ')}');
    
    if (_subscriptionPlans.isEmpty) {
      return const Center(
        child: Text('No subscription plans available'),
      );
    }

    // If there's only one plan, display it full width
    if (_subscriptionPlans.length == 1) {
      return _buildSubscriptionCard(
        _subscriptionPlans.first,
        'default',
        isFullWidth: true,
      );
    }

    // Group plans by title (monthly, 6 months, yearly)
    final monthlyPlans = _subscriptionPlans.where((p) =>
    p.title?.toLowerCase()
        .contains('monthly') ?? false).toList();
    final sixMonthPlans = _subscriptionPlans.where((p) =>
    p.title?.toLowerCase()
        .contains('6') ?? false).toList();
    final yearlyPlans = _subscriptionPlans.where((p) =>
    p.title?.toLowerCase()
        .contains('yearly') ?? false).toList();
    
    print('Filtered plans - Monthly: ${monthlyPlans.length}, 6 Months: ${sixMonthPlans.length}, Yearly: ${yearlyPlans.length}');

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
      ],
    );
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
    if (_remainingTimeData == null || !_remainingTimeData!.hasActiveSubscription!) {
      return const SizedBox.shrink();
    }
    
    final remaining = _remainingTimeData!.remainingTime;
    if (remaining == null) return const SizedBox.shrink();
    
    final percentUsed = double.tryParse((remaining.percentageUsed ?? '0').replaceAll('%', '')) ?? 0;
    final percentLeft = 1 - (percentUsed / 100);
    
    return Container(
      child: Column(
        children: [
          // Section title with refresh button
          Row(
            children: [
              Expanded(
                child: _buildSectionTitle('Time Left'),
              ),
              IconButton(
                onPressed: _loadSubscriptionData,
                icon: Icon(Icons.refresh, color: Colors.blue),
                tooltip: 'Refresh subscription status',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Main time remaining widget
          Container(
            padding: const EdgeInsets.all(24),
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
    return Container(
      child: Column(
        children: [
          // Section title with refresh button
          Row(
            children: [
              Expanded(
                child: _buildSectionTitle('Sponsorship Status'),
              ),
              IconButton(
                onPressed: _loadSponsorshipSubscriptionData,
                icon: Icon(Icons.refresh, color: Colors.blue),
                tooltip: 'Refresh sponsorship status',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Sponsorship subscription content
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Check if we have sponsorship subscription data
                if (_remainingTimeData?.hasActiveSubscription == true)
                  _buildActiveSponsorshipStatus()
                else
                  _buildNoSponsorshipStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSponsorshipStatus() {
    final remaining = _remainingTimeData?.remainingTime;
    if (remaining == null) return _buildNoSponsorshipStatus();
    
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
        
        // Time remaining display
        Text(
          remaining.formatted ?? '0D:0H',
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

  Widget _buildNoSponsorshipStatus() {
    return Column(
      children: [
        Icon(
          Icons.star,
          size: 64,
          color: Colors.grey[400],
        ),
        SizedBox(height: 16),
        Text(
          'No Active Sponsorship',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'You don\'t have an active sponsorship subscription.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        Text(
          'Apply for sponsorships below to get featured on our platform!',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSponsorshipSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSectionTitle('Sponsorship'),
            ),
            IconButton(
              onPressed: _loadSponsorships,
              icon: Icon(Icons.refresh, color: Colors.blue),
              tooltip: 'Refresh sponsorships',
            ),
          ],
        ),
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

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button from closing dialog
          child: AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                SizedBox(width: 20),
                Text(
                  'Sending request to admin...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Validate service provider ID exists and is valid
    if (_serviceProvider?.id == null || _serviceProvider!.id!.isEmpty) {
      Navigator.of(context).pop(); // Close loading dialog
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
      Navigator.of(context).pop(); // Close loading dialog
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
        // Close loading dialog
        Navigator.of(context).pop();
        
        setState(() {
          _isSubmittingSponsorship = false;
        });

        if (response['success'] == true) {
          // Show success snackbar first
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
          final selectedSponsorship = _sponsorships.firstWhere(
            (s) => s.id == originalSponsorshipId,
            orElse: () => Sponsorship(),
          );
          _showSponsorshipSuccessDialog(selectedSponsorship);
          
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
                'You already have a pending or active sponsorship request for this package.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please wait for the admin team to review your existing request before submitting a new one.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
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
        // Show error message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(
        //         response.message ?? 'Failed to create subscription request'),
        //     backgroundColor: Colors.red,
        //     duration: const Duration(seconds: 3),
        //   ),
        // );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to send subscription request: \\${e.toString()}'),
      //     backgroundColor: Colors.red,
      //     duration: const Duration(seconds: 3),
      //   ),
      // );
    }
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