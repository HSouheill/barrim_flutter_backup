// Fix for serviceProvider_dashboard.dart
import 'dart:convert';

import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/service_provider_edit_profile.dart';
import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/service_provider_referrals.dart';
import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/serviceprovider_reviews.dart';
import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/serviceprovider_subscriptions/serviceprovider_subscription.dart';
import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../services/user_provider.dart';
import '../../../../services/route_tracking_service.dart';
import '../../../../models/service_provider.dart';
import '../../headers/service_provider_header.dart';
import '../company_dashboard/subscription/company_subscription.dart';
import 'my_booking.dart';
import '../login_page.dart';
import 'package:provider/provider.dart';

class ServiceproviderDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ServiceproviderDashboard({Key? key, required this.userData}) : super(key: key);

  @override
  State<ServiceproviderDashboard> createState() => _ServiceproviderDashboardState();
}

class _ServiceproviderDashboardState extends State<ServiceproviderDashboard> {
  ServiceProvider? serviceProvider;
  bool isLoading = true;
  String? error;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Track this route using the route tracking service
    RouteTrackingService.trackDashboardRoute(
      context,
      'serviceProvider',
      pageData: widget.userData,
    );
    
    _loadServiceProviderData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadServiceProviderData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final providerId = widget.userData['id'] ?? '';
      debugPrint('Loading provider with ID: $providerId');
      debugPrint('User data: ${widget.userData}');
      debugPrint('User data keys: ${widget.userData.keys.toList()}');
      debugPrint('User data serviceProviderId: ${widget.userData['serviceProviderId']}');

      // First try getting service provider details for logged-in provider
      try {
        final providerDetailsData = await ApiService.getServiceProviderDetails();
        
        if (providerDetailsData != null) {
          setState(() {
            serviceProvider = ServiceProvider.fromJson(providerDetailsData);

            // Initialize description controller with the description from the API
            // Check both possible locations for the description field
            String? description = serviceProvider?.serviceProviderInfo?.description;
            if (description == null && serviceProvider?.serviceProviderInfo != null) {
              // Try getting description from serviceProviderInfo if it exists there
              description = providerDetailsData['serviceProviderInfo']?['description'];
            }

            // Only use default if no description is found
            _descriptionController.text = description ?? 'I am an energetic driver with a passion for music, often playing upbeat tunes to make the ride enjoyable.';

            isLoading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('Failed to get service provider details: $e');
      }

      // If that fails, try getting by ID
      try {
        final providerData = await ApiService.getServiceProviderByIdFixed(providerId);
        
        if (providerData != null) {
          setState(() {
            serviceProvider = ServiceProvider.fromJson(providerData);

            // Check both possible locations for the description field
            String? description = serviceProvider?.serviceProviderInfo?.description;
            if (description == null && serviceProvider?.serviceProviderInfo != null) {
              // Try getting description from serviceProviderInfo if it exists there
              description = providerData['serviceProviderInfo']?['description'];
            }

            // Only use default if no description is found
            _descriptionController.text = description ?? 'No added description.';

            isLoading = false;
          });
        } else {
          setState(() {
            error = 'Provider data not found';
            isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          error = 'Error: $e';
          isLoading = false;
        });
        debugPrint('Error loading service provider data by ID: $e');
      }
    } catch (e) {
      setState(() {
        error = 'Unexpected error: $e';
        isLoading = false;
      });
      debugPrint('Unexpected error in load function: $e');
    }
  }

  // Function to force refresh data by clearing cache
  Future<void> _forceRefreshData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Clear any cached data
      await ApiService.clearServiceProviderCache();
      
      // Reload the data
      await _loadServiceProviderData();
    } catch (e) {
      debugPrint('Error in force refresh: $e');
      setState(() {
        isLoading = false;
        error = 'Error refreshing data: $e';
      });
    }
  }

  // Function to update description
  Future<void> _updateDescription(String newDescription) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Use the ApiService to update the description
      final success = await ApiService.updateServiceProviderDescription(newDescription);

      if (success) {
        // Update local state
        if (serviceProvider != null) {
          setState(() {
            // Update both possible locations for the description
            serviceProvider = serviceProvider!.copyWith(description: newDescription);
            isLoading = false;
          });

          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Description updated successfully')),
          // );

          // Clear the cached data to force fresh fetch next time
          await ApiService.clearServiceProviderCache();
        }
      } else {
        throw Exception('Failed to update description');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to update description: $e')),
      // );
    }
  }

  // Show dialog to edit description
  void _showEditDescriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Description'),
          content: TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              hintText: 'Enter your description',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateDescription(_descriptionController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066B3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String getLogoUrl() {
    if (serviceProvider?.logoPath != null && serviceProvider!.logoPath!.isNotEmpty) {
      return serviceProvider!.logoPath!.startsWith('http')
          ? serviceProvider!.logoPath!
          : '${ApiService.baseUrl}/${serviceProvider!.logoPath!}';
    }
    return 'assets/images/profile.png';
  }

  // Get the correct description with proper fallback logic
  // Fixed: Changed return type to String instead of String?
  String getDescription() {
    // First try the direct description field
    if (serviceProvider?.serviceProviderInfo?.description != null &&
        serviceProvider!.serviceProviderInfo!.description!.isNotEmpty) {
      return serviceProvider!.serviceProviderInfo!.description!;
    }

    // Next, try the serviceProviderInfo.description if it exists
    if (serviceProvider?.serviceProviderInfo != null) {
      // This would require accessing raw data or modifying the model
      // For now, we'll rely on the textController which was set during loading
      if (_descriptionController.text.isNotEmpty &&
          _descriptionController.text != 'No added description.') {
        return _descriptionController.text;
      }
    }

    // Last resort fallback
    return 'No added description.';
  }

  @override
  Widget build(BuildContext context) {
    final socialLinks = serviceProvider?.serviceProviderInfo?.socialLinks ?? {};
    
    if (error != null) {
      return Scaffold(body: _buildErrorView());
    }
    
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (serviceProvider == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'No Service Provider Data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'The data could not be loaded. Please try refreshing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _forceRefreshData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066B3),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry Loading'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      body: _buildDashboard(socialLinks),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Provider Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _forceRefreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066B3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(Map<String, String> socialLinks) {
    return Column(
      children: [
        // Header with logo and notification icons
        ServiceProviderHeader(
          serviceProvider: serviceProvider,
          isLoading: isLoading,
          onLogoNavigation: () {
            // Refresh the current dashboard page
            _forceRefreshData();
          },
          // onRefresh: _forceRefreshData,
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Service Types
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0066B3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Category',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      serviceProvider?.category ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0066B3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Service Type',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      serviceProvider?.serviceProviderInfo?.serviceType ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Details Section Header
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.blue)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Details',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.blue)),
                    ],
                  ),
                ),

                // Profile Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile photo, name and rating
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              getLogoUrl(),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, size: 40),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  serviceProvider?.fullName ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  getDescription(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    Icon(Icons.star_border, color: Colors.grey[400], size: 16),
                                    Icon(Icons.star_border, color: Colors.grey[400], size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${serviceProvider?.rating ?? '0'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: _showEditDescriptionDialog,  // Connect the Edit button to the dialog
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0066B3),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Edit',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
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

                      const SizedBox(height: 16),

                      // Experience
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.work, color: Colors.blue, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${serviceProvider?.serviceProviderInfo?.yearsExperience ?? '0'} Years of Experience',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Socials Section Header
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.blue)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Socials',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.blue)),
                    ],
                  ),
                ),

                // Social links
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                       _buildSocialLink(
                          icon: Icons.phone,
                          text: serviceProvider?.phone ?? 'N/A',
                          color: Colors.blue
                      ),
                        const SizedBox(height: 6),

                      _buildSocialLink(
                          icon: null,
                          customIcon: Padding(
                            padding: const EdgeInsets.all(0.0),
                            child: Image.asset(
                              'assets/icons/whatsapp.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                          text: serviceProvider?.phone ?? 'N/A',
                          color: Colors.blue
                      ),
                                             const SizedBox(height: 6),

                      const SizedBox(height: 12),
                      _buildSocialLink(
                          icon: null,
                          customIcon: Padding(
                            padding: const EdgeInsets.all(0.0),
                            child: Image.asset(
                              'assets/icons/instagram.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),                          text: socialLinks['instagram'] ?? 'N/A',
                          color: Colors.blue
                      ),
                                              const SizedBox(height: 6),

                      _buildSocialLink(
                          icon: null,
                          customIcon: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Image.asset(
                              'assets/icons/facebook.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                          text: socialLinks['facebook'] ?? 'N/A',
                          color: Colors.blue
                      ),
                                              const SizedBox(height: 6),

                      _buildSocialLink(
                          icon: Icons.language,
                          customIcon: null,
                          iconSize: 24,
                          text: socialLinks['website'] ?? 'N/A',
                          color: Colors.blue
                      ),
                      const SizedBox(height: 16),

                      // Edit button
                      SizedBox(
                        width: 140,
                        child: ElevatedButton(
                          onPressed: () {
                            if (serviceProvider != null) {
                              _showEditSocialsDialog();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0066B3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Edit Socials'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                const SizedBox(height: 16),
                _buildActionButton('My Bookings'),
                const SizedBox(height: 8),
                _buildActionButton('Review Checkup'),
                const SizedBox(height: 8),
                _buildActionButton('Referrals'),
                const SizedBox(height: 8),
                _buildActionButton('Subscriptions'),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildSocialLink({IconData? icon, Widget? customIcon, required String text, required Color color, double iconSize = 20}) {
    return Row(
      children: [
        customIcon ?? (icon != null ? Icon(icon, color: color, size: iconSize) : SizedBox(width: iconSize)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Fix for the _buildActionButton method in serviceProvider_dashboard.dart
  Widget _buildActionButton(String title) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0094FF),
            Color(0xFF05055A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (title == 'Review Checkup') {
              if (serviceProvider == null) {
                print('ERROR: ServiceProvider is null!');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ServiceProvider data not loaded')),
                );
                return;
              }
              final providerId = serviceProvider?.id ?? '';
              if (providerId.isEmpty) {
                print('ERROR: Provider ID is empty!');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: Provider ID is empty')),
                );
                return;
              }
              try {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServiceProviderReviews(
                      providerId: providerId,
                    ),
                  ),
                ).then((_) {
                  print('Returned from ServiceProviderReviews');
                }).catchError((error) {
                  print('Error navigating to ServiceProviderReviews: $error');
                });
              } catch (e) {
                print('Exception navigating to ServiceProviderReviews: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error navigating: $e')),
                );
              }
            } else if (title == 'My Bookings') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SPMyBookingsPage(),
                ),
              );
            } else if (title == 'Subscriptions') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServiceproviderSubscription(),
                ),
              );
              // Add navigation for subscriptions if needed
            } else if (title == 'Referrals') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServiceProviderReferrals(),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add this method to show the edit socials dialog
  void _showEditSocialsDialog() {
    final socialLinks = serviceProvider?.serviceProviderInfo?.socialLinks ?? {};
    final websiteController = TextEditingController(text: socialLinks['website'] ?? '');
    final facebookController = TextEditingController(text: socialLinks['facebook'] ?? '');
    final instagramController = TextEditingController(text: socialLinks['instagram'] ?? '');
    bool saving = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Social Links'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Website',
                        prefixIcon: Icon(Icons.language),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: facebookController,
                      decoration: const InputDecoration(
                        labelText: 'Facebook',
                        prefixIcon: Icon(Icons.facebook),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instagramController,
                      decoration: const InputDecoration(
                        labelText: 'Instagram',
                        prefixIcon: Icon(Icons.camera_alt),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() { saving = true; });
                          final success = await ApiService.updateServiceProviderSocialLinks(
                            website: websiteController.text,
                            facebook: facebookController.text,
                            instagram: instagramController.text,
                          );
                          if (success) {
                            await ApiService.clearServiceProviderCache();
                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   const SnackBar(content: Text('Social links updated successfully')),
                            // );
                            Navigator.of(context).pop();
                            await _loadServiceProviderData();
                          } else {
                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   const SnackBar(content: Text('Failed to update social links')),
                            // );
                            setState(() { saving = false; });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066B3),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Extension method for ServiceProvider class to provide copyWith functionality
extension ServiceProviderExtension on ServiceProvider {
  ServiceProvider copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    ServiceProviderInfo? serviceProviderInfo,
    String? logoPath,
    Location? location,
    double? rating,
    int? reviewCount,
    String? description,
    List<String>? availableWeekdays,
    List<String>? availableDays,
  }) {
    // Create a new ServiceProviderInfo with updated description if needed
    ServiceProviderInfo? updatedInfo;
    if (description != null && this.serviceProviderInfo != null) {
      updatedInfo = ServiceProviderInfo(
        serviceType: this.serviceProviderInfo!.serviceType,
        yearsExperience: this.serviceProviderInfo!.yearsExperience,
        customServiceType: this.serviceProviderInfo!.customServiceType,
        availableHours: this.serviceProviderInfo!.availableHours,
        availableDays: this.serviceProviderInfo!.availableDays,
        profilePhoto: this.serviceProviderInfo!.profilePhoto,
        description: description,
      );
    }

    return ServiceProvider(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      serviceProviderInfo: updatedInfo ?? this.serviceProviderInfo,
      logoPath: logoPath ?? this.logoPath,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      availableWeekdays: availableWeekdays ?? this.availableWeekdays,
      availableDays: availableDays ?? this.availableDays,
    );
  }

  
}