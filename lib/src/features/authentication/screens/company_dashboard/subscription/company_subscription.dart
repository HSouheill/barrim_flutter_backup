import 'package:flutter/material.dart';
import '../../../headers/company_header.dart';
import '../../../headers/dashboard_headers.dart';
import '../../../headers/sidebar.dart';
import '../../../../../../src/services/company_service.dart';
import '../../../../../../src/services/company_subscription_service.dart';
import '../../../../../../src/services/sponsorship_service.dart';
import '../../../../../../src/models/company_model.dart';
import '../../../../../../src/models/subscription.dart';
import '../../../../../../src/models/sponsorship.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../company_settings.dart';



class CompanySubscriptionsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? logoUrl;
  final String? branchId;
  const CompanySubscriptionsPage({Key? key, required this.userData, this.logoUrl, this.branchId}) : super(key: key);

  @override
  State<CompanySubscriptionsPage> createState() => _CompanySubscriptionsPageState();
}

class _CompanySubscriptionsPageState extends State<CompanySubscriptionsPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final CompanyService _companyService = CompanyService();
  bool _isSidebarOpen = false;
  bool _isLoading = false;
  List<SubscriptionPlan> _subscriptionPlans = [];
  SubscriptionStatus? _currentSubscription;
  String? _error;
  Timer? _refreshTimer;
  Timer? _countdownTimer; // Add countdown timer
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  AnimationController? _pulseAnimationController; // Make nullable for safety
  Animation<double>? _pulseAnimation; // Make nullable for safety
  SubscriptionRemainingTimeData? _remainingTimeData; // <-- Add this line
  
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

  // Sponsorship subscription state
  SponsorshipSubscriptionTimeRemainingData? _sponsorshipSubscriptionData;
  bool _isLoadingSponsorshipSubscription = false;
  String? _sponsorshipSubscriptionError;
  
  // Sponsorship countdown timer state
  Timer? _sponsorshipCountdownTimer;
  String _sponsorshipCurrentTimeDisplay = '';
  DateTime? _sponsorshipEndDate;

  @override
  void initState() {
    super.initState();
    
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    _loadSubscriptionData();
    _loadSponsorships();
    _loadSponsorshipSubscriptionData(); // Load sponsorship subscription data
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
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _sponsorshipCountdownTimer?.cancel();
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
        // Pause the countdown timers when app is in background
        _stopCountdownTimer();
        _stopSponsorshipCountdownTimer();
        break;
      case AppLifecycleState.resumed:
        // Resume the countdown timers when app comes to foreground
        if (_remainingTimeData?.hasActiveSubscription == true) {
          _startCountdownTimer();
        }
        if (_sponsorshipSubscriptionData?.hasActiveSubscription == true) {
          _startSponsorshipCountdownTimer();
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
      final statusResponse = await CompanySubscriptionService.getSubscriptionStatus(
        branchId: widget.branchId ?? '',
      );
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

      // Load remaining time
      final remainingTimeResponse = await CompanySubscriptionService.getSubscriptionRemainingTime(
        branchId: widget.branchId ?? '',
      );
      if (remainingTimeResponse.success && remainingTimeResponse.data != null) {
        setState(() {
          _remainingTimeData = remainingTimeResponse.data;
        });
        _progressAnimationController.forward(from: 0.0);
        
        // Start countdown timer if we have remaining time data
        if (remainingTimeResponse.data!.hasActiveSubscription == true) {
          _startCountdownTimer();
          // Set subscription end date for countdown timer
          if (remainingTimeResponse.data!.remainingTime?.endDate != null) {
            _setSubscriptionEndDate(remainingTimeResponse.data!.remainingTime!.endDate);
          }
        } else {
          _stopCountdownTimer();
        }
      } else {
        _stopCountdownTimer();
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

  Future<void> _loadSponsorships() async {
    setState(() {
      _isLoadingSponsorships = true;
      _sponsorshipError = null;
    });

    try {
      print('Loading company/wholesaler sponsorships...');
      final response = await SponsorshipService.getCompanyWholesalerSponsorships(
        page: 1,
        limit: 20,
      );

      print('Sponsorship response: $response');

      if (mounted) {
        final sponsorships = SponsorshipService.parseSponsorships(response);
        print('Parsed sponsorships: ${sponsorships.length}');
        print('Sponsorships: ${sponsorships.map((s) => s.toJson()).toList()}');
        
        setState(() {
          _sponsorships = sponsorships;
          _sponsorshipPagination = SponsorshipService.parsePagination(response);
          _sponsorshipError = response['success'] == true ? null : response['message'];
          _isLoadingSponsorships = false;
        });
      }
    } catch (e) {
      print('Error loading sponsorships: $e');
      if (mounted) {
        setState(() {
          _sponsorshipError = 'Failed to load sponsorships: ${e.toString()}';
          _isLoadingSponsorships = false;
        });
      }
    }
  }

  Future<void> _loadSponsorshipSubscriptionData() async {
    if (widget.branchId == null || widget.branchId!.isEmpty) {
      print('DEBUG: Branch ID is null or empty, skipping sponsorship subscription data load');
      return;
    }

    print('DEBUG: Loading sponsorship subscription data for branch: ${widget.branchId}');

    setState(() {
      _isLoadingSponsorshipSubscription = true;
      _sponsorshipSubscriptionError = null;
    });

    try {
      final response = await SponsorshipService.getCompanyBranchSponsorshipTimeRemaining(
        branchId: widget.branchId!,
      );

      print('DEBUG: Sponsorship subscription API response: $response');

      if (mounted) {
        // Check for success in the response
        final isSuccess = response['status'] == 200 || response['success'] == true;
        print('DEBUG: Response success check - status: ${response['status']}, success: ${response['success']}, isSuccess: $isSuccess');
        
        if (isSuccess && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          print('DEBUG: Found data in response, parsing...');
          
          // Parse the response data
          _parseSponsorshipSubscriptionData(data);
        } else {
          print('DEBUG: No success or no data in response');
          setState(() {
            _sponsorshipSubscriptionData = SponsorshipSubscriptionTimeRemainingData(
              hasActiveSubscription: false,
              message: response['message'] ?? 'No active sponsorship subscription found',
            );
            _sponsorshipSubscriptionError = null;
            _isLoadingSponsorshipSubscription = false;
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error in _loadSponsorshipSubscriptionData: $e');
      if (mounted) {
        setState(() {
          _sponsorshipSubscriptionError = 'Failed to load sponsorship subscription data: ${e.toString()}';
          _isLoadingSponsorshipSubscription = false;
        });
      }
    }
  }

  void _parseSponsorshipSubscriptionData(Map<String, dynamic> data) {
    try {
      print('DEBUG: Parsing sponsorship subscription data: $data');
      
      final hasActiveSubscription = data['hasActiveSubscription'] ?? false;
      print('DEBUG: hasActiveSubscription: $hasActiveSubscription');
      
      if (hasActiveSubscription && data['timeRemaining'] != null) {
        final timeRemaining = data['timeRemaining'] as Map<String, dynamic>;
        print('DEBUG: timeRemaining data: $timeRemaining');
        
        final remainingTime = SponsorshipSubscriptionTimeRemaining(
          days: timeRemaining['days'],
          hours: timeRemaining['hours'],
          minutes: timeRemaining['minutes'],
          seconds: timeRemaining['seconds'],
          formatted: timeRemaining['formatted'],
          percentageUsed: timeRemaining['percentageUsed'],
          startDate: timeRemaining['startDate'] != null ? DateTime.parse(timeRemaining['startDate']) : null,
          endDate: timeRemaining['endDate'] != null ? DateTime.parse(timeRemaining['endDate']) : null,
        );
        
        print('DEBUG: Created remainingTime object: ${remainingTime.toJson()}');
        
        _sponsorshipSubscriptionData = SponsorshipSubscriptionTimeRemainingData(
          hasActiveSubscription: hasActiveSubscription,
          timeRemaining: remainingTime,
          subscription: data['subscription'] != null 
              ? SponsorshipSubscription.fromJson(data['subscription'])
              : null,
          sponsorship: data['sponsorship'] != null 
              ? Sponsorship.fromJson(data['sponsorship'])
              : null,
          entityInfo: data['entityInfo'] != null 
              ? SponsorshipSubscriptionEntityInfo.fromJson(data['entityInfo'])
              : null,
          message: data['message'],
        );
        
        print('DEBUG: Parsed sponsorship subscription data successfully');
        print('DEBUG: hasActiveSubscription: $hasActiveSubscription');
        print('DEBUG: timeRemaining: ${remainingTime.toJson()}');
        print('DEBUG: sponsorship: ${data['sponsorship']}');
        print('DEBUG: entityInfo: ${data['entityInfo']}');
        
        // Start countdown timer if we have active subscription
        if (hasActiveSubscription && remainingTime.endDate != null) {
          print('DEBUG: Starting countdown timer with end date: ${remainingTime.endDate}');
          _setSponsorshipEndDate(remainingTime.endDate);
        } else {
          print('DEBUG: Stopping countdown timer - no end date or inactive subscription');
          _stopSponsorshipCountdownTimer();
        }
      } else {
        print('DEBUG: No active subscription or time remaining data');
        _sponsorshipSubscriptionData = SponsorshipSubscriptionTimeRemainingData(
          hasActiveSubscription: false,
          message: data['message'] ?? 'No active sponsorship subscription found',
        );
        _stopSponsorshipCountdownTimer();
      }
      
      setState(() {
        _sponsorshipSubscriptionError = null;
        _isLoadingSponsorshipSubscription = false;
      });
      
      print('DEBUG: Final _sponsorshipSubscriptionData: $_sponsorshipSubscriptionData');
    } catch (e) {
      print('DEBUG: Error parsing sponsorship subscription data: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      setState(() {
        _sponsorshipSubscriptionData = SponsorshipSubscriptionTimeRemainingData(
          hasActiveSubscription: false,
          message: 'Error parsing sponsorship subscription data',
        );
        _sponsorshipSubscriptionError = 'Failed to parse sponsorship subscription data: ${e.toString()}';
        _isLoadingSponsorshipSubscription = false;
      });
      _stopSponsorshipCountdownTimer();
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
      final end = endDate; // endDate is already a DateTime
      final difference = end.difference(now);
      
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
      final updatedRemainingTime = SubscriptionRemainingTime(
        days: days,
        hours: hours,
        minutes: minutes,
        formatted: formatted,
        percentageUsed: '${percentageUsed.toStringAsFixed(1)}%',
        endDate: endDate,
      );
      
      // Update the remaining time data
      setState(() {
        _remainingTimeData = SubscriptionRemainingTimeData(
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

  Future<void> _cancelSubscription() async {
    try {
      final response = await CompanySubscriptionService.cancelSubscription(
        branchId: widget.branchId ?? '',
      );
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
    // Check if branch ID is available
    if (widget.branchId == null || widget.branchId!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Column(
          children: [
            CompanyAppHeader(
              logoUrl: widget.logoUrl,
              userData: widget.userData,
              onAvatarTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CompanySettingsPage()),
                );
              },
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Branch ID Required',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please select a branch to view subscription information.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                    MaterialPageRoute(builder: (context) => const CompanySettingsPage()),
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
                        _buildSectionTitle('Company Subscriptions'),
                        // const SizedBox(height: 14),

                       

                        // Subscription Plans Grid
                        _buildSubscriptionPlansGrid(),

                        const SizedBox(height: 40),

                        // Time Remaining Section
                        _buildRemainingTimeWidget(),

                        const SizedBox(height: 40),

                        // Sponsorship Section
                        _buildSponsorshipSection(),

                        const SizedBox(height: 40),

                        _buildSponsorshipSubscriptionTimeWidget(),

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

  Widget _buildSponsorshipSection() {
    return Column(
      children: [
        _buildSectionTitle('Sponsorship'),
        const SizedBox(height: 24),
        
              
            
        Container(
          padding: const EdgeInsets.all(14),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sponsor as a Company',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2079C2),
                      ),
                    ),
                  ),
                     
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Boost your visibility with sponsorship options tailored for companies. Choose your duration, set your budget, and enjoy the flexibility to pause or resume anytime!',
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
                          _selectedSponsorshipId != null 
                            ? 'Get Sponsored Now!' 
                            : 'Select a sponsorship',
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
        
        const SizedBox(height: 40),
        
        // Sponsorship Subscription Section
        _buildSponsorshipSubscriptionSection(),
      ],
    );
  }

  Widget _buildSponsorshipSubscriptionSection() {
    // print('DEBUG: _buildSponsorshipSubscriptionSection called');
    // print('DEBUG: _sponsorshipSubscriptionData: $_sponsorshipSubscriptionData');
    // print('DEBUG: _isLoadingSponsorshipSubscription: $_isLoadingSponsorshipSubscription');
    // print('DEBUG: _sponsorshipSubscriptionError: $_sponsorshipSubscriptionError');
    
    // if (_sponsorshipSubscriptionData != null) {
    //   print('DEBUG: hasActiveSubscription: ${_sponsorshipSubscriptionData!.hasActiveSubscription}');
    //   print('DEBUG: timeRemaining: ${_sponsorshipSubscriptionData!.timeRemaining?.toJson()}');
    //   print('DEBUG: sponsorship: ${_sponsorshipSubscriptionData!.sponsorship?.toJson()}');
    //   print('DEBUG: entityInfo: ${_sponsorshipSubscriptionData!.entityInfo?.toJson()}');
    // }
    
    return Column(
      children: [
              
        if (_isLoadingSponsorshipSubscription)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_sponsorshipSubscriptionError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    'Error loading sponsorship subscription data',
                    style: TextStyle(color: Colors.red),
                  ),
                  TextButton(
                    onPressed: _loadSponsorshipSubscriptionData,
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_sponsorshipSubscriptionData == null || !_sponsorshipSubscriptionData!.hasActiveSubscription)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.grey[600],
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active Sponsorship Subscription',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You don\'t have an active sponsorship subscription for this branch.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadSponsorshipSubscriptionData,
                  child: Text('Refresh'),
                ),
              ],
            ),
          )
      ],
    );
  }

 

  Widget _buildTimeBox(String value, String label) {
    print('DEBUG: _buildTimeBox called with value: $value, label: $label');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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

  Widget _buildSponsorshipsGrid() {
    if (_sponsorships.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out sponsorships with empty IDs
    final validSponsorships = _sponsorships.where((sponsorship) => 
      sponsorship.id != null && sponsorship.id!.isNotEmpty
    ).toList();

    if (validSponsorships.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No valid sponsorships available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // Display sponsorships in a row similar to the screenshot
    return Row(
      children: validSponsorships.take(4).toList().asMap().entries.map((entry) {
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

    try {
      final response = await SponsorshipService.createCompanyBranchSponsorshipRequest(
        sponsorshipId: originalSponsorshipId,
        branchId: widget.branchId ?? '',
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
          
          // Refresh sponsorship subscription data
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
                'Request Sent Successfully!',
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
                        'The admin team will review your request and contact you within 24-48 hours.',
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
                  fontSize: 14,
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
        branchId: widget.branchId ?? '',
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.success) {
        // Show success dialog
        _showSuccessDialog();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
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

  Widget _buildRemainingTimeWidget() {
    // Check if we have either regular subscription or sponsorship subscription
    final hasRegularSubscription = _remainingTimeData?.hasActiveSubscription == true;
    final hasSponsorshipSubscription = _sponsorshipSubscriptionData?.hasActiveSubscription == true;
    
    // print('DEBUG: _buildRemainingTimeWidget called');
    // print('DEBUG: hasRegularSubscription: $hasRegularSubscription');
    // print('DEBUG: hasSponsorshipSubscription: $hasSponsorshipSubscription');
    // print('DEBUG: _remainingTimeData: $_remainingTimeData');
    // print('DEBUG: _sponsorshipSubscriptionData: $_sponsorshipSubscriptionData');
    
    // if (_sponsorshipSubscriptionData != null) {
    //   print('DEBUG: Sponsorship subscription data details:');
    //   print('DEBUG: - hasActiveSubscription: ${_sponsorshipSubscriptionData!.hasActiveSubscription}');
    //   print('DEBUG: - timeRemaining: ${_sponsorshipSubscriptionData!.timeRemaining?.toJson()}');
    //   print('DEBUG: - sponsorship: ${_sponsorshipSubscriptionData!.sponsorship?.toJson()}');
    // }
    
    if (!hasRegularSubscription && !hasSponsorshipSubscription) {
      print('DEBUG: No active subscriptions found, returning empty widget');
      return const SizedBox.shrink();
    }
    
    // print('DEBUG: Building remaining time widget with subscriptions');
    
    return Container(
      child: Column(
        children: [
          // Section title
          _buildSectionTitle('Time Left'),
          const SizedBox(height: 24),
          
          
          
          // Show regular subscription if available
          if (hasRegularSubscription) ...[
            _buildRegularSubscriptionTimeWidget(),
            const SizedBox(height: 4),
          ],
          
        
        ],
      ),
    );
  }

  Widget _buildRegularSubscriptionTimeWidget() {
    final remaining = _remainingTimeData!.remainingTime;
    if (remaining == null) return const SizedBox.shrink();
    
    final percentUsed = double.tryParse((remaining.percentageUsed ?? '0').replaceAll('%', '')) ?? 0;
    final percentLeft = 1 - (percentUsed / 100);
    
    return Container(
      
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
    );
  }

  Widget _buildSponsorshipSubscriptionTimeWidget() {
    // print('DEBUG: _buildSponsorshipSubscriptionTimeWidget called');
    final data = _sponsorshipSubscriptionData!;
    final timeRemaining = data.timeRemaining;
    
    // print('DEBUG: data: $data');
    // print('DEBUG: timeRemaining: $timeRemaining');
    // print('DEBUG: timeRemaining.toJson(): ${timeRemaining?.toJson()}');
    
    if (timeRemaining == null) {
      // print('DEBUG: No time remaining data, returning empty widget');
      return const SizedBox.shrink();
    }
    
    // print('DEBUG: Building sponsorship subscription widget with time remaining');
    // print('DEBUG: days: ${timeRemaining.days}, hours: ${timeRemaining.hours}, minutes: ${timeRemaining.minutes}');
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Text(
            'Sponsorship Subscription',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 20),
          
          // Time remaining display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeBox('${timeRemaining.days ?? 0}', 'Days'),
              _buildTimeBox('${timeRemaining.hours ?? 0}', 'Hours'),
              _buildTimeBox('${timeRemaining.minutes ?? 0}', 'Minutes'),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Formatted time display with countdown
          Center(
            child: Column(
              children: [
                Text(
                  _sponsorshipCurrentTimeDisplay.isNotEmpty 
                      ? _sponsorshipCurrentTimeDisplay 
                      : (timeRemaining.formatted ?? 'Time remaining not available'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                if (_sponsorshipCurrentTimeDisplay.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Live Countdown',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Sponsorship details
          if (data.sponsorship != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sponsorship Package',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.card_giftcard, color: Colors.green[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.sponsorship!.title ?? 'Unknown Package',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.green[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '\$${(data.sponsorship!.price ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Icon(Icons.schedule, color: Colors.green[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${data.sponsorship!.duration ?? 0} days',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
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

  void _startSponsorshipCountdownTimer() {
    print('DEBUG: Starting sponsorship countdown timer');
    // Cancel existing timer if any
    _sponsorshipCountdownTimer?.cancel();
    
    // Start new countdown timer that updates every second
    _sponsorshipCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sponsorshipSubscriptionData?.timeRemaining != null && mounted) {
        // Update the sponsorship remaining time data with current time
        _updateSponsorshipRemainingTime();
      } else {
        print('DEBUG: Stopping countdown timer - no time remaining data or widget not mounted');
        // Stop timer if no remaining time data or widget is disposed
        timer.cancel();
      }
    });
  }

  void _stopSponsorshipCountdownTimer() {
    _sponsorshipCountdownTimer?.cancel();
  }

  void _updateSponsorshipRemainingTime() {
    print('DEBUG: _updateSponsorshipRemainingTime called');
    if (_sponsorshipSubscriptionData?.timeRemaining == null) {
      print('DEBUG: No time remaining data, returning');
      return;
    }
    
    final remaining = _sponsorshipSubscriptionData!.timeRemaining!;
    final endDate = remaining.endDate;
    
    print('DEBUG: Updating with endDate: $endDate');
    
    if (endDate != null) {
      final now = DateTime.now();
      final end = endDate; // endDate is already a DateTime
      final difference = end.difference(now);
      
      print('DEBUG: Time difference: $difference');
      
      if (difference.isNegative) {
        // Sponsorship subscription has expired
        print('DEBUG: Subscription expired, stopping timer');
        _stopSponsorshipCountdownTimer();
        return;
      }
      
      // Calculate the remaining time values
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;
      
      print('DEBUG: Calculated time - days: $days, hours: $hours, minutes: $minutes, seconds: $seconds');
      
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
      
      print('DEBUG: Setting time display to: $timeDisplay');
      
      setState(() {
        _sponsorshipCurrentTimeDisplay = timeDisplay.trim();
      });
      
      // Calculate percentage used
      final totalDuration = _sponsorshipSubscriptionData?.subscription?.endDate != null && 
                           _sponsorshipSubscriptionData?.subscription?.startDate != null
          ? _sponsorshipSubscriptionData!.subscription!.endDate!.difference(_sponsorshipSubscriptionData!.subscription!.startDate!).inDays
          : 30; // Fallback to 30 days
      final usedDays = totalDuration - days;
      final percentageUsed = ((usedDays / totalDuration) * 100).clamp(0, 100);
      
      print('DEBUG: Percentage used: $percentageUsed%');
      
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
      
      print('DEBUG: Updated sponsorship subscription data');
    }
  }

  void _setSponsorshipEndDate(DateTime? endDate) {
    print('DEBUG: _setSponsorshipEndDate called with endDate: $endDate');
    _sponsorshipEndDate = endDate;
    if (endDate != null) {
      print('DEBUG: Starting sponsorship countdown timer');
      _startSponsorshipCountdownTimer();
    } else {
      print('DEBUG: Stopping sponsorship countdown timer');
      _stopSponsorshipCountdownTimer();
    }
  }
}