import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../headers/sidebar.dart';
import '../../../../../models/subscription.dart';
import '../../../../../models/sponsorship.dart';
import '../../../../../models/wholesaler_model.dart';

import '../../../../../services/wholesaler_service.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/sponsorship_service.dart';
import '../../../../../utils/subscription_provider.dart';
import 'package:provider/provider.dart';
import '../../../headers/wholesaler_header.dart';


class WholesalerSubscription extends StatefulWidget {
  const WholesalerSubscription({Key? key}) : super(key: key);

  @override
  State<WholesalerSubscription> createState() => _WholesalerSubscriptionState();
}

class _WholesalerSubscriptionState extends State<WholesalerSubscription> {
  bool _isSidebarOpen = false;
  String? _logoUrl;
  final WholesalerService _wholesalerService = WholesalerService();
  
  // Sponsorship state
  List<Sponsorship> _sponsorships = [];
  bool _isLoadingSponsorships = false;
  String? _sponsorshipError;
  SponsorshipPagination? _sponsorshipPagination;
  String? _selectedSponsorshipId;
  bool _isSubmittingSponsorship = false;
  String? _wholesalerId; // Add this to store the actual wholesaler ID
  String? _selectedBranchId; // Add this to store the selected branch ID
  List<Branch> _branches = []; // Add this to store the branches
  bool _isLoadingWholesalerData = true; // Add this to track loading state

  @override
  void initState() {
    super.initState();
    _initializeSubscriptionData();
    _loadWholesalerLogo();
    _loadBranches();
    _loadSponsorships();
  }

  Future<void> _loadWholesalerLogo() async {
    try {
      final wholesalerData = await _wholesalerService.getWholesalerData();
      if (wholesalerData != null && mounted) {
        // Store the wholesaler ID
        setState(() {
          _wholesalerId = wholesalerData.id;
          _isLoadingWholesalerData = false;
        });
        
        print('Wholesaler ID loaded: ${wholesalerData.id}');
        print('Wholesaler data: ${wholesalerData.toJson()}');
        
        // Convert logo URL to full URL if it's a relative path
        String? logoUrl = wholesalerData.logoUrl;
        if (logoUrl != null && logoUrl.isNotEmpty) {
          // If it's a relative path, convert to full URL
          if (logoUrl.startsWith('/') || logoUrl.startsWith('uploads/')) {
            logoUrl = '${ApiService.baseUrl}/$logoUrl';
          }
          // If it starts with file://, remove it and convert to full URL
          else if (logoUrl.startsWith('file://')) {
            logoUrl = logoUrl.replaceFirst('file://', '');
            if (logoUrl.startsWith('/')) {
              logoUrl = '${ApiService.baseUrl}$logoUrl';
            } else {
              logoUrl = '${ApiService.baseUrl}/$logoUrl';
            }
          }
        }
        setState(() {
          _logoUrl = logoUrl;
        });
      } else {
        print('No wholesaler data received');
        setState(() {
          _wholesalerId = null;
          _isLoadingWholesalerData = false;
        });
      }
    } catch (e) {
      print('Error loading wholesaler logo: $e');
      setState(() {
        _wholesalerId = null;
        _isLoadingWholesalerData = false;
      });
    }
  }

  Future<void> _refreshWholesalerData() async {
    setState(() {
      _isLoadingWholesalerData = true;
    });
    await _loadWholesalerLogo();
    await _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await _wholesalerService.getWholesalerBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
          // Select the first branch by default if available
          if (branches.isNotEmpty && _selectedBranchId == null) {
            _selectedBranchId = branches.first.id;
          }
        });
        print('Loaded ${branches.length} branches');
        if (branches.isNotEmpty) {
          print('Selected branch ID: $_selectedBranchId');
          print('Branch names: ${branches.map((b) => b.name).toList()}');
          print('Branch IDs: ${branches.map((b) => b.id).toList()}');
        }
      }
    } catch (e) {
      print('Error loading branches: $e');
      if (mounted) {
        setState(() {
          _branches = [];
        });
      }
    }
  }

  Future<void> _initializeSubscriptionData() async {
    final provider = context.read<SubscriptionProvider>();
    await provider.initialize();
    
    // Check if subscription was recently approved
    _checkSubscriptionApprovalStatus();
  }

  void _checkSubscriptionApprovalStatus() {
    // This method can be called to check if subscription was approved
    // You can integrate this with your backend API to check the actual status
    // For now, this is a placeholder that you can call when needed
    
    // Example usage:
    // if (subscriptionStatus == 'approved') {
    //   _showSubscriptionApprovedDialog();
    // }
  }

  // Call this method when you want to show the subscription approved dialog
  void showSubscriptionApprovedPopup() {
    _showSubscriptionApprovedDialog();
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

      if (mounted) {
        setState(() {
          _sponsorships = SponsorshipService.parseSponsorships(response);
          _sponsorshipPagination = SponsorshipService.parsePagination(response);
          _sponsorshipError = response['success'] == true ? null : response['message'];
          _isLoadingSponsorships = false;
        });
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

  Future<void> _handleSubscriptionRequest(SubscriptionPlan plan) async {
    try {
      final provider = context.read<SubscriptionProvider>();

      // If already subscribed, show info dialog and return
      if (provider.hasActiveSubscription) {
        _showActiveSubscriptionDialog();
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 30),
                Text(
                  'Processing subscription request...',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        },
      );

      final success = await provider.requestSubscription(
        planId: plan.id!,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (success) {
        _showSubscriptionDialog(plan.title ?? 'Unknown Plan',
            plan.price?.toString() ?? '0');
      } else {
        // Show info dialog if error is about pending subscription
        final errorMessage = provider.errorMessage ?? '';
        if (errorMessage.toLowerCase().contains('already have a pending subscription request')) {
          _showActiveSubscriptionDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      // Show info dialog if error is about pending subscription
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('already have a pending subscription request')) {
        _showActiveSubscriptionDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showConfirmationDialog(SubscriptionPlan plan) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Confirm Subscription',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2079C2),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to subscribe to:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title ?? 'Unknown Plan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2079C2),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Price: \$${plan.price?.toString() ?? '0'}',
                      style: TextStyle(fontSize: 14),
                    ),
                    if (plan.duration != null) ...[
                      SizedBox(height: 5),
                      Text(
                        'Duration: ${plan.duration} days',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 15),
              Text(
                'After confirmation, you will need to contact us for payment details.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2079C2),
                foregroundColor: Colors.white,
              ),
              child: Text('Confirm'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<File?> _pickPaymentProofImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<bool> _showPaymentProofDialog(SubscriptionPlan plan) async {
    File? selectedImage;
    
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Upload Payment Proof',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2079C2),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please upload a screenshot or photo of your payment proof for:',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title ?? 'Unknown Plan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2079C2),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Price: \$${plan.price?.toString() ?? '0'}',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Image picker section
                  if (selectedImage == null) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        final image = await _pickPaymentProofImage();
                        if (image != null) {
                          setState(() {
                            selectedImage = image;
                          });
                        }
                      },
                      icon: Icon(Icons.upload_file),
                      label: Text('Select Payment Proof'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2079C2),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedImage = null;
                            });
                          },
                          child: Text('Change Image'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final image = await _pickPaymentProofImage();
                            if (image != null) {
                              setState(() {
                                selectedImage = image;
                              });
                            }
                          },
                          child: Text('Select Different'),
                        ),
                      ],
                    ),
                  ],
                  
                  SizedBox(height: 15),
                  Text(
                    'Note: Payment proof is optional but recommended for faster processing.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2079C2),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    ) ?? false;
  }

  void _showActiveSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange,
                size: 50,
              ),
              SizedBox(height: 10),
              Text(
                'Subscription In Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2079C2),
                ),
              ),
            ],
          ),
          content: Text(
            'You are already in the subscription process.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Clear error and refresh data
                final provider = context.read<SubscriptionProvider>();
                provider.clearError();
                provider.initialize();
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF2079C2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCancelSubscription() async {
    try {
      final provider = context.read<SubscriptionProvider>();
      
      // Show confirmation dialog
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Cancel Subscription',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel your current subscription? This action cannot be undone.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Keep Subscription',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Cancel Subscription'),
              ),
            ],
          );
        },
      ) ?? false;

      if (!shouldCancel) return;

      final success = await provider.cancelSubscription();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMessage = provider.errorMessage ?? 'Failed to cancel subscription';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              Column(
                children: [
                           WholesalerHeader(logoUrl: _logoUrl),

                  Expanded(
                    child: provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : provider.hasError
                        ? SizedBox.shrink()
                        : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),

                          _buildSectionTitle('Wholesaler Subscriptions'),
                          const SizedBox(height: 24),

                          // Subscription plans in horizontal layout
                          if (provider.availablePlans.isNotEmpty) ...[
                            _buildSubscriptionPlansRow(provider),
                            const SizedBox(height: 40),
                          ] else ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  'No subscription plans available at the moment',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],

                          // Time Left Section - Only show if user has active subscription
                          if (provider.hasActiveSubscription) ...[
                            _buildTimeLeftSection(provider),
                            const SizedBox(height: 40),

                          ],

                          // Sponsorship Section
                          _buildSponsorshipSection(),

                          const SizedBox(height: 40),
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
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionPlansRow(SubscriptionProvider provider) {
    final sortedPlans = provider.getPlansSortedByDuration();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 140 / 180,
      ),
      itemCount: sortedPlans.length,
      itemBuilder: (context, index) {
        final plan = sortedPlans[index];

        return _buildCompactSubscriptionCard(
          plan.title ?? 'Unknown Plan',
          plan.price?.toString() ?? '0',
          _parseBenefits(plan.benefits),
          onTap: () => _handleSubscriptionRequest(plan),
          duration: plan.duration,
        );
      },
    );
  }

  Widget _buildTimeLeftSection(SubscriptionProvider provider) {
    final remainingTime = provider.formattedRemainingTime;
    final progress = provider.subscriptionProgress;
    final progressValue = (double.tryParse(progress ?? '0') ?? 0) / 100;

    return Column(
      children: [
        _buildSectionTitle('Time Left'),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
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
              // Custom circular progress with partial circle design
              SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: CircularTimerPainter(
                    progress: 1 - progressValue, // Reverse for countdown
                    isExpiringSoon: provider.isExpiringSoon,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          remainingTime ?? '0D:0H:0M',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Cancel subscription button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: provider.isCancellingSubscription 
                    ? null 
                    : () => _handleCancelSubscription(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: provider.isCancellingSubscription
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Cancelling...'),
                        ],
                      )
                    : const Text(
                        'Cancel Subscription',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
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
                'Sponsor as a Wholesaler',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2079C2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Boost your visibility with sponsorship options tailored for wholesalers. Choose your duration, set your budget, and enjoy the flexibility to pause or resume anytime!',
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
              else if (_isLoadingWholesalerData)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading wholesaler data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_branches.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.store,
                          size: 48,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No branches available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'You need to create at least one branch to apply for sponsorship',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_selectedBranchId == null || _selectedBranchId!.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No branch selected',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadBranches,
                          child: Text('Refresh Branches'),
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
              
              // Branch selection dropdown (if multiple branches)
              if (_branches.length > 1) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Branch for Sponsorship',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedBranchId,
                        decoration: InputDecoration(
                          labelText: 'Branch',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: _branches.map((branch) {
                          return DropdownMenuItem<String>(
                            value: branch.id,
                            child: Text(branch.name),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedBranchId = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_branches.length == 1) ...[
                // Show selected branch info when there's only one
                
                const SizedBox(height: 16),
              ],
              
              // Get Sponsored button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(70),
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
                  child: ElevatedButton(
                    onPressed: (_selectedSponsorshipId != null && _selectedBranchId != null && _selectedBranchId!.isNotEmpty)
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
                            'Get Sponsored Now!' ,
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
      // Check if we have the branch ID
      if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
        throw Exception('No branch selected. Please try again.');
      }

      print('Submitting sponsorship request with branch ID: $_selectedBranchId');

      final response = await SponsorshipService.createSponsorshipSubscriptionRequest(
        sponsorshipId: originalSponsorshipId,
        entityType: 'wholesaler_branch',
        entityId: _selectedBranchId!, // Use the selected branch ID
        entityName: 'Wholesaler Branch',
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
                  Icons.check_circle,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Request Sent Successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                                const SizedBox(height: 16),
                // Show sponsorship details
                if (sponsorship.id != null && sponsorship.id!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Details:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.card_giftcard, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sponsorship.title ?? 'Unknown Package',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.attach_money, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              '\$${(sponsorship.price ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 16),
                            Icon(Icons.schedule, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              '${sponsorship.duration ?? 0} days',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The admin team will review your request and contact you within 24-48 hours.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                  fontSize: 20,
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

  void _showSubscriptionApprovedDialog() {
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
                  Icons.celebration,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Subscription Approved!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Congratulations! Your subscription request has been approved by the admin team.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[300],
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your subscription is now active',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.orange[300],
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can now access all premium features',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Refresh subscription data to show updated status
                    _initializeSubscriptionData();
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
                    'Great!',
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


  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  List<String> _parseBenefits(dynamic benefits) {
    if (benefits == null) return ['No benefits listed'];

    // Handle string benefits
    if (benefits is String) return [benefits];

    // Handle map with 'value' key
    if (benefits is Map && benefits['value'] != null) {
      final value = benefits['value'];
      if (value is List) {
        return _parseBenefitList(value);
      }
      return [value.toString()];
    }

    // Handle direct list
    if (benefits is List) {
      return _parseBenefitList(benefits);
    }

    return ['No benefits listed'];
  }

  List<String> _parseBenefitList(List benefits) {
    final List<String> parsedBenefits = [];

    for (var item in benefits) {
      if (item is Map) {
        // Handle key-value pairs
        if (item.containsKey('Key') && item.containsKey('Value')) {
          final key = item['Key']?.toString() ?? '';
          final value = item['Value']?.toString() ?? '';
          if (key.isNotEmpty && value.isNotEmpty) {
            parsedBenefits.add('$key: $value');
          }
        } else if (item.containsKey('feature') && item.containsKey('description')) {
          // Handle feature-description pairs
          final feature = item['feature']?.toString() ?? '';
          final description = item['description']?.toString() ?? '';
          if (feature.isNotEmpty) {
            parsedBenefits.add(description.isNotEmpty ? '$feature: $description' : feature);
          }
        } else if (item.containsKey('title') && item.containsKey('description')) {
          // Handle title-description pairs
          final title = item['title']?.toString() ?? '';
          final description = item['description']?.toString() ?? '';
          if (title.isNotEmpty) {
            parsedBenefits.add(description.isNotEmpty ? '$title: $description' : title);
          }
        }
      } else if (item is List) {
        // Recursively handle nested lists
        parsedBenefits.addAll(_parseBenefitList(item));
      } else if (item != null) {
        // Handle simple values
        parsedBenefits.add(item.toString());
      }
    }

    return parsedBenefits.isEmpty ? ['No benefits listed'] : parsedBenefits;
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


  void _showSubscriptionDialog(String plan, String price) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 50,
              ),
              const SizedBox(height: 10),
              Text(
                'Subscription Request Sent!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2079C2),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your request for the $plan plan (\$$price) has been sent to the Barrim team.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2079C2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone, color: Color(0xFF2079C2)),
                        const SizedBox(width: 8),
                        Text(
                          '81004114',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2079C2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Contact us for payment details and subscription activation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF2079C2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildCompactSubscriptionCard(
      String title,
      String price,
      List<String> benefits, {
        VoidCallback? onTap,
        int? duration,
      }) {

    // Determine background based on plan type
    Color buttonForegroundColor = Colors.white; // Default button foreground color

    if (title.toLowerCase().contains('monthly')) {
      return Container(
        width: 140,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),],
          image: const DecorationImage(
            image: AssetImage('assets/images/monthly_subscription.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Benefits
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: benefits.take(3).map((benefit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            benefit,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),

              // Join button
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: buttonForegroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Join for only \$${price}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (title.toLowerCase().contains('6 month')) {
      buttonForegroundColor = const Color(0xFF2196F3);
      return Container(
        width: 140,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),],
          image: const DecorationImage(
            image: AssetImage('assets/images/6months_subscription.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Benefits
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: benefits.take(3).map((benefit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            benefit,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),

              // Join button
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: buttonForegroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Join for only \$${price}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (title.toLowerCase().contains('yearly')) {
      BoxDecoration cardDecoration = BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)], // Blue gradient
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      );
      buttonForegroundColor = Colors.white; // White color for visibility on blue gradient and image
      return Container(
        width: 140,
        height: 180,
        decoration: cardDecoration, // Apply the decoration with gradient and shadow
        child: Stack(
          children: [
            // Image on top of the gradient
            Positioned.fill(
              child: Image.asset(
                'assets/images/yearly_subscription.png',
                fit: BoxFit.cover,
              ),
            ),
            // Foreground content (Title, Benefits, Button)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Benefits
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: benefits.take(3).map((benefit) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                benefit,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),

                  // Join button
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: buttonForegroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Join for only \$${price}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // For Monthly, 6 Months, and default cases
      String backgroundImage = 'assets/images/monthly_subscription.png'; // Default or fallback
      // Default white color
      return Container(
        width: 140,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),],
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Benefits
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: benefits.take(3).map((benefit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            benefit,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),

              // Join button
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: buttonForegroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Join for only \$${price}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

// Add this custom painter class to create the circular timer design
class CircularTimerPainter extends CustomPainter {
  final double progress;
  final bool isExpiringSoon;

  CircularTimerPainter({
    required this.progress,
    required this.isExpiringSoon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background circle (light gray)
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = isExpiringSoon ? Colors.orange : const Color(0xFF2196F3)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the progress arc (starting from top)
    const startAngle = -pi / 2; // Start from top
    final sweepAngle = 2 * pi * progress; // Progress amount

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}