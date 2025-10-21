import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io' show HttpException;
import 'dart:convert';
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
import 'package:barrim/src/utils/authService.dart';
import 'worker_home.dart';

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
      print('ServiceProviderProfile: Received provider data: ${widget.provider}');
      final convertedProvider = _convertMap(widget.provider);
      print('ServiceProviderProfile: Converted provider data: $convertedProvider');

      final mappedData = _mapApiDataToUiData(convertedProvider);
      print('ServiceProviderProfile: Mapped UI data: $mappedData');
      
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
     print('ServiceProviderProfile: Fetching provider data for ID: ${widget.providerId}');
     final data = await ApiService.getServiceProviderById(widget.providerId);
     
     if (data == null) {
       setState(() {
         errorMessage = 'Failed to load provider data';
         isLoading = false;
       });
       return;
     }

     print('ServiceProviderProfile: Fetched provider data: $data');
     
     // Convert Map<dynamic, dynamic> to Map<String, dynamic> recursively
     final convertedData = _convertMap(data);
     print('ServiceProviderProfile: Converted fetched data: $convertedData');

     final mappedData = _mapApiDataToUiData(convertedData);
     print('ServiceProviderProfile: Mapped fetched data: $mappedData');

     setState(() {
       providerData = mappedData;
       isLoading = false;
     });
   } catch (e) {
     print('ServiceProviderProfile: Error fetching provider data: $e');
     setState(() {
       errorMessage = 'Error loading provider data: ${e.toString()}';
       isLoading = false;
     });
   }
 }

  Map<String, dynamic> _mapApiDataToUiData(Map<String, dynamic> apiData) {
    print('ServiceProviderProfile: Mapping API data: $apiData');
    
    final spInfo = apiData['serviceProviderInfo'] ?? {};
    print('ServiceProviderProfile: ServiceProviderInfo: $spInfo');
    
    // Try to get location from multiple sources
    final location = apiData['location'] ?? 
                    apiData['contactInfo']?['address'] ?? 
                    apiData['contactInfo'] ?? {};
    print('ServiceProviderProfile: Location data: $location');
    
    final socialLinks = apiData['socialLinks'] ?? {};
    print('ServiceProviderProfile: Social links: $socialLinks');

    // Defensive logoPath mapping
    final logoPathRaw = apiData['logoPath'];
    final logoPath = (logoPathRaw != null && logoPathRaw.toString().isNotEmpty)
        ? getFullImageUrl(logoPathRaw.toString())
        : null;
    print('ServiceProviderProfile: Logo path: $logoPathRaw -> $logoPath');

    final Map<String, dynamic> finalData = {
      'id': widget.providerId,
      'name': apiData['fullName']?.toString() ?? apiData['businessName']?.toString() ?? 'Unknown',
      'position': _getYearsExperienceFromProvider(apiData) != null 
          ? '${_getYearsExperience(_getYearsExperienceFromProvider(apiData))} Years of Experience'
          : '0 Years of Experience',
      'rating': _getProviderRating(apiData),
      'jobTitle': spInfo['serviceType']?.toString() ?? 'Service Provider',
      'location': _getLocationString(location),
      'description': _getProviderDescription(apiData),
      'availability': {
        // 'emergencyStatus': spInfo['status']?.toString() ?? 'Not Available',
        'calendar': spInfo['calendar'] ?? {},
        'hours': spInfo['availableHours'] ?? ['09:00', '17:00']
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
      'availableDays': _parseAvailableDays(apiData),
      // 'emergencyStatus': spInfo['status']?.toString() ?? 'Not Available',
      'yearsExperience': apiData['yearsExperience'],
    };
    
    print('ServiceProviderProfile: Final mapped data: $finalData');
    return finalData;
  }

  // Parse available days from both serviceProviderInfo and root level
  List<String> _parseAvailableDays(Map<String, dynamic> apiData) {
    List<String> availableDays = [];
    
    // First try serviceProviderInfo (this is where the data actually is)
    final spInfo = apiData['serviceProviderInfo'] ?? {};
    final spAvailableDays = spInfo['availableDays'];
    print('ServiceProviderProfile: ServiceProviderInfo availableDays: $spAvailableDays');
    
    if (spAvailableDays is List) {
      availableDays = spAvailableDays.cast<String>().where((day) => day.isNotEmpty).toList();
      print('ServiceProviderProfile: Using serviceProviderInfo availableDays: $availableDays');
    }
    
    // If serviceProviderInfo is empty, try root level availableDays (from serviceProviders collection)
    if (availableDays.isEmpty && apiData['availableDays'] != null) {
      final rootAvailableDays = apiData['availableDays'];
      print('ServiceProviderProfile: Root availableDays: $rootAvailableDays');
      
      if (rootAvailableDays is List && rootAvailableDays.isNotEmpty) {
        final firstElement = rootAvailableDays[0];
        if (firstElement is String && firstElement.isNotEmpty) {
          try {
            // Parse JSON string
            final parsedJson = jsonDecode(firstElement);
            if (parsedJson is List) {
              availableDays = List<String>.from(parsedJson);
              print('ServiceProviderProfile: Parsed root availableDays: $availableDays');
            }
          } catch (e) {
            print('ServiceProviderProfile: Failed to parse root availableDays JSON: $e');
          }
        }
      }
    }
    
    print('ServiceProviderProfile: Final availableDays: $availableDays');
    return availableDays;
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

    // If no description is found, create a personalized default message
    String providerName = provider['fullName']?.toString() ?? provider['businessName']?.toString() ?? 'service provider';
    String serviceType = provider['serviceType']?.toString() ?? 
                        spInfo['serviceType']?.toString() ?? 
                        provider['category']?.toString() ?? 'service';
    
    return '$providerName is a professional $serviceType with experience in their field.';
  }

  int _getProviderRating(Map provider) {
    final spInfo = provider['serviceProviderInfo'] ?? {};
    dynamic rating = spInfo['rating'] ?? provider['rating'] ?? 0;

    if (rating is num) return rating.round();
    if (rating is String) return double.tryParse(rating)?.round() ?? 0;
    return 0;
  }

  // Helper method to get years of experience from provider data
  dynamic _getYearsExperienceFromProvider(Map provider) {
    // First check serviceProviderInfo.yearsExperience
    if (provider['serviceProviderInfo'] != null && 
        provider['serviceProviderInfo']['yearsExperience'] != null) {
      return provider['serviceProviderInfo']['yearsExperience'];
    }
    
    // Fallback to root level yearsExperience
    if (provider['yearsExperience'] != null) {
      return provider['yearsExperience'];
    }
    
    // Default to 0 if no experience data found
    return 0;
  }

  int _getYearsExperience(dynamic years) {
    if (years == null) {
      return 0; // Default value if null
    }
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

  void _showBookingSuccessDialog(BuildContext context) {
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
                  'Your Request has been sent',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
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
                      // Debug logging for BookingSection
                      Builder(
                        builder: (context) {
                          print("=== BOOKING SECTION DEBUG ===");
                          print("Provider availableDays: ${providerData['availableDays']}");
                          print("Provider availableDays length: ${providerData['availableDays']?.length}");
                          print("Provider availability hours: ${providerData['availability']?['hours']}");
                          print("=== END BOOKING SECTION DEBUG ===");
                          return SizedBox.shrink();
                        },
                      ),
                      BookingSection(
                        serviceProvider: ServiceProvider(
                          id: widget.providerId,
                          fullName: providerData['name'] ?? 'Unknown',
                          email: null,
                          phone: providerData['phoneNumber'],
                          serviceProviderInfo: ServiceProviderInfo(
                            serviceType: providerData['jobTitle'] ?? 'Service Provider',
                            yearsExperience: _getYearsExperience(_getYearsExperienceFromProvider(providerData)),
                            availableDays: providerData['availableDays']?.cast<String>() ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
                            availableHours: providerData['availability']?['hours']?.cast<String>() ?? ['09:00', '17:00'],
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
            right: _isSidebarOpen ? 0 : -200,
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
      width: 200,
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
                        MaterialPageRoute(builder: (context) => UserDashboard(userData: {})),
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
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => DriversGuidesPage()),
                      );
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
                      onTap: () async {
                        setState(() {
                          _isSidebarOpen = false;
                        });
                        await AuthService().logout();
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