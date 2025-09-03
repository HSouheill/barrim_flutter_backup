import 'package:barrim/src/features/authentication/screens/workers/worker_profile_view.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barrim/src/services/api_service.dart';
import '../user_dashboard/notification.dart' as notification;
import '../user_dashboard/home.dart';
import '../booking/myboooking.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import '../category/categories.dart';
import 'workers_filter.dart';
import 'package:barrim/src/components/secure_network_image.dart';
import 'package:barrim/src/utils/authService.dart';

class DriversGuidesPage extends StatefulWidget {
  const DriversGuidesPage({Key? key}) : super(key: key);

  @override
  _DriversGuidesPageState createState() => _DriversGuidesPageState();
}

class _DriversGuidesPageState extends State<DriversGuidesPage> {
  bool _isSidebarOpen = false;
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _serviceProviders = [];
  String? _profileImagePath;

  Map<String, String> _providerLogos = {};

  // Map to store providers by their service type
  Map<String, List<dynamic>> _categorizedProviders = {};
  // List to track category order for display
  List<String> _categoryOrder = [];
  ServiceProviderFilters _filters = ServiceProviderFilters();

  @override
  void initState() {
    super.initState();
    _loadServiceProviders();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData != null && userData['profilePic'] != null) {
        setState(() {
          _profileImagePath = ApiService.getImageUrl(userData['profilePic']);
          print('Profile Image Path: $_profileImagePath');
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  // Format profile photo URL with improved debugging
  String _formatProfilePhotoUrl(dynamic provider) {
    String? photoPath;

    // Check for logo field first (this is the actual field name in the API response)
    if (provider['logo'] != null && provider['logo'].toString().isNotEmpty) {
      photoPath = provider['logo'].toString();
      print('Found logo: $photoPath');
    }
    // Check for logoPath as fallback
    else if (provider['logoPath'] != null && provider['logoPath'].toString().isNotEmpty) {
      photoPath = provider['logoPath'].toString();
      print('Found logoPath: $photoPath');
    }

    // If still nothing, use default image
    if (photoPath == null || photoPath.isEmpty) {
      print('No profile photo found for provider: ${provider['fullName'] ?? "Unknown"}');
      return 'assets/logo/barrim_logo1.png'; // Return default image path instead of empty string
    }

    // If it's already a full URL, fix the duplicate uploads issue
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      // Fix the duplicate uploads/ issue
      return photoPath.replaceAll('/uploads/', '/uploads/');
    }

    // If it's a local asset
    if (photoPath.startsWith('assets/')) {
      return photoPath;
    }

    // Construct the correct URL - remove any duplicate 'uploads/' prefix
    final baseUrl = ApiService.baseUrl;

    // Clean up the path - remove leading slashes and duplicate uploads
    String cleanPath = photoPath.replaceAll(RegExp(r'^/+'), '')
        .replaceAll('uploads/', '');

    // For service provider images, they're in the serviceprovider subdirectory
    if (!cleanPath.startsWith('serviceprovider/')) {
      cleanPath = 'serviceprovider/$cleanPath';
    }

    return '$baseUrl/uploads/$cleanPath';
  }

  // Load service providers from API
  Future<void> _loadServiceProviders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Try to fetch service providers
      List<dynamic> providers = [];
      try {
        providers = await ApiService.getAllServiceProviders();
        print('Fetched ${providers.length} providers'); // Debug log
        
        // Debug: Print first provider structure
        if (providers.isNotEmpty) {
          print('First provider structure: ${providers[0]}');
          print('First provider serviceProviderInfo: ${providers[0]['serviceProviderInfo']}');
          print('First provider status: ${providers[0]['status']}');
          print('First provider serviceProviderInfo status: ${providers[0]['serviceProviderInfo']?['status']}');
        }

        // Filter out providers with status 'pending' or 'rejected'
        print('Total providers before filtering: ${providers.length}');
        providers = providers.where((provider) {
          // Use ONLY the root level status, ignore serviceProviderInfo status
          final status = provider['status'];
          String displayName = provider['fullName'] ?? provider['businessName'] ?? 'Unknown';
          print('Provider: $displayName, Root Status: $status');
          if (status != 'active') return false;
          return true;
        }).toList();
        print('Active providers after filtering: ${providers.length}');

        // Fetch logos for each provider
        await _fetchProviderLogos(providers);

        if (providers.isNotEmpty) {
          print('First provider data: ${providers[0]}'); // Debug log
        }
      } catch (e) {
        print('API error: $e');
      }

      // Store the original providers list
      setState(() {
        _serviceProviders = providers;
        _isLoading = false;
      });

      // Apply any existing filters
      if (_filters.selectedSkills.isNotEmpty || _filters.sortOption != null || _filters.emergencyOnly) {
        _applyFilters();
      } else {
        // If no filters, just categorize the providers
        _categorizeProviders(providers);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load service providers: ${e.toString()}';
      });
      print('Error loading service providers: $e');
    }
  }

  Future<void> _fetchProviderLogos(List<dynamic> providers) async {
    Map<String, String> providerLogos = {};

    for (var provider in providers) {
      String providerId = provider['_id'] ?? provider['id'] ?? '';
      if (providerId.isNotEmpty) {
        try {
          String? logoUrl = await ApiService.getServiceProviderLogo(providerId);
          if (logoUrl != null && logoUrl.isNotEmpty) {
            providerLogos[providerId] = logoUrl;
            print('Fetched logo for provider $providerId: $logoUrl');
          }
        } catch (e) {
          print('Error fetching logo for provider $providerId: $e');
        }
      }
    }

    setState(() {
      _providerLogos = providerLogos;
    });
  }

  // Get logo for a specific provider
  String getProviderLogoUrl(dynamic provider) {
    String providerId = provider['_id'] ?? provider['id'] ?? '';

    // Check if we have a logo in our cache
    if (providerId.isNotEmpty && _providerLogos.containsKey(providerId)) {
      return _providerLogos[providerId]!;
    }

    // Fallback options if no custom logo was found
    // Check for logo field first (this is the actual field name in the API response)
    if (provider['logo'] != null && provider['logo'].toString().isNotEmpty) {
      String logoPath = provider['logo'].toString();
      return logoPath.startsWith('http') ? logoPath : 'https://barrim.online/$logoPath';
    }
    // Check for logoPath as fallback
    else if (provider['logoPath'] != null && provider['logoPath'].toString().isNotEmpty) {
      String logoPath = provider['logoPath'].toString();
      return logoPath.startsWith('http') ? logoPath : 'https://barrim.online/$logoPath';
    }

    // If still no logo, return default
    return '';
  }


  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  Widget _buildSidebar() {
    return Container(
      width: 199,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2079C2),
            Color(0xFF1F4889),
            Color(0xFF10105D),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(5, 0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(top: 30),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset('assets/logo/sidebar_logo.png', width: 50, height: 50),
                      Text(
                        'Barrim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                ListTile(
                  leading: Icon(Icons.home, color: Colors.white),
                  title: Text('Home', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const UserDashboard(userData: {})),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.category, color: Colors.white),
                  title: Text('Categories', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const CategoriesPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.white),
                  title: Text('Workers', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                  },
                ),
                // ListTile(
                //   leading: Icon(Icons.book_online, color: Colors.white),
                //   title: Text('Bookings', style: TextStyle(color: Colors.white)),
                //   onTap: () {
                //     _toggleSidebar();
                //     Future.delayed(const Duration(milliseconds: 300), () {
                //       Navigator.of(context).pushReplacement(
                //         MaterialPageRoute(builder: (context) => const MyBookingsPage()),
                //       );
                //     });
                //   },
                // ),
                ListTile(
                  leading: Icon(Icons.share, color: Colors.white),
                  title: Text('Referral', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const ReferralPointsPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.white),
                  title: Text('Settings', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.blue),
                      title: Text('Logout', style: TextStyle(color: Colors.blue)),
                      onTap: () async {
                        _toggleSidebar();
                        await AuthService().logout();
                        Future.delayed(const Duration(milliseconds: 300), () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              DriversGuidesHeader(
                onMenuTap: _toggleSidebar,
                onNotificationTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => notification.NotificationsPage(),
                    ),
                  );
                },
                onFilterTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FilterPage(
                        initialFilters: _filters,
                        onApplyFilters: _handleFilterApply,
                      ),
                    ),
                  );
                },
                profileImagePath: _profileImagePath,
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage))
                    : _serviceProviders.isEmpty
                    ? Center(child: Text('No service providers found'))
                    : RefreshIndicator(
                  onRefresh: _loadServiceProviders,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                                         child: Column(
                       children: [
                         // Debug: Show category information
                         if (_categoryOrder.isEmpty)
                           Padding(
                             padding: const EdgeInsets.all(16.0),
                             child: Center(
                               child: Column(
                                 children: [
                                   Text('Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                                   Text('Total providers: ${_serviceProviders.length}'),
                                   Text('Categories: ${_categoryOrder.length}'),
                                   Text('Categorized providers: ${_categorizedProviders.keys.toList()}'),
                                 ],
                               ),
                             ),
                           ),
                         // Display all categories
                         ..._categoryOrder.map((category) => _buildCategorySection(category)).toList(),

                         SizedBox(height: 20), // Bottom padding
                       ],
                     ),
                  ),
                ),
              ),
            ],
          ),

          // Semi-transparent overlay when sidebar is open
          if (_isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),

          // Sidebar
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _isSidebarOpen ? 0 : -250,
            top: 0,
            bottom: 0,
            child: _buildSidebar(),
          ),
        ],
      ),

    );
  }

  // Build a category section
  Widget _buildCategorySection(String category) {
    List<dynamic> providersInCategory = _categorizedProviders[category] ?? [];
    
    // Debug logging
    print('Building category section for: $category');
    print('Providers in category: ${providersInCategory.length}');
    if (providersInCategory.isNotEmpty) {
      print('First provider in category: ${providersInCategory[0]}');
    }

    return Column(
      children: [
        // Category header
        SectionHeader(title: category),

        // Display providers in this category
        providersInCategory.isEmpty
            ? Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(child: Text('No $category available')),
        )
            : Column(
          children: providersInCategory.map((provider) {
            // Calculate the image path here
            String providerImagePath = _formatProfilePhotoUrl(provider);
            
            // Debug logging for each provider
            String displayName = provider['fullName'] ?? provider['businessName'] ?? 'Unknown';
            print('Building ProfileCard for provider: $displayName');
            print('Provider data: $provider');

            return ProfileCard(
              name: provider['fullName'] ?? provider['businessName'] ?? 'Unknown',
              isVerified: _getYearsExperience(_getYearsExperienceFromProvider(provider)) > 5,
              experience: "${_getYearsExperience(_getYearsExperienceFromProvider(provider))} Years of Experience",
              description: _getProviderDescription(provider, category),
              rating: _getProviderRating(provider),
              imagePath: providerImagePath,
              onMessage: () {},
                             onView: () {
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => ServiceProviderProfile(
                       provider: provider, // Pass the full provider data
                       providerId: provider['_id'] ?? provider['id'],
                       logoUrl: providerImagePath, // Use the local variable we created above
                     ),
                   ),
                 );
               },
              provider: provider,
            );
          }).toList(),
        ),

        // "View more" button if there are more than 2 providers
        // if (providersInCategory.length > 2) ViewMoreButton(),
      ],
    );
  }

  // Helper method to get custom description based on provider info
  String _getProviderDescription(dynamic provider, String category) {
    // Try to get a description from provider data
    String? description;

    if (provider['serviceProviderInfo'] != null) {
      description = provider['serviceProviderInfo']['description']?.toString();

      if (description == null || description.isEmpty) {
        description = provider['serviceProviderInfo']['bio']?.toString();
      }
    }

    if (description == null || description.isEmpty) {
      description = provider['description']?.toString();
    }

    if (description == null || description.isEmpty) {
      description = provider['bio']?.toString();
    }

    // If no description found, create a generic one
    if (description == null || description.isEmpty) {
      String categoryLower = category.toLowerCase();
      String providerName = provider['fullName'] ?? provider['businessName'] ?? 'service provider';
      
      if (categoryLower == 'other') {
        return "$providerName is a professional service provider with experience in their field.";
      } else {
        return "$providerName is a professional $categoryLower with experience in service.";
      }
    }

    return description;
  }

  // Helper method to get provider rating
  int _getProviderRating(dynamic provider) {
    dynamic rating;

    if (provider['serviceProviderInfo'] != null) {
      rating = provider['serviceProviderInfo']['rating'];
    }

    if (rating == null) {
      rating = provider['rating'];
    }

    // Try to parse as number
    if (rating is num) {
      return rating.round();
    } else if (rating is String) {
      return double.tryParse(rating)?.round() ?? 4;
    }

    return 4; // Default rating
  }

  // Helper method to get years of experience from provider data
  dynamic _getYearsExperienceFromProvider(dynamic provider) {
    // First check serviceProviderInfo.yearsExperience
    if (provider['serviceProviderInfo'] != null && 
        provider['serviceProviderInfo']['yearsExperience'] != null) {
      return provider['serviceProviderInfo']['yearsExperience'];
    }
    
    // Fallback to root level yearsExperience
    if (provider['yearsExperience'] != null) {
      return provider['yearsExperience'];
    }
    
    // Default to 1 if no experience data found
    return 1;
  }

  // Helper method to get years of experience as int
  int _getYearsExperience(dynamic yearsExp) {
    if (yearsExp == null) {
      return 1; // Default value if null
    }
    if (yearsExp is int) {
      return yearsExp;
    } else if (yearsExp is String) {
      return int.tryParse(yearsExp) ?? 1;
    } else if (yearsExp is double) {
      return yearsExp.round();
    }
    return 1; // Default value
  }

  // Add filter handling method
  void _handleFilterApply(ServiceProviderFilters newFilters) {
    setState(() {
      _filters = newFilters;
      _applyFilters();
    });
  }

  // Helper method to categorize providers
  void _categorizeProviders(List<dynamic> providers) {
    Map<String, List<dynamic>> categorizedProviders = {};
    List<String> categoryOrder = [];

    for (var provider in providers) {
      String serviceType = 'Other'; // Default category

      // Try to get service type from multiple sources
      if (provider['serviceType'] != null && provider['serviceType'].toString().isNotEmpty) {
        serviceType = provider['serviceType'].toString();
      } else if (provider['serviceProviderInfo'] != null &&
          provider['serviceProviderInfo']['serviceType'] != null) {
        serviceType = provider['serviceProviderInfo']['serviceType'].toString();
      } else if (provider['category'] != null && 
                 provider['category'].toString().isNotEmpty) {
        // Use the root level category field as fallback
        serviceType = provider['category'].toString();
      }

      // Convert to title case for display
      String displayServiceType = serviceType.split(' ')
          .map((word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '')
          .join(' ');

      // Ensure we have a valid category name
      if (displayServiceType.isEmpty) {
        displayServiceType = 'Other';
      }

      // Add to the category map
      if (!categorizedProviders.containsKey(displayServiceType)) {
        categorizedProviders[displayServiceType] = [];
        categoryOrder.add(displayServiceType);
      }

      categorizedProviders[displayServiceType]!.add(provider);
    }

    setState(() {
      _categorizedProviders = categorizedProviders;
      _categoryOrder = categoryOrder;
    });
    
    // Debug: Print categorization results
    print('Categorized providers: $_categorizedProviders');
    print('Category order: $_categoryOrder');
  }

  // Update filter application method
  void _applyFilters() {
    if (_serviceProviders.isEmpty) return;

    print('Applying filters: ${_filters.toJson()}'); // Debug log

    // Create a filtered copy of providers
    List<dynamic> filteredProviders = List.from(_serviceProviders);

    // Apply skill filters
    if (_filters.selectedSkills.isNotEmpty) {
      print('Filtering by skills: ${_filters.selectedSkills}'); // Debug log
      filteredProviders = filteredProviders.where((provider) {
        // Get service type from root level first, then fallback to serviceProviderInfo
        String serviceType = provider['serviceType']?.toString().toLowerCase() ?? 
                           provider['serviceProviderInfo']?['serviceType']?.toString().toLowerCase() ?? '';
        bool matches = _filters.selectedSkills.any((skill) => 
          serviceType.contains(skill.toLowerCase()));
        print('Provider $serviceType matches skills: $matches'); // Debug log
        return matches;
      }).toList();
    }

    // Apply emergency filter
    if (_filters.emergencyOnly) {
      print('Filtering emergency only'); // Debug log
      filteredProviders = filteredProviders.where((provider) {
        // Get service type from root level first, then fallback to serviceProviderInfo
        String serviceType = provider['serviceType']?.toString().toLowerCase() ?? 
                           provider['serviceProviderInfo']?['serviceType']?.toString().toLowerCase() ?? '';
        bool isDriver = serviceType == 'driver';
        print('Provider is driver: $isDriver'); // Debug log
        return isDriver;
      }).toList();
    }

    // Apply sorting
    if (_filters.sortOption != null) {
      print('Sorting by: ${_filters.sortOption}'); // Debug log
      switch (_filters.sortOption) {
        case SortOption.highToLow:
          filteredProviders.sort((a, b) {
            double ratingA = (a['rating'] ?? 0).toDouble();
            double ratingB = (b['rating'] ?? 0).toDouble();
            return ratingB.compareTo(ratingA);
          });
          break;
        case SortOption.lowToHigh:
          filteredProviders.sort((a, b) {
            double ratingA = (a['rating'] ?? 0).toDouble();
            double ratingB = (b['rating'] ?? 0).toDouble();
            return ratingA.compareTo(ratingB);
          });
          break;
        case SortOption.closest:
          // TODO: Implement location-based sorting when location data is available
          break;
        case SortOption.emergency:
          // Sort drivers to the top
          filteredProviders.sort((a, b) {
            String serviceTypeA = a['serviceType']?.toString().toLowerCase() ?? 
                                 a['serviceProviderInfo']?['serviceType']?.toString().toLowerCase() ?? '';
            String serviceTypeB = b['serviceType']?.toString().toLowerCase() ?? 
                                 b['serviceProviderInfo']?['serviceType']?.toString().toLowerCase() ?? '';
            bool isDriverA = serviceTypeA == 'driver';
            bool isDriverB = serviceTypeB == 'driver';
            return isDriverB ? 1 : (isDriverA ? -1 : 0);
          });
          break;
        default:
          break;
      }
    }

    print('Filtered providers count: ${filteredProviders.length}'); // Debug log

    // Categorize the filtered providers
    _categorizeProviders(filteredProviders);
  }

  // Add toJson method to ServiceProviderFilters for debugging
  Map<String, dynamic> toJson() {
    return {
      'selectedSkills': _filters.selectedSkills,
      'sortOption': _filters.sortOption?.toString(),
      'emergencyOnly': _filters.emergencyOnly,
    };
  }
}




class DriversGuidesHeader extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onFilterTap;
  final String? profileImagePath;

  const DriversGuidesHeader({
    Key? key,
    this.onMenuTap,
    this.onNotificationTap,
    this.onFilterTap,
    this.profileImagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF2079C2), // #2079C2
            Color(0xFF1F4889), // #1F4889
            Color(0xFF10105D), // #10105D
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      height: 182,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row with logo and icons
          Row(
            children: [
              Image.asset('assets/logo/barrim_logo.png', height: 60, width: 60),
              Spacer(),
              CircleAvatar(
                backgroundColor: Colors.blue,
                backgroundImage: (profileImagePath != null && profileImagePath!.startsWith('http'))
                    ? null
                    : null,
                radius: 22,
                child: (profileImagePath != null && profileImagePath!.startsWith('http'))
                    ? ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: profileImagePath!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          placeholder: Icon(Icons.person, color: Colors.white),
                          errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.white),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white),
              ),
              SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: onNotificationTap,
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: onMenuTap,
              ),
            ],
          ),

          // Search bar with filter button
          Row(
            children: [
              // Search bar
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search here...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(fontSize: 16, color: Colors.grey),
                            contentPadding: EdgeInsets.symmetric(vertical: 9.5),
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(4),
                        margin: EdgeInsets.only(right: 4),
                        child: Icon(Icons.search, color: Colors.grey, size: 26),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Filter button
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: IconButton(
                    icon: Icon(Icons.filter_list, color: Color(0xFF2079C2), size: 26),
                    onPressed: onFilterTap,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: TextStyle(
          color: Color(0xFF2079C2),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  final String name;
  final bool isVerified;
  final String experience;
  final String description;
  final int rating;
  final String imagePath;
  final VoidCallback onMessage;
  final VoidCallback onView;
  final dynamic provider;

  const ProfileCard({
    Key? key,
    required this.name,
    required this.isVerified,
    required this.experience,
    required this.description,
    required this.rating,
    required this.imagePath,
    required this.onMessage,
    required this.onView,
    required this.provider,
  }) : super(key: key);

  // Check if provider is a driver
  bool _isDriverProvider() {
    if (provider != null) {
      // Get service type from root level first, then fallback to serviceProviderInfo
      String? serviceType = provider['serviceType']?.toString().toLowerCase() ?? 
                           provider['serviceProviderInfo']?['serviceType']?.toString().toLowerCase();
      return serviceType == 'driver';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    bool isDriver = _isDriverProvider();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image with enhanced error handling
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildProfileImage(),
            ),
            SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and verification + experience (responsive)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        experience,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Rating and buttons
                  Row(
                    children: [
                      // Star rating
                      Row(
                        children: List.generate(
                          5,
                              (index) => Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          ),
                        ),
                      ),
                      Spacer(),

                      // Emergency button - only shown for drivers
                      if (isDriver)
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: onMessage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFFF5512),
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                minimumSize: Size(80, 30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                'Emergency',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
                        ),

                      // View button
                      ElevatedButton(
                        onPressed: onView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2079C2),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: Size(60, 30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          'View',
                          style: TextStyle(fontSize: 12, color: Colors.white),
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
  }

  // Helper method to build profile image with proper error handling
  Widget _buildProfileImage() {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // For network images
      return Container(
        width: 60,
        height: 60,
        child: SecureNetworkImage(
          imageUrl: imagePath,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          placeholder: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          errorWidget: (context, url, error) {
            print('Error loading image: $error\nURL: $imagePath');
            return const Icon(Icons.person, size: 40);
          },
        ),
      );
    } else if (imagePath.isNotEmpty) {
      // For asset images
      return Image.asset(
        imagePath,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading asset image: $error');
          return const Icon(Icons.person, size: 40);
        },
      );
    } else {
      return const Icon(Icons.person, size: 40);
    }
  }


}

class ViewMoreButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View more',
            style: TextStyle(
              color: Color(0xFF2079C2),
              fontWeight: FontWeight.w500,
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF2079C2),
          ),
        ],
      ),
    );
  }
}