import 'package:flutter/material.dart';
import '../../../headers/service_provider_header.dart';
import '../../../headers/sidebar.dart';
import '../../../../../../src/services/service_provider_services.dart' as sp_services;
import '../../../../../../src/services/service_provider_subscription_service.dart';
import '../../../../../../src/models/service_provider.dart';
import '../../../../../../src/models/subscription.dart' as subscription_models;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ServiceproviderSubscription extends StatefulWidget {
  const ServiceproviderSubscription({Key? key}) : super(key: key);

  @override
  State<ServiceproviderSubscription> createState() => _ServiceproviderSubscriptionState();
}

class _ServiceproviderSubscriptionState extends State<ServiceproviderSubscription> with TickerProviderStateMixin {
  final sp_services.ServiceProviderService _serviceProviderService = sp_services
      .ServiceProviderService();
  final ServiceProviderSubscriptionService _subscriptionService = ServiceProviderSubscriptionService();
  bool _isSidebarOpen = false;
  bool _isLoading = true;
  List<subscription_models.SubscriptionPlan> _subscriptionPlans = [];
  dynamic _currentSubscription;
  String? _error;
  Map<String, dynamic>? _timeRemaining;
  ServiceProvider? _serviceProvider;

  // Animation controller for circular progress
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
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
    _fetchServiceProvider();
    _loadSubscriptionData();
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plansResponse = await ServiceProviderSubscriptionService
          .getSubscriptionPlans();
      final statusResponse = await ServiceProviderSubscriptionService
          .getSubscriptionStatus();
      final timeRemainingResponse = await ServiceProviderSubscriptionService
          .getSubscriptionTimeRemaining();

      if (mounted) {
        setState(() {
          if (plansResponse.success) {
            _subscriptionPlans = plansResponse.data ?? [];
            print('Loaded subscription plans: ${_subscriptionPlans.length}');
          } else {
            _error = plansResponse.message;
          }
          if (statusResponse.success) {
            _currentSubscription = statusResponse.data;
          }
          if (timeRemainingResponse.success) {
            _timeRemaining = timeRemainingResponse.data;
            // Start animation when time remaining is loaded
            _progressAnimationController.forward();
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

  Future<void> _fetchServiceProvider() async {
    try {
      final provider = await _serviceProviderService.getServiceProviderData();
      if (mounted) {
        setState(() {
          _serviceProvider = provider;
        });
      }
    } catch (e) {
      // Optionally handle error
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
                      _buildSectionTitle('Service Provider Subscriptions'),
                      const SizedBox(height: 24),

                      // Current subscription status with circular progress
                      if (_currentSubscription != null)
                        _buildCurrentSubscriptionStatus(),

                      const SizedBox(height: 24),

                      // Subscription plans grid
                      if (_subscriptionPlans.isNotEmpty)
                        _buildSubscriptionPlansGrid()
                      else
                        const Center(
                          child: Text('No subscription plans available'),
                        ),

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

  Widget _buildCurrentSubscriptionStatus() {
    if (_timeRemaining == null) return const SizedBox.shrink();

    final bool isActive = _timeRemaining!['isActive'] ?? false;
    final int remainingDays = _timeRemaining!['remainingDays'] ?? 0;
    final String endDate = _timeRemaining!['endDate'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side - Status info
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                   
                    const SizedBox(width: 8),
                    Text(
                      isActive ? 'Active Subscription' : '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isActive) ...[
                  Text(
                    'Time Remaining: ${ServiceProviderSubscriptionService.formatRemainingTime(remainingDays)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'End Date: ${endDate.isNotEmpty ? endDate : 'N/A'}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
                if (ServiceProviderSubscriptionService.isSubscriptionExpiringSoon(remainingDays)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ServiceProviderSubscriptionService.getExpiryWarningMessage(remainingDays) ?? '',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right side - Circular progress
          if (isActive) ...[
            const SizedBox(width: 16),
            _buildCircularTimeProgress(remainingDays),
          ],
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
                      const SizedBox(height: 4),
                      Text(
                        'Time Left',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
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
    if (_subscriptionPlans.isEmpty) {
      return const Center(
        child: Text('No subscription plans available'),
      );
    }

    // If there's only one plan, display it full width
    if (_subscriptionPlans.length == 1) {
      return _buildSubscriptionCard(
        _subscriptionPlans.first,
        const Color(0xFF2079C2),
        isFullWidth: true,
      );
    }

    // Group plans by type (monthly, 6 months, yearly)
    final monthlyPlans = _subscriptionPlans.where((p) =>
    p.type?.toLowerCase()
        .contains('monthly') ?? false).toList();
    final sixMonthPlans = _subscriptionPlans.where((p) =>
    p.type?.toLowerCase()
        .contains('6') ?? false).toList();
    final yearlyPlans = _subscriptionPlans.where((p) =>
    p.type?.toLowerCase()
        .contains('yearly') ?? false).toList();

    return Column(
      children: [
        // Monthly and 6-month plans row
        if (monthlyPlans.isNotEmpty || sixMonthPlans.isNotEmpty)
          Row(
            children: [
              if (monthlyPlans.isNotEmpty)
                Expanded(
                  child: _buildSubscriptionCard(
                    monthlyPlans.first,
                    const Color(0xFF2079C2),
                  ),
                ),
              if (monthlyPlans.isNotEmpty && sixMonthPlans.isNotEmpty)
                const SizedBox(width: 16),
              if (sixMonthPlans.isNotEmpty)
                Expanded(
                  child: _buildSubscriptionCard(
                    sixMonthPlans.first,
                    const Color(0xFF1F4889),
                  ),
                ),
            ],
          ),

        const SizedBox(height: 20),

        // Yearly plan (full width)
        if (yearlyPlans.isNotEmpty)
          _buildSubscriptionCard(
            yearlyPlans.first,
            const Color(0xFF10105D),
            isFullWidth: true,
          ),
      ],
    );
  }

  Widget _buildSubscriptionCard(subscription_models.SubscriptionPlan plan,
      Color backgroundColor, {
        bool isFullWidth = false,
      }) {
    final benefits = plan.benefitsText.split('\n')
        .where((b) => b.isNotEmpty)
        .toList();

    return Container(
      width: isFullWidth ? double.infinity : null,
      constraints: isFullWidth ? null : const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        color: (plan.type?.toLowerCase().contains('yearly') ?? false)
            ? const Color(0xFF0094FF)
            : null,
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
                _getSubscriptionImage(plan.type ?? ''),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Container(
                    color: backgroundColor.withOpacity(0.1),
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
                    plan.title ?? plan.type ?? 'Unknown Plan',
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
                      onPressed: () => _showSubscriptionDialog(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: backgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        'Join for only \$${plan.price?.toStringAsFixed(2) ??
                            '0.00'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

  // Helper method to get subscription image
  String _getSubscriptionImage(String type) {
    if (type.toLowerCase().contains('monthly')) {
      return 'assets/images/monthly_subscription.png';
    } else if (type.toLowerCase().contains('6') ||
        type.toLowerCase().contains('six')) {
      return 'assets/images/6months_subscription.png';
    } else if (type.toLowerCase().contains('yearly') ||
        type.toLowerCase().contains('annual')) {
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