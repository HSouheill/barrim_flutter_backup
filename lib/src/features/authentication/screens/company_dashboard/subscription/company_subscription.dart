import 'package:flutter/material.dart';
import '../../../headers/company_header.dart';
import '../../../headers/dashboard_headers.dart';
import '../../../headers/sidebar.dart';
import '../../../../../../src/services/company_service.dart';
import '../../../../../../src/services/company_subscription_service.dart';
import '../../../../../../src/models/company_model.dart';
import '../../../../../../src/models/subscription.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../company_settings.dart';


class CompanySubscriptionsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? logoUrl;
  const CompanySubscriptionsPage({Key? key, required this.userData, this.logoUrl}) : super(key: key);

  @override
  State<CompanySubscriptionsPage> createState() => _CompanySubscriptionsPageState();
}

class _CompanySubscriptionsPageState extends State<CompanySubscriptionsPage> with TickerProviderStateMixin {
  final CompanyService _companyService = CompanyService();
  bool _isSidebarOpen = false;
  bool _isLoading = false;
  List<SubscriptionPlan> _subscriptionPlans = [];
  SubscriptionStatus? _currentSubscription;
  String? _error;
  Timer? _refreshTimer;
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
    // Set up periodic refresh for subscription status
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _loadSubscriptionData();
    });

    // Initialize animation controller
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
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load subscription plans
      final plansResponse = await CompanySubscriptionService.getSubscriptionPlans();
      print('Subscription Plans Response: ${plansResponse.success}');
      print('Subscription Plans Message: ${plansResponse.message}');
      print('Subscription Plans Data: ${plansResponse.data?.map((p) => p.toJson()).toList()}');

      if (plansResponse.success && plansResponse.data != null) {
        setState(() {
          _subscriptionPlans = plansResponse.data!;
        });
        print('Updated _subscriptionPlans: ${_subscriptionPlans.map((p) => p.toJson()).toList()}');
      }

      // Load current subscription status
      final statusResponse = await CompanySubscriptionService.getSubscriptionStatus();
      print('Subscription Status Response: ${statusResponse.success}');
      print('Subscription Status Message: ${statusResponse.message}');
      if (statusResponse.data != null) {
        final status = statusResponse.data!;
        print('Subscription Status:');
        print('- Has Active Subscription: ${status.hasActiveSubscription}');
        print('- Is Active: ${status.isActive}');
        print('- Is Expired: ${status.isExpired}');
        print('- Is Expiring Soon: ${status.isExpiringSoon}');
        print('- Days Remaining: ${status.daysRemaining}');
        print('- Status Text: ${status.statusText}');
        print('- Plan: ${status.plan?.toJson()}');
      }

      if (statusResponse.success && statusResponse.data != null) {
        setState(() {
          _currentSubscription = statusResponse.data;
        });
        print('Updated _currentSubscription:');
        print('- Has Active Subscription: ${_currentSubscription?.hasActiveSubscription}');
        print('- Is Active: ${_currentSubscription?.isActive}');
        print('- Is Expired: ${_currentSubscription?.isExpired}');
        print('- Is Expiring Soon: ${_currentSubscription?.isExpiringSoon}');
        print('- Days Remaining: ${_currentSubscription?.daysRemaining}');
        print('- Status Text: ${_currentSubscription?.statusText}');
        print('- Plan: ${_currentSubscription?.plan?.toJson()}');
      }
    } catch (e) {
      print('Error loading subscription data: $e');
      setState(() {
        _error = 'Failed to load subscription data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _cancelSubscription() async {
    try {
      final response = await CompanySubscriptionService.cancelSubscription();
      if (response.success) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Subscription cancelled successfully'),
        //     backgroundColor: Colors.green,
        //   ),
        // );
        _loadSubscriptionData();
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(response.message),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to cancel subscription: \\${e.toString()}'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Subscription'),
          content: const Text('Are you sure you want to cancel your current subscription?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelSubscription();
              },
              child: const Text('Yes, Cancel'),
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
              CompanyAppHeader(
                logoUrl: widget.logoUrl,
                userData: widget.userData,

                onAvatarTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),

              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSubscriptionData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),



                        // Company Subscriptions Section
                        _buildSectionTitle('Company Subscriptions'),
                        // const SizedBox(height: 14),

                        // Subscription Plans Grid
                        _buildSubscriptionPlansGrid(),

                        // const SizedBox(height: 40),

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
                      left: 0,
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
                fontSize: 22,
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

  Widget _buildSubscriptionPlansGrid() {
    if (_subscriptionPlans.isEmpty) {
      return const Center(
        child: Text('No subscription plans available'),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _subscriptionPlans.length,
      itemBuilder: (context, index) {
        final plan = _subscriptionPlans[index];
        final benefitsList = plan.benefitsText.split('\n').where((b) => b.isNotEmpty).toList();
        return _buildSubscriptionCard(
          plan.title ?? 'Unknown Plan',
          CompanySubscriptionService.formatPrice(plan.price ?? 0),
          benefitsList,
          const Color(0xFF2079C2),
        );
      },
    );
  }

  Widget _buildSubscriptionCard(
      String title,
      String price,
      List<String> benefits,
      Color backgroundColor, {
        bool isFullWidth = false,
      }) {
    final bool isCurrentPlan = _currentSubscription?.plan?.title == title;
    final bool isActive = _currentSubscription?.isActive ?? false;

    return Container(
      width: isFullWidth ? double.infinity : null,
      constraints: isFullWidth ? null : const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        color: title.toLowerCase().contains('yearly') ? const Color(0xFF0094FF) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        border: isCurrentPlan ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                _getSubscriptionImage(title),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (isCurrentPlan)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Benefits list
                  ...benefits.map((benefit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.white, fontSize: 16)),
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
                      onPressed: isCurrentPlan && isActive
                          ? null
                          : () => _showSubscriptionDialog(title, price),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: backgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                      ),
                      child: Text(
                        isCurrentPlan && isActive
                            ? 'Current Plan'
                            : 'Join for only $price',
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




  void _showSubscriptionDialog(String plan, String price) async {
    // Find the selected plan
    final selectedPlan = _subscriptionPlans.firstWhere(
          (p) => p.title == plan,
      orElse: () => throw Exception('Plan not found'),
    );

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
      // Create subscription request
      final response = await CompanySubscriptionService.createSubscriptionRequest(
        planId: selectedPlan.id!,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.success) {
        // Show success dialog
        _showSuccessDialog();
      } else {
        // Show error message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(response.message),
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
                            final Uri launchUri = Uri(scheme: 'tel', path: '+96181004114');
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
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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



  // Helper method to get subscription image
  String _getSubscriptionImage(String title) {
    switch (title.toLowerCase()) {
      case 'monthly':
        return 'assets/images/monthly_subscription.png';
      case '6 months':
        return 'assets/images/6months_subscription.png';
      case 'yearly':
        return 'assets/images/yearly_subscription.png';
      default:
        return 'assets/images/monthly_subscription.png'; // Changed default image
    }
  }

  Widget _buildCurrentSubscriptionStatus() {
    if (_currentSubscription == null) {
      return const SizedBox.shrink();
    }

    final status = _currentSubscription!;
    final Color statusColor = status.isActive
        ? (status.isExpiringSoon ? Colors.orange : Colors.green)
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (status.plan != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      status.plan!.title ?? 'Unknown Plan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              if (status.isActive)
                TextButton.icon(
                  onPressed: _showCancelConfirmationDialog,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          if (status.isActive && status.daysRemaining > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${status.daysRemaining} days remaining',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
          if (status.isActive && status.plan != null) ...[
            const SizedBox(height: 8),
            Text(
              'Benefits: ${status.plan!.benefitsText}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
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

  Color _getProgressColor(double progress) {
    if (progress > 0.5) {
      return const Color(0xFF0094FF); // Blue for healthy time remaining
    } else if (progress > 0.2) {
      return Colors.orange; // Orange for moderate time remaining
    } else {
      return Colors.red; // Red for low time remaining
    }
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
}