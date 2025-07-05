import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io' show HttpException;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/service_provider.dart';
import '../../../../services/api_service.dart';
import '../../headers/dashboard_headers.dart';
import '../user_dashboard/notification.dart';
import 'sections/profile_header.dart';
import 'sections/description_section.dart';
import 'sections/booking_section.dart';
import 'sections/reviews_section.dart';
import '../../headers/sidebar.dart';
import '../user_dashboard/home.dart';
import '../category/categories.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';

class ServiceProviderProfile extends StatefulWidget {
  final dynamic provider;
  final String providerId;
  final String? logoUrl;

  const ServiceProviderProfile({
    Key? key,
    this.provider,
    required this.providerId,
    this.logoUrl,
  }) : super(key: key);

  @override
  State<ServiceProviderProfile> createState() => _ServiceProviderProfileState();
}

class _ServiceProviderProfileState extends State<ServiceProviderProfile> {
  Map<String, dynamic> providerData = {};
  bool isLoading = true;
  String errorMessage = '';
  String? logoUrl;
  bool _isSidebarOpen = false;
  String? _userProfileImagePath;

  // Add GlobalKey for Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Add your backend base URL here
  static const String baseUrl = ApiService.baseUrl;

  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    // Remove leading slash if present to avoid double slashes
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUrl.endsWith('/') ? baseUrl + cleanPath : baseUrl + '/' + cleanPath;
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfileImage();
    if (widget.provider != null && widget.provider is Map) {
      final convertedProvider = _convertMap(widget.provider);

      final mappedData = _mapApiDataToUiData(convertedProvider);
      if (widget.logoUrl != null) {
        mappedData['logoPath'] = widget.logoUrl;
      }

      setState(() {
        providerData = mappedData;
        isLoading = false;
      });
    } else if (widget.providerId.isNotEmpty) {
      fetchProviderData();
    } else {
      setState(() {
        errorMessage = 'No provider data available';
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserProfileImage() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData['profilePic'] != null && userData['profilePic'].toString().isNotEmpty) {
        String profilePic = userData['profilePic'];
        // Construct the full URL
        if (profilePic.startsWith('http')) {
          _userProfileImagePath = profilePic;
        } else {
          if (ApiService.baseUrl.endsWith('/') && profilePic.startsWith('/')) {
            _userProfileImagePath = '${ApiService.baseUrl}${profilePic.substring(1)}';
          } else if (!ApiService.baseUrl.endsWith('/') && !profilePic.startsWith('/')) {
            _userProfileImagePath = '${ApiService.baseUrl}/$profilePic';
          } else {
            _userProfileImagePath = '${ApiService.baseUrl}$profilePic';
          }
        }
      }
    } catch (e) {
      print('Error loading user profile image: $e');
    }
    setState(() {});
  }

  Map<String, dynamic> _convertMap(Map<dynamic, dynamic> map) {
    return map.map<String, dynamic>((key, value) {
      if (value is Map<dynamic, dynamic>) {
        return MapEntry(key.toString(), _convertMap(value));
      } else if (value is List) {
        return MapEntry(key.toString(), _convertList(value));
      } else {
        return MapEntry(key.toString(), value);
      }
    });
  }

  List<dynamic> _convertList(List list) {
    return list.map((item) {
      if (item is Map<dynamic, dynamic>) {
        return _convertMap(item);
      } else if (item is List) {
        return _convertList(item);
      } else {
        return item;
      }
    }).toList();
  }

 Future<void> fetchProviderData() async {
  try {
    final data = await ApiService.getServiceProviderById(widget.providerId);
    
    if (data == null) {
      setState(() {
        errorMessage = 'Failed to load provider data';
        isLoading = false;
      });
      return;
    }

    // Convert Map<dynamic, dynamic> to Map<String, dynamic> recursively
    final convertedData = _convertMap(data);

    final mappedData = _mapApiDataToUiData(convertedData);

    setState(() {
      providerData = mappedData;
      isLoading = false;
    });
  } catch (e) {
    setState(() {
      errorMessage = 'Error loading provider data: ${e.toString()}';
      isLoading = false;
    });
  }
}

  Map<String, dynamic> _mapApiDataToUiData(Map<String, dynamic> apiData) {
    final spInfo = apiData['serviceProviderInfo'] ?? {};
    final location = apiData['location'] ?? {};
    final socialLinks = apiData['socialLinks'] ?? {};

    // Defensive logoPath mapping
    final logoPathRaw = apiData['logoPath'];
    final logoPath = (logoPathRaw != null && logoPathRaw.toString().isNotEmpty)
        ? getFullImageUrl(logoPathRaw.toString())
        : null;

    return {
      'id': widget.providerId,
      'name': apiData['fullName']?.toString() ?? 'Unknown',
      'position': '${_getYearsExperience(spInfo['yearsExperience'])} Years of Experience',
      'rating': _getProviderRating(apiData),
      'jobTitle': spInfo['serviceType']?.toString() ?? 'Service Provider',
      'location': _getLocationString(location),
      'languages': spInfo['languages']?.cast<String>() ?? ['English'],
      'skills': spInfo['skills']?.cast<String>() ?? [],
      'description': _getProviderDescription(apiData),
      'availability': {
        'emergencyStatus': spInfo['status']?.toString() ?? 'Not Available',
        'calendar': spInfo['calendar'] ?? {},
        'hours': spInfo['availableHours'] ?? {
          'morning': false,
          'afternoon': false,
          'evening': false,
          'night': false,
        }
      },
      'phoneNumber': apiData['phone']?.toString() ?? 'No phone number',
      'reviews': apiData['reviews'] ?? [],
      'profilePic': logoPath,
      'certificateImage': spInfo['certificateImage'],
      'socialLinks': {
        'website': socialLinks['website'],
        'facebook': socialLinks['facebook'],
        'instagram': socialLinks['instagram'],
        'twitter': socialLinks['twitter'],
        'linkedin': socialLinks['linkedin'],
      },
      'serviceType': spInfo['serviceType'],
      'customServiceType': spInfo['customServiceType'],
      'availableDays': spInfo['availableDays']?.cast<String>() ?? [],
      'emergencyStatus': spInfo['status']?.toString() ?? 'Not Available',
    };
  }

  String _getLocationString(Map location) {
    if (location.isEmpty) return 'Location not specified';

    final city = location['city']?.toString() ?? '';
    final country = location['country']?.toString() ?? '';
    final district = location['district']?.toString() ?? '';
    final street = location['street']?.toString() ?? '';

    List<String> parts = [];
    if (street.isNotEmpty) parts.add(street);
    if (district.isNotEmpty) parts.add(district);
    if (city.isNotEmpty) parts.add(city);
    if (country.isNotEmpty) parts.add(country);

    return parts.isEmpty ? 'Location not specified' : parts.join(', ');
  }

  String _getProviderDescription(Map provider) {
    final spInfo = provider['serviceProviderInfo'] ?? {};

    // Try to get description from various possible locations
    if (spInfo['description'] != null && spInfo['description'].toString().isNotEmpty) {
      return spInfo['description'].toString();
    }
    if (spInfo['bio'] != null && spInfo['bio'].toString().isNotEmpty) {
      return spInfo['bio'].toString();
    }
    if (provider['description'] != null && provider['description'].toString().isNotEmpty) {
      return provider['description'].toString();
    }
    if (provider['bio'] != null && provider['bio'].toString().isNotEmpty) {
      return provider['bio'].toString();
    }

    // If no description is found, return a default message
    return 'No description available for this service provider.';
  }

  int _getProviderRating(Map provider) {
    final spInfo = provider['serviceProviderInfo'] ?? {};
    dynamic rating = spInfo['rating'] ?? provider['rating'] ?? 0;

    if (rating is num) return rating.round();
    if (rating is String) return double.tryParse(rating)?.round() ?? 0;
    return 0;
  }

  int _getYearsExperience(dynamic years) {
    if (years is num) return years.round();
    if (years is String) return int.tryParse(years) ?? 0;
    return 0;
  }

  Widget _buildProfileImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.person, size: 40);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) {
        // If we get a 429 error, show a retry button
        if (error is HttpException && error.message.contains('429')) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  setState(() {}); // Trigger rebuild to retry loading
                },
                child: const Text('Retry'),
              ),
            ],
          );
        }
        return const Icon(Icons.person, size: 40);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          Column(
            children: [
              AppHeader(
                profileImagePath: _userProfileImagePath ?? '',
                onMenuTap: () {
                  setState(() {
                    _isSidebarOpen = true;
                  });
                },
                onNotificationTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileHeader(
                        providerData: providerData,
                        onBackPressed: () => Navigator.of(context).pop(),
                      ),
                      DescriptionSection(providerData: providerData),
                      BookingSection(
                        serviceProvider: ServiceProvider(
                          id: widget.providerId,
                          fullName: providerData['name'] ?? 'Unknown',
                          email: null,
                          phone: providerData['phoneNumber'],
                          serviceProviderInfo: ServiceProviderInfo(
                            serviceType: providerData['jobTitle'] ?? 'Service Provider',
                            yearsExperience: int.tryParse(providerData['position']?.toString().split(' ')[0] ?? '0') ?? 0,
                            availableDays: const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
                          ),
                          location: null,
                        ),
                      ),
                      ReviewsSection(providerId: widget.providerId),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Semi-transparent overlay when sidebar is open
          if (_isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isSidebarOpen = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          // Sidebar
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _isSidebarOpen ? 0 : -160,
            top: 0,
            bottom: 0,
            child: _buildSidebar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 160,
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
                      Image.asset('assets/logo/sidebar_logo.png', width: 40, height: 40),
                      SizedBox(width: 4),
                      Text(
                        'Barrim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),
                ListTile(
                  leading: Icon(Icons.home, color: Colors.white),
                  title: Text('Home', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    setState(() {
                      _isSidebarOpen = false;
                    });
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => Home(userData: {})),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.category, color: Colors.white),
                  title: Text('Categories', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    setState(() {
                      _isSidebarOpen = false;
                    });
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => CategoriesPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.white),
                  title: Text('Workers', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    setState(() {
                      _isSidebarOpen = false;
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.share, color: Colors.white),
                  title: Text('Referral', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    setState(() {
                      _isSidebarOpen = false;
                    });
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => ReferralPointsPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.white),
                  title: Text('Settings', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    setState(() {
                      _isSidebarOpen = false;
                    });
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => SettingsPage()),
                      );
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.blue),
                      title: Text('Logout', style: TextStyle(color: Colors.blue, fontSize: 14)),
                      onTap: () {
                        setState(() {
                          _isSidebarOpen = false;
                        });
                        Future.delayed(const Duration(milliseconds: 300), () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => LoginPage()),
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
}