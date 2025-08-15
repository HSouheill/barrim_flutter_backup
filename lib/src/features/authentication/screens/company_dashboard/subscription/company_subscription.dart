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
  SubscriptionRemainingTimeData? _remainingTimeData; // <-- Add this line
  
  // Sponsorship state
  List<Sponsorship> _sponsorships = [];
  bool _isLoadingSponsorships = false;
  String? _sponsorshipError;
  SponsorshipPagination? _sponsorshipPagination;
  String? _selectedSponsorshipId;
  bool _isSubmittingSponsorship = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
    _loadSponsorships();
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
      final response = await SponsorshipService.getCompanyWholesalerSponsorships(
        page: 1,
        limit: 20,
      );

      print('Sponsorship API Response: $response');

      if (mounted) {
        print('Sponsorship response success: ${response['success']}');
        print('Sponsorship response data: ${response['data']}');
        
        // Debug: Check the raw sponsorships data
        if (response['data'] != null && response['data']['sponsorships'] != null) {
          final rawSponsorships = response['data']['sponsorships'] as List;
          print('Raw sponsorships from API:');
          for (int i = 0; i < rawSponsorships.length; i++) {
            final raw = rawSponsorships[i];
            print('  Sponsorship $i:');
            print('    Raw JSON: $raw');
            print('    ID field: ${raw['id']}');
            print('    _id field: ${raw['_id']}');
            print('    Title: ${raw['title']}');
          }
        }
        
        final sponsorships = SponsorshipService.parseSponsorships(response);
        print('Parsed sponsorships: ${sponsorships.map((s) => s.toJson()).toList()}');
        print('Number of parsed sponsorships: ${sponsorships.length}');
        
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
                        _buildRemainingTimeWidget(), // <-- Insert here
                        _buildSectionTitle('Company Subscriptions'),
                        // const SizedBox(height: 14),

                        // Subscription Plans Grid
                        _buildSubscriptionPlansGrid(),

                        const SizedBox(height: 40),

                        // Sponsorship Section
                        _buildSponsorshipSection(),

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
              Text(
                'Sponsor as a Company',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2079C2),
                ),
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
      ],
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
    print('Building sponsorships grid:');
    print('  Total sponsorships: ${_sponsorships.length}');
    print('  Sponsorship IDs: ${_sponsorships.map((s) => s.id).toList()}');
    
    if (_sponsorships.isEmpty) {
      print('  No sponsorships available');
      return const SizedBox.shrink();
    }

    // Filter out sponsorships with empty IDs
    final validSponsorships = _sponsorships.where((sponsorship) => 
      sponsorship.id != null && sponsorship.id!.isNotEmpty
    ).toList();
    
    print('  Valid sponsorships: ${validSponsorships.length}');
    print('  Valid sponsorship IDs: ${validSponsorships.map((s) => s.id).toList()}');

    if (validSponsorships.isEmpty) {
      print('  No valid sponsorships available');
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
    
    // Debug logging for sponsorship data
    print('Building sponsorship card:');
    print('  sponsorship.id: ${sponsorship.id}');
    print('  sponsorshipId: $sponsorshipId');
    print('  index: $index');
    print('  sponsorship.toJson(): ${sponsorship.toJson()}');
    
    // Create a unique identifier using both ID and index
    final uniqueId = '$sponsorshipId-$index';
    print('  uniqueId: $uniqueId');
    

    
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
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
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

    // Debug logging
    print('Submitting sponsorship request with:');
    print('  sponsorshipId: $originalSponsorshipId');
    print('  entityType: company_branch');
    print('  entityId: ${widget.branchId ?? "NULL"}');
    print('  entityName: ${widget.userData['businessName'] ?? widget.userData['name'] ?? "NULL"}');
    print('  userData keys: ${widget.userData.keys.toList()}');

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
      final response = await SponsorshipService.createSponsorshipSubscriptionRequest(
        sponsorshipId: originalSponsorshipId,
        entityType: 'company_branch',
        entityId: widget.branchId ?? '',
        entityName: widget.userData['businessName'] ?? widget.userData['name'] ?? 'Company',
      );

      // Debug logging
      print('API Response: $response');

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
        } else {
          print('API Error: ${response['message']}');
          print('API Error Details: ${response['error']}');
          
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
      print('Exception caught: $e');
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
      // Debug: Print branch ID and plan ID
      print('Branch ID: ${widget.branchId}');
      print('Plan ID: ${selectedPlan.id}');
      print('Plan Title: ${selectedPlan.title}');
      
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

  Widget _buildRemainingTimeWidget() {
    if (_remainingTimeData == null || !_remainingTimeData!.hasActiveSubscription!) {
      return SizedBox.shrink();
    }
    final remaining = _remainingTimeData!.remainingTime;
    if (remaining == null) return SizedBox.shrink();
    final percentUsed = double.tryParse((remaining.percentageUsed ?? '0').replaceAll('%', '')) ?? 0;
    final percentLeft = 1 - (percentUsed / 100);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[200]!),
                  ),
                  CircularProgressIndicator(
                    value: percentLeft * _progressAnimation.value,
                    strokeWidth: 10,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(percentLeft > 0.5 ? Colors.blue : percentLeft > 0.2 ? Colors.orange : Colors.red),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        remaining.formatted ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time Left',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subscription ends:', style: TextStyle(color: Colors.grey[700])),
                  Text(
                    remaining.endDate != null ? '${remaining.endDate}' : '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Used: ${remaining.percentageUsed ?? '-'}', style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _timeBox('${remaining.days ?? 0}', 'Days'),
                      _timeBox('${remaining.hours ?? 0}', 'Hours'),
                      _timeBox('${remaining.minutes ?? 0}', 'Min'),
                      _timeBox('${remaining.seconds ?? 0}', 'Sec'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBox(String value, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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