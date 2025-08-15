import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import '../../../../components/category_circle_button.dart';
import '../../../../components/collapsed_sheet.dart';
import '../../../../components/map_component.dart';
import '../../../../components/google_maps_wrapper.dart';
import '../../../../components/place_details_overlay.dart';
import '../../../../components/search_results_overlay.dart';
import '../../../../services/api_service.dart';
import '../../headers/dashboard_headers.dart';
import '../../headers/sidebar.dart';
import 'filter.dart';
import '../../../../services/wholesaler_service.dart';
import '../../../../models/wholesaler_model.dart';
import 'package:flutter/services.dart';
import 'package:barrim/src/components/secure_network_image.dart';
import 'notification.dart' as notification;
import '../booking/myboooking.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import '../category/categories.dart';

class UserDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const UserDashboard({super.key, required this.userData});
  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> with WidgetsBindingObserver {
  bool _isSidebarOpen = false;
  bool _isMapExpanded = true;
  Map<String, dynamic>? _selectedPlace;
// Add to your existing _HomeState class variables
  bool _showSearchResults = false;
  List<Map<String, dynamic>> _searchResults = [];
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  // Add profile image path variable
  String? _profileImagePath;

  // Google Maps related variables
  final GoogleMapsWrapper _mapController = GoogleMapsWrapper();
  final Location _locationTracker = Location();
  final PolylinePoints _polylinePoints = PolylinePoints();
  StreamSubscription<LocationData>? _locationSubscription;

  latlong.LatLng? _currentLocation;
  latlong.LatLng? _destinationLocation;
  List<latlong.LatLng> _primaryRouteCoordinates = [];
  List<latlong.LatLng> _alternativeRouteCoordinates = [];
  bool _isTracking = false;
  bool _isNavigating = false;
  String _routeInstructions = '';
  bool _initialLocationSet = false;

  double _primaryDistance = 0;
  double _primaryDuration = 0;
  double _alternativeDistance = 0;
  double _alternativeDuration = 0;
  List<Map<String, dynamic>> _steps = [];
  bool _usingPrimaryRoute = true;
  List<google_maps.Marker> _wayPointMarkers = [];
  final Color primaryRouteColor = Colors.blue;
  final Color alternativeRouteColor = Colors.purple;
  List<Map<String, dynamic>> _allBranches = [];
  List<Map<String, dynamic>> _allCompanies = [];
  List<Map<String, dynamic>> _wholesalerBranches = [];

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '';

  Wholesaler? _myWholesaler;
  google_maps.Marker? _myWholesalerMarker;
  final WholesalerService _wholesalerService = WholesalerService();

  // Track if location is denied
  bool _locationDenied = false;
  
  // Track location accuracy
  double _locationAccuracy = 0.0;

  // Add a variable to track marker size based on zoom
  double _companyMarkerSize = 40;

  // Top Listed section state variables
  List<Map<String, dynamic>> _sponsoredCompanies = [];
  List<Map<String, dynamic>> _sponsoredWholesalers = [];
  List<Map<String, dynamic>> _sponsoredServiceProviders = [];
  List<Map<String, dynamic>> _sponsoredBranches = []; // Add this line
  bool _isLoadingSponsored = true;
  String? _sponsoredErrorMessage;

  // Add method to fetch user data
  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      setState(() {
        if (userData['profilePic'] != null && userData['profilePic'].toString().isNotEmpty) {
          String profilePic = userData['profilePic'];
          // Construct the full URL
          if (profilePic.startsWith('http')) {
            // Already a full URL
            _profileImagePath = profilePic;
          } else {
            // Need to add base URL
            // Remove leading slash if present in both baseUrl and profilePic
            if (ApiService.baseUrl.endsWith('/') && profilePic.startsWith('/')) {
              _profileImagePath = '${ApiService.baseUrl}${profilePic.substring(1)}';
            } else if (!ApiService.baseUrl.endsWith('/') && !profilePic.startsWith('/')) {
              _profileImagePath = '${ApiService.baseUrl}/${profilePic}';
            } else {
              _profileImagePath = '${ApiService.baseUrl}${profilePic}';
            }
          }
          print('Profile Image Path: $_profileImagePath');
        } else {
          _profileImagePath = null;
          print('No profile picture available');
        }
      });
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _profileImagePath = null;
      });
    }
  }

  // Load sponsored entities for Top Listed section
  Future<void> _loadSponsoredEntities() async {
    try {
      setState(() {
        _isLoadingSponsored = true;
        _sponsoredErrorMessage = null;
      });

      // Load sponsored entities in parallel
      await Future.wait([
        _loadSponsoredCompanies(),
        _loadSponsoredWholesalers(),
        _loadSponsoredServiceProviders(),
        _loadSponsoredBranches(),
      ]);

      setState(() {
        _isLoadingSponsored = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSponsored = false;
        _sponsoredErrorMessage = 'Failed to load sponsored entities: $e';
      });
      print('Error loading sponsored entities: $e');
    }
  }

  Future<void> _loadSponsoredCompanies() async {
    try {
      final sponsoredCompanies = await ApiService.getSponsoredCompanies();
      setState(() {
        _sponsoredCompanies = sponsoredCompanies;
      });
    } catch (e) {
      print('Error loading sponsored companies: $e');
    }
  }

  Future<void> _loadSponsoredWholesalers() async {
    try {
      final wholesalers = await _wholesalerService.getAllWholesalers();
      
      // Filter wholesalers that have sponsorship: true
      // Since the sponsorship field might not exist in the model yet,
      // we'll check for it in the raw data or use a different approach
      final sponsoredWholesalers = wholesalers.where((wholesaler) {
        // For now, we'll check if the wholesaler has any special indicators
        // You may need to adjust this based on your actual data structure
        // or add the sponsorship field to your Wholesaler model
        
        // Check if wholesaler has any special status or premium features
        // This is a placeholder - you'll need to implement based on your API
        return wholesaler.balance > 0 || wholesaler.points > 100; // Example criteria
      }).map((wholesaler) => {
        'id': wholesaler.id,
        'businessName': wholesaler.businessName,
        'category': wholesaler.category,
        'phone': wholesaler.phone,
        'email': wholesaler.email,
        'logoUrl': wholesaler.logoUrl,
        'address': wholesaler.address,
        'branches': wholesaler.branches,
        'type': 'wholesaler',
        'balance': wholesaler.balance,
        'points': wholesaler.points,
      }).toList();

      setState(() {
        _sponsoredWholesalers = sponsoredWholesalers;
      });
    } catch (e) {
      print('Error loading sponsored wholesalers: $e');
    }
  }

  Future<void> _loadSponsoredServiceProviders() async {
    try {
      // This would need to be implemented based on your service provider API
      // For now, setting empty list
      setState(() {
        _sponsoredServiceProviders = [];
      });
    } catch (e) {
      print('Error loading sponsored service providers: $e');
    }
  }

  Future<void> _loadSponsoredBranches() async {
    try {
      final sponsoredBranches = await ApiService.getSponsoredBranches();
      setState(() {
        _sponsoredBranches = sponsoredBranches;
      });
    } catch (e) {
      print('Error loading sponsored branches: $e');
    }
  }

// Add this method to fetch branches
  Future<void> _fetchAllBranches() async {
    try {
      final branches = await ApiService.getAllBranches();
      print('Total branches fetched: ${branches.length}');
      
      // Debug: Print first few branches to see structure
      if (branches.isNotEmpty) {
        print('First branch structure: ${branches[0]}');
        print('First branch status: ${branches[0]['status']}');
        print('First branch location: ${branches[0]['location']}');
        print('First branch company: ${branches[0]['company']}');
      }

      // Filter out branches whose status is not 'active'
      final filteredBranches = branches.where((branch) {
        // Check branch status - only show active branches
        final branchStatus = branch['status'];
        print('Branch: ${branch['name']}, Status: $branchStatus');
        if (branchStatus != 'active') return false;
        return true;
      }).toList();
      
      print('Active branches after filtering: ${filteredBranches.length}');

      setState(() {
        _allBranches = filteredBranches;

        // Create markers for filtered branches
        final branchMarkers = filteredBranches.map((branch) {
          final location = branch['location'];
          final company = branch['company'];
          final logoUrl = company?['logoUrl'];

          print('Processing branch: ${branch['name']}, Location: $location, Company: $company');

          // Validate location data
          if (location == null ||
              location['lat'] == null ||
              location['lng'] == null) {
            print('Branch ${branch['name']} has invalid location data');
            return null;
          }
          
          print('Creating marker for branch: ${branch['name']} at lat: ${location['lat']}, lng: ${location['lng']}');

          return google_maps.Marker(
            markerId: google_maps.MarkerId('branch_${branch['id']}'),
            position: google_maps.LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
            onTap: () {
              setState(() {
                _selectedPlace = {
                  'name': branch['name'] ?? 'Unnamed Branch',
                  '_id': branch['id'],
                  'latitude': location['lat'].toDouble(),
                  'longitude': location['lng'].toDouble(),
                  'address': '${location['street'] ?? ''}, ${location['city'] ?? ''}',
                  'phone': branch['phone'] ?? '',
                  'description': branch['description'] ?? '',
                  'image': logoUrl ?? 'assets/images/company_placeholder.png',
                  'logoUrl': logoUrl,
                  'companyName': company['businessName'] ?? 'Unknown Company',
                  'companyId': company['id'],
                  'images': branch['images'] ?? [],
                  'category': branch['category'] ?? 'Unknown Category',
                  'company': company,
                };
              });
            },
            icon: _isRestaurantCategory(branch['category']?.toString() ?? '') || _isRestaurantCategory(company['category']?.toString() ?? '')
                ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed)
                : _isHotelCategory(branch['category']?.toString() ?? '') || _isHotelCategory(company['category']?.toString() ?? '')
                    ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue)
                    : google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
          );
        }).where((marker) => marker != null).cast<google_maps.Marker>().toList();

        print('Created ${branchMarkers.length} branch markers');

        // Add a test marker to see if markers are working
        if (filteredBranches.isNotEmpty) {
          final testBranch = filteredBranches.first;
          final testLocation = testBranch['location'];
          if (testLocation != null && testLocation['lat'] != null && testLocation['lng'] != null) {
            final testMarker = google_maps.Marker(
              markerId: google_maps.MarkerId('test_marker'),
              position: google_maps.LatLng(
                testLocation['lat'].toDouble(),
                testLocation['lng'].toDouble(),
              ),
              onTap: () {
                setState(() {
                  _selectedPlace = {
                    'name': testBranch['name'] ?? 'Unnamed Branch',
                    '_id': testBranch['id'],
                    'latitude': testLocation['lat'].toDouble(),
                    'longitude': testLocation['lng'].toDouble(),
                    'address': '${testLocation['street'] ?? ''}, ${testLocation['city'] ?? ''}',
                    'phone': testBranch['phone'] ?? '',
                    'description': testBranch['description'] ?? '',
                    'image': testBranch['logoUrl'] ?? 'assets/images/company_placeholder.png',
                    'logoUrl': testBranch['logoUrl'],
                    'companyName': testBranch['company']?['businessName'] ?? 'Unknown Company',
                    'companyId': testBranch['company']?['id'],
                    'images': testBranch['images'] ?? [],
                    'category': testBranch['category'] ?? 'Unknown Category',
                    'company': testBranch['company'],
                  };
                });
              },
              icon: _isRestaurantCategory(testBranch['category']?.toString() ?? '') || _isRestaurantCategory(testBranch['company']?['category']?.toString() ?? '')
                  ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed)
                  : _isHotelCategory(testBranch['category']?.toString() ?? '') || _isHotelCategory(testBranch['company']?['category']?.toString() ?? '')
                      ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue)
                      : google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
            );
            _wayPointMarkers.add(testMarker);
            print('Added test marker for branch: ${testBranch['name']}');
          }
        }

        // Add branch markers to existing company markers
        _wayPointMarkers.addAll(branchMarkers);
        print('Total markers on map: ${_wayPointMarkers.length}');
      });

      // Move camera to the first marker if exists
      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].position, 15.0);
      }
    } catch (e) {
      print('Error fetching branches: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load branches: $e')),
      // );
    }
  }

// Add this function to filter branches by category
  void _filterBranchesByCategory(String categoryType) {
    try {
      // Removed categoryMapping and mapping logic
      // final Map<String, String> categoryMapping = {
      //   'Stations': 'station',
      //   'Restaurant': 'restaurant',
      //   'Hotels': 'hotel',
      //   'Shops': 'shop',
      // };

      // Get the database category name directly from the UI category
      final String dbCategory = categoryType.toLowerCase();

      // Filter branches based on the category
      final filteredBranches = _allBranches.where((branch) {
        // First check if the branch is active
        final branchStatus = branch['status'];
        if (branchStatus != 'active') {
          return false; // Skip branches that are not active
        }
        final branchCategory = branch['category']?.toString().toLowerCase() ?? '';
        final companyCategory = branch['company']?['category']?.toString().toLowerCase() ?? '';

        // Check both branch category and company category
        return branchCategory.contains(dbCategory) || companyCategory.contains(dbCategory);
      }).toList();

      print('Filtering for category: $dbCategory');
      print('Found ${filteredBranches.length} branches');

      if (filteredBranches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No branches found in category: $categoryType')),
        );
        return;
      }

      // Create markers for filtered branches
      setState(() {
        _wayPointMarkers = filteredBranches.map((branch) {
          final location = branch['location'];
          final company = branch['company'];
          final logoUrl = company['logoUrl'];

          if (location == null ||
              location['lat'] == null ||
              location['lng'] == null) {
            return null;
          }

          return google_maps.Marker(
            markerId: google_maps.MarkerId('branch_${branch['id']}'),
            position: google_maps.LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
            onTap: () {
              setState(() {
                _selectedPlace = {
                  'name': branch['name'] ?? 'Unnamed Branch',
                  '_id': branch['id'],
                  'latitude': location['lat'].toDouble(),
                  'longitude': location['lng'].toDouble(),
                  'address': '${location['street'] ?? ''}, ${location['city'] ?? ''}',
                  'phone': branch['phone'] ?? '',
                  'description': branch['description'] ?? '',
                  'image': logoUrl ?? 'assets/images/company_placeholder.png',
                  'logoUrl': logoUrl,
                  'companyName': company['businessName'] ?? 'Unknown Company',
                  'companyId': company['id'],
                  'images': branch['images'] ?? [],
                  'category': branch['category'] ?? 'Unknown Category',
                  'company': company,
                };
              });
            },
            icon: _isRestaurantCategory(branch['category']?.toString() ?? '') || _isRestaurantCategory(company['category']?.toString() ?? '')
                ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed)
                : _isHotelCategory(branch['category']?.toString() ?? '') || _isHotelCategory(company['category']?.toString() ?? '')
                    ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue)
                    : google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
          );
        }).where((marker) => marker != null).cast<google_maps.Marker>().toList();
      });

      // Move camera to the first filtered marker if exists
      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].position, 15.0);
      }
    } catch (e) {
      print('Error filtering branches: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to filter branches: $e')),
      // );
    }
  }



  Future<void> _fetchCompanies() async {
    try {
      final companies = await ApiService.getCompaniesWithLocations();
      print('Raw companies data: ${jsonEncode(companies)}'); // Debug output

      // Filter out companies with status 'pending' or 'rejected'
      final filteredCompanies = companies.where((company) {
        final status = company['status'] ?? company['companyInfo']?['status'];
        return status == 'active';
      }).toList();

      // Store all companies for later use in filtering and searching
      _allCompanies = List<Map<String, dynamic>>.from(filteredCompanies);

      setState(() {
        // Create markers for companies and their branches
        _wayPointMarkers = [];

        for (var company in filteredCompanies) {
          print('Processing company: ${company['companyInfo']?['name']}'); // Debug log

          // Add company headquarters marker
          if (company['location'] != null &&
              company['location']['lat'] != null &&
              company['location']['lng'] != null) {

            final location = company['location'];
            final companyInfo = company['companyInfo'];
            final logoUrl = companyInfo?['logo'];

            print('Company location: lat=${location['lat']}, lng=${location['lng']}'); // Debug log

            // Add company headquarters marker with a distinct style
            _wayPointMarkers.add(
              google_maps.Marker(
                markerId: google_maps.MarkerId('company_${company['_id']}'),
                position: google_maps.LatLng(
                  location['lat'].toDouble(),
                  location['lng'].toDouble(),
                ),
                onTap: () async {
                  try {
                    // Fetch branches for this company
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('auth_token');
                    if (token != null) {
                      final branches = await ApiService.getCompanyBranches(token);
                      // Filter branches for this specific company and check status
                      final companyBranches = branches.where((b) {
                        // First check if this branch belongs to the current company
                        if (b['companyId'] != company['_id']) return false;
                        
                        // Then check if the branch is active
                        final branchStatus = b['status'];
                        if (branchStatus != 'active') {
                          return false; // Skip branches that are not active
                        }
                        
                        return true;
                      }).toList();

                      // Process branch data
                      final processedBranches = companyBranches.map((branch) {
                        final branchImages = branch['images'];
                        List<String> processedImages = [];

                        if (branchImages != null && branchImages is List && branchImages.isNotEmpty) {
                          processedImages = branchImages.map((img) {
                            if (img is String) {
                              if (img.startsWith('http')) {
                                return img;
                              }
                              return '${ApiService.baseUrl}/$img';
                            }
                            return '';
                          }).where((img) => img.isNotEmpty).toList();
                        }

                        return {
                          ...branch,
                          'name': branch['name'] ?? 'Unnamed Branch',
                          'description': branch['description'] ?? 'No description available',
                          'location': branch['location'] ?? 'No address available',
                          'images': processedImages,
                          'latitude': branch['latitude'] ?? location['lat'].toDouble(),
                          'longitude': branch['longitude'] ?? location['lng'].toDouble(),
                        };
                      }).toList();

                      setState(() {
                        _selectedPlace = {
                          'name': companyInfo?['name'] ?? 'Unknown Company',
                          '_id': company['_id'],
                          'latitude': location['lat'].toDouble(),
                          'longitude': location['lng'].toDouble(),
                          'address': '${location['street'] ?? ''}, ${location['city'] ?? ''}',
                          'phone': company['phone'] ?? '',
                          'description': companyInfo?['description'] ?? '',
                          'image': logoUrl ?? 'assets/images/company_placeholder.png',
                          'logoUrl': logoUrl,
                          'branches': processedBranches,
                          'type': 'company', // Add type to distinguish company from branch
                          'category': companyInfo?['category'] ?? 'Unknown Category',
                        };
                      });
                    }
                  } catch (e) {
                    print('Error fetching branches: $e');
                    setState(() {
                      _selectedPlace = {
                        'name': companyInfo?['name'] ?? 'Unknown Company',
                        '_id': company['_id'],
                        'latitude': location['lat'].toDouble(),
                        'longitude': location['lng'].toDouble(),
                        'address': '${location['street'] ?? ''}, ${location['city'] ?? ''}',
                        'phone': company['phone'] ?? '',
                        'description': companyInfo?['description'] ?? '',
                        'image': logoUrl ?? 'assets/images/company_placeholder.png',
                        'logoUrl': logoUrl,
                        'branches': [],
                        'type': 'company', // Add type to distinguish company from branch
                        'category': companyInfo?['category'] ?? 'Unknown Category',
                      };
                    });
                  }
                },
                icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
              ),
            );
          } else {
            print('Company missing location data: ${company['companyInfo']?['name']}'); // Debug log
          }

          // Add branch markers if available
          if (company['branches'] != null && company['branches'] is List) {
            print('Processing branches for company: ${company['companyInfo']?['name']}'); // Debug log
            for (var branch in company['branches']) {
              if (branch['location'] != null &&
                  branch['location']['lat'] != null &&
                  branch['location']['lng'] != null) {

                final branchLocation = branch['location'];
                final companyInfo = company['companyInfo'];
                final logoUrl = companyInfo?['logo'];

                print('Branch location: lat=${branchLocation['lat']}, lng=${branchLocation['lng']}'); // Debug log

                _wayPointMarkers.add(
                  google_maps.Marker(
                    markerId: google_maps.MarkerId('branch_${branch['id']}'),
                    position: google_maps.LatLng(
                      branchLocation['lat'].toDouble(),
                      branchLocation['lng'].toDouble(),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedPlace = {
                          'name': branch['name'] ?? 'Unnamed Branch',
                          '_id': branch['id'],
                          'latitude': branchLocation['lat'].toDouble(),
                          'longitude': branchLocation['lng'].toDouble(),
                          'address': '${branchLocation['street'] ?? ''}, ${branchLocation['city'] ?? ''}',
                          'phone': branch['phone'] ?? '',
                          'description': branch['description'] ?? '',
                          'image': logoUrl ?? 'assets/images/company_placeholder.png',
                          'logoUrl': logoUrl,
                          'companyName': companyInfo?['name'] ?? 'Unknown Company',
                          'companyId': company['_id'],
                          'images': branch['images'] ?? [],
                          'type': 'branch', // Add type to distinguish branch from company
                          'category': branch['category'] ?? 'Unknown Category',
                          'company': companyInfo,
                        };
                      });
                    },
                    icon: _isRestaurantCategory(branch['category']?.toString() ?? '') || _isRestaurantCategory(company['category']?.toString() ?? '')
                        ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed)
                        : _isHotelCategory(branch['category']?.toString() ?? '') || _isHotelCategory(company['category']?.toString() ?? '')
                            ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue)
                            : google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
                  ),
                );
              } else {
                print('Branch missing location data: ${branch['name']}'); // Debug log
              }
            }
          }
        }

        print('Total markers created: ${_wayPointMarkers.length}'); // Debug log
      });

      // Move camera to the first marker if exists
      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        print('Moving camera to first marker'); // Debug log
        _mapController.move(_wayPointMarkers[0].position, 15.0);
      } else {
        print('No markers to move camera to'); // Debug log
      }
    } catch (e) {
      print('Error fetching companies: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load company locations: $e')),
      // );
    }
  }



  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

// Test widget to verify restaurant icon is loading
  Widget _buildTestRestaurantIcon() {
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        // child: Column(
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     Text('Test Restaurant Icon', style: TextStyle(fontSize: 12)),
        //     Image.asset(
        //       'assets/icons/restaurant_icon.png',
        //       width: 40,
        //       height: 40,
        //       errorBuilder: (context, error, stackTrace) {
        //         print('Test widget - Error loading restaurant icon: $error');
        //         return Icon(Icons.error, color: Colors.red, size: 40);
        //       },
        //     ),
        //   ],
        // ),
      ),
    );
  }

void _createMarkersFromCompanies(List<Map<String, dynamic>> companies) {
  print('Creating markers for ${companies.length} companies');
  setState(() {
    _wayPointMarkers = companies.map((company) {
      final location = company['location'];
      final companyInfo = company['companyInfo'];
      final logoUrl = companyInfo?['logo'];
      final category = companyInfo?['category']?.toString().toLowerCase().trim() ?? '';
      
      // Debug print for company info
      print('--- Company Debug Info ---');
      print('Name: ${companyInfo?['name']}');
      print('Category: "$category" (length: ${category.length})');
      print('Location: ${location?['lat']}, ${location?['lng']}');
      print('Logo URL: $logoUrl');
      print('Company Info: $companyInfo');
      print('--------------------------');

      print('Processing company: ${companyInfo?['name']}');
      print('Company category: "$category" (type: ${category.runtimeType})');
      print('Location: ${location?['lat']}, ${location?['lng']}');

      return google_maps.Marker(
        markerId: google_maps.MarkerId('company_${company['_id']}'),
        position: google_maps.LatLng(
          location['lat'].toDouble(),
          location['lng'].toDouble(),
        ),
        onTap: () async {
          try {
            // Fetch branches for this company
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('auth_token');
            if (token != null) {
              final branches = await ApiService.getCompanyBranches(token);
              // Filter branches for this specific company and check status
              final companyBranches = branches.where((b) {
                // First check if this branch belongs to the current company
                if (b['companyId'] != company['_id']) return false;
                
                // Then check if the branch is active
                final branchStatus = b['status'];
                if (branchStatus != 'active') {
                  return false; // Skip branches that are not active
                }
                
                return true;
              }).toList();

              // Process branch data to ensure it has all required fields
              final processedBranches = companyBranches.map((branch) {
                // Handle branch images
                final branchImages = branch['images'];
                List<String> processedImages = [];

                if (branchImages != null && branchImages is List && branchImages.isNotEmpty) {
                  processedImages = branchImages.map((img) {
                    if (img is String) {
                      // If it's already a full URL, use it as is
                      if (img.startsWith('http')) {
                        return img;
                      }
                      // Otherwise, construct the full URL using the base URL
                      return '${ApiService.baseUrl}/$img';
                    }
                    return '';
                  }).where((img) => img.isNotEmpty).toList();
                }

                return {
                  ...branch,
                  'name': branch['name'] ?? 'Unnamed Branch',
                  'description': branch['description'] ?? 'No description available',
                  'location': branch['location'] ?? 'No address available',
                  'images': processedImages,
                  'latitude': branch['latitude'] ?? location['lat'].toDouble(),
                  'longitude': branch['longitude'] ?? location['lng'].toDouble(),
                };
              }).toList();

              setState(() {
                _selectedPlace = {
                  'name': companyInfo?['name'] ?? 'Unknown Company',
                  '_id': company['_id'],
                  'latitude': location['lat'].toDouble(),
                  'longitude': location['lng'].toDouble(),
                  'address': '${location['street'] ?? ''}, ${location['city'] ?? ''}',
                  'phone': company['phone'] ?? '',
                  'description': companyInfo?['description'] ?? '',
                  'image': logoUrl ?? 'assets/images/company_placeholder.png',
                  'logoUrl': logoUrl,
                  'branches': processedBranches,
                };
              });
            }
          } catch (e) {
            print('Error fetching branches: $e');
            setState(() {
              // Fallback to showing just company info if branch fetch fails
              _selectedPlace = {
                'name': companyInfo?['name'] ?? 'Unknown Company',
                '_id': company['_id'],
                'latitude': location['lat'].toDouble(),
                'longitude': location['lng'].toDouble(),
                'address': '${location['street'] ?? ''}, ${location['city'] ?? ''}',
                'phone': company['phone'] ?? '',
                'description': companyInfo?['description'] ?? '',
                'image': logoUrl ?? 'assets/images/company_placeholder.png',
                'logoUrl': logoUrl,
                'branches': [],
              };
            });
          }
        },
        icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
      );
    }).where((marker) => marker != null).cast<google_maps.Marker>().toList();
  });

    print('Number of markers created: ${_wayPointMarkers.length}');
  }

  void _applyFilters(Map<String, dynamic> filters) async {
    setState(() {
      _wayPointMarkers.clear();
      _primaryRouteCoordinates.clear();
      _alternativeRouteCoordinates.clear();
    });

    // If Wholesaler is selected, filter wholesalers
    if (filters['type'] == 'Wholesaler') {
      // Fetch all wholesalers if not already loaded
      final wholesalers = await _wholesalerService.getAllWholesalers();
      List<Wholesaler> filteredWholesalers = wholesalers;

      // Category filter
      if (filters['category'] != null && filters['category'] != 'All' && filters['category'] != null) {
        filteredWholesalers = filteredWholesalers.where((w) =>
          w.category.toLowerCase() == filters['category'].toString().toLowerCase()
        ).toList();
      }

      // Distance filter (use address or first branch location)
      if (filters['distance'] != null) {
        double maxDistance = double.parse(filters['distance'].toString().replaceAll(' km', ''));
        filteredWholesalers = filteredWholesalers.where((w) {
          double lat = 0.0;
          double lng = 0.0;
          if (w.branches.isNotEmpty) {
            lat = w.branches.first.location.lat;
            lng = w.branches.first.location.lng;
          } else if (w.address != null) {
            lat = w.address!.lat;
            lng = w.address!.lng;
          }
          if (lat == 0.0 && lng == 0.0) return false;
          double distance = _calculateDistance(
            _userLocation.latitude,
            _userLocation.longitude,
            lat,
            lng,
          );
          return distance <= maxDistance;
        }).toList();
      }

      // Sort
      if (filters['sortBy'] != null) {
        switch (filters['sortBy']) {
          case 'Most Recent':
            filteredWholesalers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case 'Closest':
            filteredWholesalers.sort((a, b) {
              double distA = 999999, distB = 999999;
              if (a.branches.isNotEmpty) {
                distA = _calculateDistance(_userLocation.latitude, _userLocation.longitude, a.branches.first.location.lat, a.branches.first.location.lng);
              } else if (a.address != null) {
                distA = _calculateDistance(_userLocation.latitude, _userLocation.longitude, a.address!.lat, a.address!.lng);
              }
              if (b.branches.isNotEmpty) {
                distB = _calculateDistance(_userLocation.latitude, _userLocation.longitude, b.branches.first.location.lat, b.branches.first.location.lng);
              } else if (b.address != null) {
                distB = _calculateDistance(_userLocation.latitude, _userLocation.longitude, b.address!.lat, b.address!.lng);
              }
              return distA.compareTo(distB);
            });
            break;
        }
      }

      // Create markers for filtered wholesalers
      final wholesalerMarkers = filteredWholesalers.map((wholesaler) {
        double lat = 0.0;
        double lng = 0.0;
        String address = '';
        Branch? activeBranch;
        if (wholesaler.branches.isNotEmpty) {
          // Find the first active branch
          final activeBranches = wholesaler.branches.where((b) => b.status != 'inactive');
          if (activeBranches.isNotEmpty) {
            activeBranch = activeBranches.first;
            lat = activeBranch.location.lat;
            lng = activeBranch.location.lng;
            address = '${activeBranch.location.street}, ${activeBranch.location.city}';
          }
        } else if (wholesaler.address != null) {
          lat = wholesaler.address!.lat;
          lng = wholesaler.address!.lng;
          address = '${wholesaler.address!.street}, ${wholesaler.address!.city}';
        }
        if (lat == 0.0 && lng == 0.0) return null;
        return google_maps.Marker(
          markerId: google_maps.MarkerId('wholesaler_${wholesaler.id}'),
          position: google_maps.LatLng(lat, lng),
          onTap: () {
            setState(() {
              _selectedPlace = {
                'name': wholesaler.businessName,
                '_id': wholesaler.id,
                'latitude': lat,
                'longitude': lng,
                'address': address,
                'phone': wholesaler.phone,
                'description': 'Wholesaler',
                'image': wholesaler.logoUrl ?? 'assets/images/company_placeholder.png',
                'logoUrl': wholesaler.logoUrl,
                'companyName': wholesaler.businessName,
                'companyId': wholesaler.id,
                'images': wholesaler.branches.isNotEmpty ? wholesaler.branches.first.images : [],
                'category': wholesaler.category,
                'company': {
                  'businessName': wholesaler.businessName,
                  'logoUrl': wholesaler.logoUrl,
                  'id': wholesaler.id,
                },
              };
            });
          },
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
        );
      }).where((marker) => marker != null).cast<google_maps.Marker>().toList();

      setState(() {
        _wayPointMarkers = wholesalerMarkers;
      });

      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].position, 15.0);
      }

      // if (filteredWholesalers.isEmpty) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('No wholesalers found matching your filters')),
      //   );
      // }
      return;
    }

    // Otherwise, filter branches
    if (_allBranches.isEmpty) {
      await _fetchAllBranches();
    }
    // if (_allBranches.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('No branch data available. Please try again.')),
    //   );
    //   return;
    // }

    // Filter branches
    List<Map<String, dynamic>> filteredBranches = _allBranches.where((branch) {
      // First check if the branch is active
      final branchStatus = branch['status'];
      if (branchStatus != 'active') {
        return false; // Skip branches that are not active
      }
      final branchType = branch['type']?.toString().toLowerCase() ?? branch['category']?.toString().toLowerCase() ?? '';
      final branchCategory = branch['category']?.toString().toLowerCase() ?? '';
      final companyCategory = branch['company']?['category']?.toString().toLowerCase() ?? '';
      final location = branch['location'];
      if (location == null || location['lat'] == null || location['lng'] == null) return false;
      // Type filter
      if (filters['type'] != null && filters['type'] != 'All' && filters['type'] != '') {
        if (branchType != filters['type'].toString().toLowerCase()) {
          return false;
        }
      }
      // Category filter
      if (filters['category'] != null && filters['category'] != 'All' && filters['category'] != '') {
        if (branchCategory != filters['category'].toString().toLowerCase() && companyCategory != filters['category'].toString().toLowerCase()) {
          return false;
        }
      }
      // Distance filter
      if (filters['distance'] != null) {
        double maxDistance = double.parse(filters['distance'].toString().replaceAll(' km', ''));
        double distance = _calculateDistance(
          _userLocation.latitude,
          _userLocation.longitude,
          location['lat'].toDouble(),
          location['lng'].toDouble(),
        );
        if (distance > maxDistance) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort branches
    if (filters['sortBy'] != null) {
      switch (filters['sortBy']) {
        case 'Most Popular':
          filteredBranches.sort((a, b) {
            final ratingA = a['rating']?.toDouble() ?? 0.0;
            final ratingB = b['rating']?.toDouble() ?? 0.0;
            return ratingB.compareTo(ratingA);
          });
          break;
        case 'Most Recent':
          filteredBranches.sort((a, b) {
            final dateA = a['createdAt'] != null ? DateTime.parse(a['createdAt']) : DateTime.now();
            final dateB = b['createdAt'] != null ? DateTime.parse(b['createdAt']) : DateTime.now();
            return dateB.compareTo(dateA);
          });
          break;
        case 'Closest':
          filteredBranches.sort((a, b) {
            double distA = _calculateDistance(
              _userLocation.latitude,
              _userLocation.longitude,
              a['location']['lat'].toDouble(),
              a['location']['lng'].toDouble(),
            );
            double distB = _calculateDistance(
              _userLocation.latitude,
              _userLocation.longitude,
              b['location']['lat'].toDouble(),
              b['location']['lng'].toDouble(),
            );
            return distA.compareTo(distB);
          });
          break;
      }
    }

    // Create markers for filtered branches
    _createMarkers(filteredBranches);

    if (_wayPointMarkers.isNotEmpty && _mapController != null) {
      _mapController.move(_wayPointMarkers[0].position, 15.0);
    }

    // if (filteredBranches.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('No branches found matching your filters')),
    //   );
    // }
  }

  void _createMarkers(List<Map<String, dynamic>> places) {
    setState(() {
      _wayPointMarkers = places.map((place) {
        return google_maps.Marker(
          markerId: google_maps.MarkerId('branch_${place['id']}'),
          position: google_maps.LatLng(place['latitude'], place['longitude']),
          onTap: () {
            setState(() {
              _selectedPlace = place;
            });
          },
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed),
        );
        print('Number of markers created: ${_wayPointMarkers.length}');
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Prioritize getting user location immediately upon login
    _getUserLocationOnLogin();
    
    _fetchUserData(); // Add this line to fetch user data
    if (_allCompanies.isEmpty) {
      _fetchCompanies().then((_) {
        // After companies are fetched, show nearby companies if location is already set
        if (_currentLocation != null || _initialLocationSet) {
          _showNearbyCompanies();
        }
      });
    }
    _fetchAllBranches();
    _fetchAllWholesalers();
    _loadSponsoredEntities(); // Add this line to load sponsored entities
    
    // Add search focus listener
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty) {
        setState(() {
          _showSearchResults = true;
        });
      }
    });
    // Add listener to search controller
    _searchController.addListener(_onSearchChanged);

    // Listen to map zoom changes to update marker size
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventMoveEnd) {
        final zoom = _mapController.zoom;
        double newSize = 40;
        if (zoom < 10) {
          newSize = 20;
        } else if (zoom < 13) {
          newSize = 28;
        } else if (zoom < 15) {
          newSize = 36;
        } else {
          newSize = 40;
        }
        if (newSize != _companyMarkerSize) {
          setState(() {
            _companyMarkerSize = newSize;
          });
        }
      }
    });

    // Ensure location tracking is always active
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _ensureLocationTracking();
      }
    });
  }

  // New method to get user location immediately upon login
  Future<void> _getUserLocationOnLogin() async {
    print('Getting user location on login...');
    
    // First check if location services are enabled
    bool serviceEnabled = await _locationTracker.serviceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled');
      serviceEnabled = await _locationTracker.requestService();
      if (!serviceEnabled) {
        print('User denied location service request');
        _setDefaultLocation();
        return;
      }
    }

    // Check location permission
    var permissionStatus = await _locationTracker.hasPermission();
    if (permissionStatus == permission.PermissionStatus.denied) {
      print('Requesting location permission...');
      permissionStatus = await _locationTracker.requestPermission();
      if (permissionStatus != permission.PermissionStatus.granted) {
        print('Location permission denied');
        _setDefaultLocation();
        return;
      }
    }

    // Get current location with high accuracy
    try {
      print('Getting current location with high accuracy...');
      var location = await _locationTracker.getLocation();
      
      if (location.latitude != null && location.longitude != null) {
        // Validate that the location is reasonable (not in the middle of the ocean)
        if (location.latitude! >= -90 && location.latitude! <= 90 && 
            location.longitude! >= -180 && location.longitude! <= 180) {
          
          print('Successfully got user location: ${location.latitude}, ${location.longitude}');
          
          setState(() {
            _currentLocation = latlong.LatLng(location.latitude!, location.longitude!);
            _initialLocationSet = true;
            _locationDenied = false;
          });
          
          // Move map to user's location immediately
          _mapController.move(_currentLocation!, 15.0);
          
          // Start continuous location tracking
          _startLocationTracking();
          
          // Show nearby companies after getting location
          _showNearbyCompanies();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Location found! Showing nearby places.'),
                ],
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          print('Invalid location coordinates received, using default Lebanon location');
          _setDefaultLocation();
        }
      } else {
        throw Exception('Location coordinates are null');
      }
    } catch (e) {
      print('Error getting user location on login: $e');
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    print('Setting default location (Beirut, Lebanon)');
    setState(() {
      _currentLocation = _defaultLocation;
      _initialLocationSet = true;
      _locationDenied = true;
    });
    
    // Ensure map controller is ready before moving
    if (_mapController != null) {
      _mapController.move(_defaultLocation, _defaultZoom);
      print('Map moved to Lebanon default location: ${_defaultLocation.latitude}, ${_defaultLocation.longitude}');
    }
    
    // Show message about using default location
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Showing Lebanon. Enable location services for your current location.'),
          ],
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _initLocationOrFallback() async {
    var status = await permission.Permission.location.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      // Permission denied, use default location
      setState(() {
        _currentLocation = _defaultLocation;
        _initialLocationSet = true;
        _locationDenied = true;
      });
      _mapController.move(_defaultLocation, _defaultZoom);
      return;
    }
    if (status.isGranted) {
      try {
        await _getCurrentLocation();
        // Start continuous location tracking immediately
        _startLocationTracking();
        setState(() {
          _locationDenied = false;
        });
      } catch (e) {
        print('Error getting initial location: $e');
        setState(() {
          _currentLocation = _defaultLocation;
          _initialLocationSet = true;
          _locationDenied = true;
        });
        _mapController.move(_defaultLocation, _defaultZoom);
      }
    } else {
      // Request permission if not granted
      
      var permissionStatus = await _locationTracker.requestPermission();
      if (permissionStatus == permission.PermissionStatus.granted) {
        try {
          await _getCurrentLocation();
          _startLocationTracking();
          setState(() {
            _locationDenied = false;
          });
        } catch (e) {
          print('Error getting location after permission: $e');
          setState(() {
            _currentLocation = _defaultLocation;
            _initialLocationSet = true;
            _locationDenied = true;
          });
          _mapController.move(_defaultLocation, _defaultZoom);
        }
      } else {
        // Permission denied, use default
        setState(() {
          _currentLocation = _defaultLocation;
          _initialLocationSet = true;
          _locationDenied = true;
        });
        _mapController.move(_defaultLocation, _defaultZoom);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Restart location tracking when app comes back to foreground
      _ensureLocationTracking();
    }
  }


  void _onSearchChanged() {
    // Cancel previous timer if it exists
    if (_searchDebounceTimer?.isActive ?? false) {
      _searchDebounceTimer!.cancel();
    }

    // Set a new timer to delay the search
    _searchDebounceTimer = Timer(Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      } else {
        setState(() {
          _showSearchResults = false;
        });
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }


    try {
      final List<Map<String, dynamic>> results = [];
      final String searchQuery = query.toLowerCase();

      // Check if the search query is related to wholesalers
      bool isWholesalerSearch = searchQuery.contains('wholesaler') || 
                               searchQuery.contains('wholesale') ||
                               searchQuery.contains('supplier') ||
                               searchQuery.contains('vendor');

      // Search in wholesalers
      _wholesalerService.getAllWholesalers().then((wholesalers) {
        for (var wholesaler in wholesalers) {
          // If it's a wholesaler search or the query matches wholesaler details
          if (isWholesalerSearch || 
              wholesaler.businessName.toLowerCase().contains(searchQuery) ||
              wholesaler.category.toLowerCase().contains(searchQuery) ||
              (wholesaler.address != null && (
                wholesaler.address!.city.toLowerCase().contains(searchQuery) ||
                wholesaler.address!.street.toLowerCase().contains(searchQuery)
              ))) {
            
            // Get location from first branch if available, otherwise use wholesaler's address
            double lat = 0.0;
            double lng = 0.0;
            String address = '';
            
            if (wholesaler.branches.isNotEmpty) {
              final branch = wholesaler.branches.first;
              lat = branch.location.lat;
              lng = branch.location.lng;
              address = '${branch.location.street}, ${branch.location.city}';
            } else if (wholesaler.address != null) {
              lat = wholesaler.address!.lat;
              lng = wholesaler.address!.lng;
              address = '${wholesaler.address!.street}, ${wholesaler.address!.city}';
            }

            if (lat != 0.0 && lng != 0.0) {
              // Calculate distance if current location is available
              double? distance;
              distance = _calculateDistance(
                _userLocation.latitude,
                _userLocation.longitude,
                lat,
                lng,
              );

              results.add({
                'name': wholesaler.businessName,
                'id': wholesaler.id,
                'latitude': lat,
                'longitude': lng,
                'address': address,
                'phone': wholesaler.phone,
                'description': wholesaler.category,
                'logoUrl': wholesaler.logoUrl,
                'companyName': wholesaler.businessName,
                'companyId': wholesaler.id,
                'images': wholesaler.branches.isNotEmpty ? wholesaler.branches.first.images : [],
                'distance': distance,
                'rating': 5, // Default rating for wholesaler
                'price': 'Wholesaler',
                'type': 'Wholesaler',
                'category': wholesaler.category,
              });
            }
          }

          // Search in wholesaler branches
          for (var branch in wholesaler.branches) {
            if (branch.status != 'active') continue;
            if (isWholesalerSearch ||
                branch.name.toLowerCase().contains(searchQuery) ||
                branch.category.toLowerCase().contains(searchQuery) ||
                branch.description.toLowerCase().contains(searchQuery) ||
                branch.location.city.toLowerCase().contains(searchQuery) ||
                branch.location.street.toLowerCase().contains(searchQuery)) {
              final lat = branch.location.lat;
              final lng = branch.location.lng;
              if (lat != 0.0 && lng != 0.0) {
                // Calculate distance if current location is available
                double? distance;
                distance = _calculateDistance(
                  _userLocation.latitude,
                  _userLocation.longitude,
                  lat,
                  lng,
                );
                results.add({
                  'name': branch.name,
                  'id': branch.id,
                  'latitude': lat,
                  'longitude': lng,
                  'address': '${branch.location.street}, ${branch.location.city}',
                  'phone': branch.phone,
                  'description': branch.description,
                  'logoUrl': wholesaler.logoUrl,
                  'companyName': wholesaler.businessName,
                  'companyId': wholesaler.id,
                  'images': branch.images,
                  'distance': distance,
                  'rating': 5, // Default rating for branch
                  'price': 'Wholesaler Branch',
                  'type': 'Wholesaler Branch',
                  'category': branch.category,
                });
              }
            }
          }
        }

        // Add existing search results from branches and companies if not a wholesaler-specific search
        if (!isWholesalerSearch && _allBranches.isNotEmpty) {
          for (var branch in _allBranches) {
            // Filter out branches whose status is not 'active'
            final branchStatus = branch['status'];
            if (branchStatus != 'active') {
              continue; // Skip this branch if it's not active
            }
            final name = branch['name']?.toString().toLowerCase() ?? '';
            final description = branch['description']?.toString().toLowerCase() ?? '';
            final category = branch['category']?.toString().toLowerCase() ?? '';
            final companyName = branch['company']?['businessName']?.toString().toLowerCase() ?? '';

            if (name.contains(searchQuery) ||
                description.contains(searchQuery) ||
                category.contains(searchQuery) ||
                companyName.contains(searchQuery)) {

              // Calculate distance if current location is available
              double? distance;
              if (branch['location'] != null) {
                distance = _calculateDistance(
                  _userLocation.latitude,
                  _userLocation.longitude,
                  branch['location']['lat'].toDouble(),
                  branch['location']['lng'].toDouble(),
                );
              }

              results.add({
                'name': branch['name'] ?? 'Unnamed Branch',
                'id': branch['id'],
                'latitude': branch['location']?['lat']?.toDouble(),
                'longitude': branch['location']?['lng']?.toDouble(),
                'address': '${branch['location']?['street'] ?? ''}, ${branch['location']?['city'] ?? ''}',
                'phone': branch['phone'] ?? '',
                'description': branch['description'] ?? '',
                'logoUrl': branch['company']?['logoUrl'],
                'companyName': branch['company']?['businessName'] ?? 'Unknown Company',
                'companyId': branch['company']?['id'],
                'images': branch['images'] ?? [],
                'distance': distance,
                'rating': 4,
                'price': (20 + (results.length * 5)).toString(),
                'type': 'Branch',
                'category': branch['category'] ?? 'Unknown Category'
              });
            }
          }
        }

        // Sort results by distance if current location is available
        results.sort((a, b) {
          final distanceA = a['distance'] as double? ?? double.infinity;
          final distanceB = b['distance'] as double? ?? double.infinity;
          return distanceA.compareTo(distanceB);
        });

        setState(() {
          _searchResults = results.take(10).toList(); // Show top 10 results
          _showSearchResults = _searchResults.isNotEmpty;
        });

        print('Search results for "${query}":');
        print('Found \\${results.length} total results');
        print('Showing top \\${_searchResults.length} results');
        for (var result in _searchResults) {
          print('\\${result['type']}: \\${result['name']} (\\${result['distance']?.toStringAsFixed(2)} km)');
        }
      });
    } catch (e) {
      print('Error performing search: $e');
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
    }
  }

  // Default location: Beirut, Lebanon - more centered in the country
  static const latlong.LatLng _defaultLocation = latlong.LatLng(33.8938, 35.5018);
  static const double _defaultZoom = 12.0; // Zoomed out to show more of Lebanon

  Future<void> _getCurrentLocation() async {
    try {
      // Configure location settings for better accuracy
      _locationTracker.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000, // Update every 1 second for faster response
        distanceFilter: 5, // Update when moved 5 meters
      );
      
      var locationData = await _locationTracker.getLocation();
      if (mounted) {
        setState(() {
          _currentLocation = latlong.LatLng(locationData.latitude!, locationData.longitude!);
          print('INITIAL USER LOCATION: Lat=${locationData.latitude}, Lng=${locationData.longitude}');
          if (!_initialLocationSet && _mapController != null) {
            _mapController.move(_currentLocation!, 15.0);
            _initialLocationSet = true;
          }
        });
        // After getting location, show nearby companies
        _showNearbyCompanies();
      }
    } catch (e) {
      print('Error getting location: $e');
      // Fallback to default location
      if (mounted) {
        setState(() {
          _currentLocation = _defaultLocation;
          if (!_initialLocationSet && _mapController != null) {
            _mapController.move(_defaultLocation, 15.0);
            _initialLocationSet = true;
          }
        });
        // After fallback, show nearby companies from default location
        _showNearbyCompanies();
      }
    }
  }

  // Show companies near the user's current location (within 5km)
  void _showNearbyCompanies() {
    if (_allCompanies.isEmpty || _userLocation == null) return;
    const double maxDistance = 5.0; // km
    final List<Map<String, dynamic>> nearbyCompanies = _allCompanies.where((company) {
      final companyLocation = company['location'];
      if (companyLocation == null || companyLocation['lat'] == null || companyLocation['lng'] == null) return false;
      final double lat = companyLocation['lat'].toDouble();
      final double lng = companyLocation['lng'].toDouble();
      final double distance = _calculateDistance(_userLocation.latitude, _userLocation.longitude, lat, lng);
      return distance <= maxDistance;
    }).toList();
    _createMarkersFromCompanies(nearbyCompanies);
    if (_wayPointMarkers.isNotEmpty && _mapController != null) {
      _mapController.move(_wayPointMarkers[0].position, 15.0);
    }
  }

  void _startLocationTracking() {
    _locationSubscription?.cancel();

    // Configure location settings for better accuracy and responsiveness
    _locationTracker.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 2000, // Update every 2 seconds for better responsiveness
      distanceFilter: 5, // Update when moved 5 meters for more precise tracking
    );

    _locationSubscription = _locationTracker.onLocationChanged.listen((locationData) {
      if (mounted) {
        setState(() {
          _currentLocation = latlong.LatLng(locationData.latitude!, locationData.longitude!);
          _locationAccuracy = locationData.accuracy ?? 0.0;
        });
        print('USER LIVE LOCATION: Lat=${locationData.latitude}, Lng=${locationData.longitude}, Accuracy: ${locationData.accuracy}m');

        // Auto-follow user when navigating
        if (_isNavigating && _destinationLocation != null) {
          _mapController.move(_currentLocation!, 15.0);

          double distanceToDestination = _calculateDistance(
              _currentLocation!.latitude, _currentLocation!.longitude,
              _destinationLocation!.latitude, _destinationLocation!.longitude
          );

          if (distanceToDestination <= 0.05) {
            _showDestinationReachedDialog();
            _stopNavigation();
          }
        }
      }
    });

    setState(() {
      _isTracking = true;
    });
  }

  void _showDestinationReachedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Destination Reached'),
          content: Text('You have arrived at your destination!'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    setState(() {
      _isTracking = false;
    });
  }

  // Method to ensure location tracking is always active
  void _ensureLocationTracking() {
    if (!_isTracking && !_locationDenied) {
      _startLocationTracking();
    }
  }

  // Method to recenter map to user's current location
  Future<void> _recenterToUserLocation() async {
    try {
      print('Recenter button pressed - getting current location...');
      
      // Check if map controller is ready
      if (_mapController == null) {
        print('Map controller is null, cannot recenter');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Map not ready yet. Please wait...'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
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
              Text('Getting your location...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
      
      // Configure location for high accuracy
      _locationTracker.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000,
        distanceFilter: 1, // Update when moved 1 meter for precise location
      );
      
      // Get fresh location data
      final locationData = await _locationTracker.getLocation();
      
      if (locationData.latitude != null && locationData.longitude != null) {
        print('Got location: ${locationData.latitude}, ${locationData.longitude}');
        
        setState(() {
          _currentLocation = latlong.LatLng(locationData.latitude!, locationData.longitude!);
        });
        
        // Move map to new location with smooth animation
        print('Moving map to user location...');
        _mapController.move(_currentLocation!, 15.0);
        
        // Wait a bit for the map to move, then show success message
        await Future.delayed(Duration(milliseconds: 500));
        
        // Show success message with accuracy
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Location updated (Accuracy: ${locationData.accuracy?.toStringAsFixed(1)}m)'),
                ],
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Show nearby companies after recentering
        _showNearbyCompanies();
        
        print('Recenter completed successfully');
      } else {
        throw Exception('Could not get location coordinates');
      }
    } catch (e) {
      print('Error getting current location: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Could not get your current location: ${e.toString()}'),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Check if location services are enabled
      try {
        if (!await _locationTracker.serviceEnabled()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please enable location services'),
                action: SnackBarAction(
                  label: 'SETTINGS',
                  onPressed: () {
                    _locationTracker.requestService();
                  },
                ),
              ),
            );
          }
        }
        
        // Check if permissions are granted
        var locationPermission = await _locationTracker.hasPermission();
        if (locationPermission == permission.PermissionStatus.denied) {
          locationPermission = await _locationTracker.requestPermission();
          if (locationPermission != permission.PermissionStatus.granted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Location permission is required'),
                  action: SnackBarAction(
                    label: 'SETTINGS',
                    onPressed: () async {
                      await permission.openAppSettings();
                    },
                  ),
                ),
              );
            }
          }
        }
      } catch (permissionError) {
        print('Error checking permissions: $permissionError');
      }
    }
  }

  Future<bool> _showChangeDestinationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change Destination?'),
          content: Text('Do you want to change your current destination?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Change'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _getRouteDirections() async {
    if (_currentLocation == null || _destinationLocation == null) return;

    try {
      final response = await http.get(Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
              '${_currentLocation!.longitude},${_currentLocation!.latitude};'
              '${_destinationLocation!.longitude},${_destinationLocation!.latitude}'
              '?overview=full&geometries=polyline&steps=true&alternatives=true'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] == null || data['routes'].isEmpty) {
          throw Exception('No route found');
        }

        final List<dynamic> routes = data['routes'];

        if (routes.isNotEmpty) {
          final primaryRoute = routes[0];
          final String polyline = primaryRoute['geometry'];

          final primaryPoints = _polylinePoints.decodePolyline(polyline);
          _primaryRouteCoordinates = primaryPoints
              .map((point) => latlong.LatLng(point.latitude, point.longitude))
              .toList();

          _primaryDistance = primaryRoute['distance'] / 1000;
          _primaryDuration = primaryRoute['duration'] / 60;

          _steps = [];
          if (primaryRoute['legs'] != null && primaryRoute['legs'].isNotEmpty &&
              primaryRoute['legs'][0]['steps'] != null) {
            _processRouteSteps(primaryRoute['legs'][0]['steps']);
          }
        }

        if (routes.length > 1) {
          final alternativeRoute = routes[1];
          final String altPolyline = alternativeRoute['geometry'];

          final alternativePoints = _polylinePoints.decodePolyline(altPolyline);
          _alternativeRouteCoordinates = alternativePoints
              .map((point) => latlong.LatLng(point.latitude, point.longitude))
              .toList();

          _alternativeDistance = alternativeRoute['distance'] / 1000;
          _alternativeDuration = alternativeRoute['duration'] / 60;
        } else {
          _alternativeRouteCoordinates = [];
          _alternativeDistance = 0;
          _alternativeDuration = 0;
        }

        _usingPrimaryRoute = true;
        _fitBounds();

      } else {
        throw Exception('Failed to load route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting route: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Could not calculate route: $e')),
      // );
      setState(() {
        _isNavigating = false;
      });
    }
  }

  void _processRouteSteps(List<dynamic> steps) {
    _steps = [];
    _wayPointMarkers = [];

    for (var step in steps) {
      _steps.add({
        'instruction': step['maneuver']['type'],
        'distance': step['distance'],
        'duration': step['duration'],
      });

      if (step['distance'] > 100) {
        final location = step['maneuver']['location'];
        if (location != null && location.length >= 2) {
          _wayPointMarkers.add(
            google_maps.Marker(
              markerId: google_maps.MarkerId('waypoint_${_wayPointMarkers.length}'),
              position: google_maps.LatLng(location[1], location[0]),
              icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
            ),
          );
        }
      }
    }
  }

  void _fitBounds() {
    List<latlong.LatLng> allPoints = [];

    if (_primaryRouteCoordinates.isNotEmpty) {
      allPoints.addAll(_primaryRouteCoordinates);
    }

    if (_alternativeRouteCoordinates.isNotEmpty) {
      allPoints.addAll(_alternativeRouteCoordinates);
    }

    if (allPoints.isEmpty) return;

    double minLat = allPoints.map((p) => p.latitude).reduce(Math.min);
    double maxLat = allPoints.map((p) => p.latitude).reduce(Math.max);
    double minLng = allPoints.map((p) => p.longitude).reduce(Math.min);
    double maxLng = allPoints.map((p) => p.longitude).reduce(Math.max);

    final google_maps.LatLngBounds bounds = google_maps.LatLngBounds(
      southwest: google_maps.LatLng(minLat - 0.05, minLng - 0.05),
      northeast: google_maps.LatLng(maxLat + 0.05, maxLng + 0.05),
    );

    _mapController.fitBounds(bounds, padding: EdgeInsets.all(50.0));
  }

  void _toggleRouteType() {
    if (_alternativeRouteCoordinates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No alternative route available')),
      );
      return;
    }

    setState(() {
      _usingPrimaryRoute = !_usingPrimaryRoute;
    });
  }

  void _clearRoute() {
    setState(() {
      _destinationLocation = null;
      _primaryRouteCoordinates = [];
      _alternativeRouteCoordinates = [];
      _routeInstructions = '';
      _isNavigating = false;
      _wayPointMarkers = [];
      _steps = [];
    });
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
  }




  void _searchPlace(String query) {
    if (query.isEmpty) return;

    setState(() {
      _wayPointMarkers.clear();
      _primaryRouteCoordinates.clear();
      _alternativeRouteCoordinates.clear();
    });

    // if (_allBranches.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('No branch data available. Please try again.')),
    //   );
    //   setState(() {
    //     _isLoading = false;
    //   });
    //   return;
    // }

    // Search for branches that match the query
    final matchedBranches = _allBranches.where((branch) {
      // First check if the branch is active
      final branchStatus = branch['status'];
      if (branchStatus != 'active') {
        return false; // Skip branches that are not active
      }
      final name = branch['name']?.toString().toLowerCase() ?? '';
      final description = branch['description']?.toString().toLowerCase() ?? '';
      final category = branch['category']?.toString().toLowerCase() ?? '';
      final companyName = branch['company']['businessName']?.toString().toLowerCase() ?? '';

      return name.contains(query.toLowerCase()) ||
          description.contains(query.toLowerCase()) ||
          category.contains(query.toLowerCase()) ||
          companyName.contains(query.toLowerCase());
    }).toList();

    // if (matchedBranches.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('No matches found for "$query"')),
    //   );
    //   setState(() {
    //     _isLoading = false;
    //   });
    //   return;
    // }

    setState(() {
      _wayPointMarkers = matchedBranches.map((branch) {
        final location = branch['location'];
        final company = branch['company'];
        final logoUrl = company['logoUrl'];

        if (location == null ||
            location['lat'] == null ||
            location['lng'] == null) {
          return null;
        }

        return google_maps.Marker(
          markerId: google_maps.MarkerId('branch_${branch['id']}'),
          position: google_maps.LatLng(
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          ),
          onTap: () {
            setState(() {
              _selectedPlace = {
                'name': branch['name'] ?? 'Unnamed Branch',
                '_id': branch['id'],
                'latitude': location['lat'].toDouble(),
                'longitude': location['lng'].toDouble(),
                'address': '${location['street'] ?? ''}, ${location['city'] ?? ''}',
                'phone': branch['phone'] ?? '',
                'description': branch['description'] ?? '',
                'image': logoUrl ?? 'assets/images/company_placeholder.png',
                'logoUrl': logoUrl,
                'companyName': company['businessName'] ?? 'Unknown Company',
                'companyId': company['id'],
                'images': branch['images'] ?? [],
                'category': branch['category'] ?? 'Unknown Category',
                'company': company,
              };
            });
          },
          icon: _isRestaurantCategory(branch['category']?.toString() ?? '') || _isRestaurantCategory(company['category']?.toString() ?? '')
              ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed)
              : _isHotelCategory(branch['category']?.toString() ?? '') || _isHotelCategory(company['category']?.toString() ?? '')
                  ? google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue)
                  : google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
        );
      }).where((marker) => marker != null).cast<google_maps.Marker>().toList();

    });

    // Move camera to the first match
    if (_wayPointMarkers.isNotEmpty && _mapController != null) {
      _mapController.move(_wayPointMarkers[0].position, 12.0);
    }
  }

  void _filterCompaniesByCategory(String categoryType) async {
    try {
      if (_allCompanies.isEmpty) {
        // If no companies have been fetched yet, fetch them
        await _fetchCompanies();
      }

      // Filter companies based on the selected category from the already fetched data
      final filteredCompanies = _allCompanies.where((company) {
        final companyInfo = company['companyInfo'];
        final category = companyInfo?['industryType']?.toString().toLowerCase() ?? '';
        return category == categoryType.toLowerCase();
      }).toList();

      // Log the filtering results for debugging
      print('Filtering companies by category: $categoryType');
      print('Found ${filteredCompanies.length} companies with this category');

      // if (filteredCompanies.isEmpty) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('No companies found in category: $categoryType')),
      //   );
      //   return;
      // }

      _createMarkersFromCompanies(filteredCompanies);

      // Move camera to the first marker
      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].position, 15.0);
      }
    } catch (e) {
      print('Error filtering companies by category: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to filter companies: $e')),
      // );
    }
  }



  void _searchPlacesByType(String placeType) {
    setState(() {
      _selectedCategory = placeType;
      _wayPointMarkers.clear();
      _primaryRouteCoordinates.clear();
      _alternativeRouteCoordinates.clear();
    });

    // First check if we have any branches
    if (_allBranches.isEmpty) {
      // If no branches, fetch them first
      _fetchAllBranches().then((_) {
        _filterBranchesByCategory(placeType);
      });
    } else {
      // If branches are already loaded, filter them directly
      _filterBranchesByCategory(placeType);
    }
  }

  void _showPlaceDetailsBottomSheet(Map<String, dynamic> place) {
    setState(() {
      _selectedPlace = place;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (!_isMapExpanded) {
            setState(() {
              _isMapExpanded = true;
            });
          }
          if (_isSidebarOpen) _toggleSidebar();
        },
        child: Stack(

          children: [
            // Test widget to verify restaurant icon loading
            _buildTestRestaurantIcon(),
            
            if (_locationDenied)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.orange.shade100,
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location is disabled. Showing results from Beirut.',
                          style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Column(
              children: [
                AppHeader(
                  profileImagePath: _profileImagePath,
                  onNotificationTap: () {
                    print('User Data: ${widget.userData}');
                    print('Profile Pic Path: $_profileImagePath');
                  },
                  onProfileTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsPage(),
                      ),
                    );
                  },
                  onMenuTap: _toggleSidebar,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child:
                            TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Search here...',
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.search, color: Colors.grey),
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
                              ),
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  _searchPlace(value);
                                  setState(() {
                                    _showSearchResults = false;
                                  });
                                }
                              },
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0094FF), Color(0xFF05055A), Color(0xFF0094FF)],
                                stops: [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            margin: EdgeInsets.all(4),
                            child: IconButton(
                              icon: Icon(Icons.filter_list, color: Colors.white),
                              onPressed: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => FilterPage(),
                                    fullscreenDialog: true,
                                  ),
                                );
                                if (result != null) {
                                  _applyFilters(result);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Top Listed Section
                _buildTopListedSection(),
                
                Expanded(
                  child: Stack(
                    children: [
                      MapComponent(
                        mapController: _mapController,
                        currentLocation: _currentLocation,
                        destinationLocation: _destinationLocation,
                        primaryRouteCoordinates: _primaryRouteCoordinates,
                        alternativeRouteCoordinates: _alternativeRouteCoordinates,
                        usingPrimaryRoute: _usingPrimaryRoute,
                        wayPointMarkers: _wayPointMarkers,
                        onMapTap: _setDestination,
                      ),

                      // Recenter button
                      Positioned(
                        top: 0,
                        right: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Debug button to test map controller
                            FloatingActionButton(
                              heroTag: "debug",
                              onPressed: () {
                                print('Debug button pressed!');
                                print('Map controller: $_mapController');
                                // Move to a fixed location (Beirut) to test if controller works
                                _mapController.move(const latlong.LatLng(33.8938, 35.5018), 15.0);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Debug: Moving to Beirut'),
                                    backgroundColor: Colors.purple,
                                  ),
                                );
                              },
                              backgroundColor: Colors.purple,
                              child: Icon(
                                Icons.bug_report,
                                color: Colors.white,
                                size: 20,
                              ),
                              mini: true,
                            ),
                            SizedBox(height: 8),
                            // Main recenter button
                            FloatingActionButton(
                              heroTag: "recenter",
                              onPressed: () {
                                print('Recenter button pressed!');
                                print('Map controller: $_mapController');
                                print('Current location: $_currentLocation');
                                
                                if (_currentLocation == null) {
                                  print('No current location available');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('No location available. Please wait...'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                
                                _recenterToUserLocation();
                              },
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.my_location,
                                color: Colors.blue,
                                size: 24,
                              ),
                              mini: true,
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        bottom: 120,
                        left: 0,
                        right: 0,
                        child: MediaQuery.of(context).viewInsets.bottom == 0
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  CategoryCircleButton(
                                    icon: Icons.local_gas_station,
                                    label: 'Stations',
                                    isSelected: _selectedCategory == 'Stations',
                                    onTap: () => _searchPlacesByType('Stations'),
                                  ),
                                  CategoryCircleButton(
                                    icon: Icons.restaurant,
                                    label: 'Restaurant',
                                    isSelected: _selectedCategory == 'Restaurant',
                                    onTap: () => _searchPlacesByType('Restaurant'),
                                  ),
                                  CategoryCircleButton(
                                    icon: Icons.hotel,
                                    label: 'Hotels',
                                    isSelected: _selectedCategory == 'Hotels',
                                    onTap: () => _searchPlacesByType('Hotels'),
                                  ),
                                  CategoryCircleButton(
                                    icon: Icons.shopping_cart,
                                    label: 'Shops',
                                    isSelected: _selectedCategory == 'Shops',
                                    onTap: () => _searchPlacesByType('Shops'),
                                  ),
                                ],
                              )
                            : SizedBox.shrink(),
                      ),
                      Positioned(
                        bottom: 42,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: MediaQuery.of(context).viewInsets.bottom == 0
                              ? GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isMapExpanded = !_isMapExpanded;
                                    });
                                  },
                                  child: Container(
                                    width: 300,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF0094FF), Color(0xFF05055A), Color(0xFF0094FF)],
                                        stops: [0.0, 0.5, 1.0],
                                      ),
                                      borderRadius: BorderRadius.circular(70),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.37),
                                          blurRadius: 6.8,
                                          offset: Offset(0, 7),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isMapExpanded ? 'Collapse Map' : 'Expand Map',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          _isMapExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_selectedPlace != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child:
                PlaceDetailsOverlay(
                  place: _selectedPlace!,
                  onClose: () {
                    setState(() {
                      _selectedPlace = null;
                    });
                  },
                  onNavigate: (latlong.LatLng destination) {
                    _setDestination(destination);
                    if (!_isTracking) {
                      _startLocationTracking();
                    }
                    setState(() {
                      _selectedPlace = null;
                    });
                  },
                  onBranchSelect: (latlong.LatLng branchLocation, String branchName) {
                    _mapController.move(branchLocation, 15.0);
                  },
                  token: widget.userData['token'],
                  duration: _primaryDuration, // Add this
                ),
              ),
            if (_showSearchResults && _searchResults.isNotEmpty)
              Positioned(
                top: 90, // Adjust this value to move the overlay down
                left: 16,
                right: 16,
                child: SearchResultsOverlay(
                  searchResults: _searchResults,
                  onResultTap: (place) {
                    setState(() {
                      _selectedPlace = place;
                      _showSearchResults = false;
                    });

                    if (place['latitude'] != null && place['longitude'] != null) {
                      _mapController.move(
                          google_maps.LatLng(place['latitude'], place['longitude']),
                          15.0
                      );
                    }
                  },
                  onClose: () {
                    setState(() {
                      _showSearchResults = false;
                    });
                  },
                ),
              ),
            if (!_isMapExpanded)
              CollapsedSheet(
                controller: null,
                onLocationCardTap: () {
                  // Handle location card tap
                },
              ),
            AnimatedPositioned(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              right: _isSidebarOpen ? 0 : -250,
              top: 0,
              bottom: 0,
              child: Sidebar(
                onCollapse: _toggleSidebar,
                parentContext: context, // Add this line
              ),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _fetchAllWholesalers() async {
    try {
      final wholesalers = await _wholesalerService.getAllWholesalers();
      // Filter wholesalers and their active branches
      final filteredWholesalers = wholesalers.where((wholesaler) {
        // Check if wholesaler has any active branches
        final hasActiveBranches = wholesaler.branches.any((branch) => branch.status == 'active');
        return hasActiveBranches;
      }).toList();
      
      // Print detailed wholesaler data for debugging
      print('\n=== WHOLESALER DATA DEBUG ===');
      print('Total wholesalers retrieved: ${filteredWholesalers.length}');
      
      for (var wholesaler in filteredWholesalers) {
        print('\n----------------------------------------');
        print('Wholesaler ID: ${wholesaler.id}');
        print('Business Name: ${wholesaler.businessName}');
        print('Category: ${wholesaler.category}');
        print('Sub Category: ${wholesaler.subCategory}');
        print('Phone: ${wholesaler.phone}');
        print('Email: ${wholesaler.email}');
        print('Logo URL: ${wholesaler.logoUrl}');
        
        // Print address information
        if (wholesaler.address != null) {
          print('\nAddress Information:');
          print('Country: ${wholesaler.address!.country}');
          print('District: ${wholesaler.address!.district}');
          print('City: ${wholesaler.address!.city}');
          print('Street: ${wholesaler.address!.street}');
          print('Postal Code: ${wholesaler.address!.postalCode}');
          print('Coordinates: ${wholesaler.address!.lat}, ${wholesaler.address!.lng}');
        } else {
          print('\nNo address information available');
        }
        
        // Print branches information
        print('\nBranches (${wholesaler.branches.length}):');
        for (var branch in wholesaler.branches) {
          print('\n  Branch: ${branch.name}');
          print('  Location: ${branch.location.city}, ${branch.location.street}');
          print('  Coordinates: ${branch.location.lat}, ${branch.location.lng}');
          print('  Phone: ${branch.phone}');
          print('  Category: ${branch.category}');
        }
        
        // Print contact information
        print('\nContact Information:');
        print('WhatsApp: ${wholesaler.contactInfo.whatsApp}');
        print('Website: ${wholesaler.contactInfo.website}');
        print('Facebook: ${wholesaler.contactInfo.facebook}');
        
        // Print social media information
        print('\nSocial Media:');
        print('Facebook: ${wholesaler.socialMedia.facebook}');
        print('Instagram: ${wholesaler.socialMedia.instagram}');
        
        print('----------------------------------------\n');
      }
      
      if (filteredWholesalers.isNotEmpty) {
        // Create markers for each wholesaler's active branches
        final wholesalerMarkers = filteredWholesalers.expand((wholesaler) {
          // Get only active branches
          final activeBranches = wholesaler.branches.where((b) => b.status == 'active');
          
          return activeBranches.map((branch) {
            double lat = branch.location.lat;
            double lng = branch.location.lng;
            String address = '${branch.location.street}, ${branch.location.city}';
            
            if (lat == 0.0 && lng == 0.0) return null;
            
            return google_maps.Marker(
              markerId: google_maps.MarkerId('wholesaler_${wholesaler.id}'),
              position: google_maps.LatLng(lat, lng),
              onTap: () {
                setState(() {
                  _selectedPlace = {
                    'name': wholesaler.businessName,
                    '_id': wholesaler.id,
                    'latitude': lat,
                    'longitude': lng,
                    'address': address,
                    'phone': wholesaler.phone,
                    'description': 'Wholesaler',
                    'image': wholesaler.logoUrl ?? 'assets/images/company_placeholder.png',
                    'logoUrl': wholesaler.logoUrl,
                    'companyName': wholesaler.businessName,
                    'companyId': wholesaler.id,
                    'images': wholesaler.branches.isNotEmpty ? wholesaler.branches.first.images : [],
                    'category': wholesaler.category,
                    'company': {
                      'businessName': wholesaler.businessName,
                      'logoUrl': wholesaler.logoUrl,
                      'id': wholesaler.id,
                    },
                  };
                });
              },
              icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
            );
          }).where((marker) => marker != null).cast<google_maps.Marker>();
        }).toList();

        print('\nCreated ${wholesalerMarkers.length} markers out of ${filteredWholesalers.length} wholesalers');

        setState(() {
          // Add wholesaler markers to existing markers
          _wayPointMarkers.addAll(wholesalerMarkers);
        });

        // Move camera to the first marker if no other markers are present
        if (_wayPointMarkers.isNotEmpty && _mapController != null) {
          _mapController.move(_wayPointMarkers[0].position, 15.0);
        }
      } else {
        print('No wholesalers found');
      }
    } catch (e) {
      print('Error fetching all wholesalers: $e');
      setState(() {
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load wholesalers: $e')),
      // );
    }
  }

  // Helper to always get a valid user location
  latlong.LatLng get _userLocation => _currentLocation ?? _defaultLocation;

  // Helper method to check if a category is restaurant-related
  bool _isRestaurantCategory(String category) {
    if (category.isEmpty) return false;
    
    final categoryLower = category.toLowerCase().trim();
    
    // Check for various restaurant-related category values
    return categoryLower == 'restaurant' ||
           categoryLower == 'food_dining' ||
           categoryLower == 'food & dining' ||
           categoryLower == 'food and dining' ||
           categoryLower == 'dining' ||
           categoryLower == 'cafe' ||
           categoryLower == 'fast food' ||
           categoryLower == 'fine dining' ||
           categoryLower == 'casual dining' ||
           categoryLower == 'bistro' ||
           categoryLower == 'bakery' ||
           categoryLower == 'dessert';
  }

  // Helper method to check if a category is hotel-related
  bool _isHotelCategory(String category) {
    if (category.isEmpty) return false;
    
    final categoryLower = category.toLowerCase().trim();
    
    // Check for various hotel-related category values
    return categoryLower == 'hotel' ||
           categoryLower == 'hotels' ||
           categoryLower == 'hospitality' ||
           categoryLower == 'accommodation' ||
           categoryLower == 'lodging' ||
           categoryLower == 'resort' ||
           categoryLower == 'motel' ||
           categoryLower == 'inn' ||
           categoryLower == 'guesthouse' ||
           categoryLower == 'bed and breakfast' ||
           categoryLower == 'bnb';
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) * Math.cos(_toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  // Convert degrees to radians
  double _toRadians(double degree) {
    return degree * Math.pi / 180;
  }

  Future<void> _setDestination(latlong.LatLng destination) async {
    if (_isNavigating) {
      // If already navigating, ask user if they want to change destination
      final shouldChange = await _showChangeDestinationDialog();
      if (!shouldChange) return;
    }

    setState(() {
      _destinationLocation = destination;
      _isNavigating = true;
    });

    await _getRouteDirections();
  }

  // Build Top Listed section
  Widget _buildTopListedSection() {
    if (_isLoadingSponsored) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading Top Listed...'),
            ],
          ),
        ),
      );
    }

    if (_sponsoredErrorMessage != null) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                _sponsoredErrorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSponsoredEntities,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final totalSponsored = _sponsoredCompanies.length + 
                           _sponsoredWholesalers.length + 
                           _sponsoredServiceProviders.length +
                           _sponsoredBranches.length;

    if (totalSponsored == 0) {
      return SizedBox.shrink(); // Don't show anything if no sponsored entities
    }

    return Container(
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Listed title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text(
                  'Top Listed (${totalSponsored})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ),
          
          // Horizontal scrollable list of sponsored entities
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Sponsored Companies
                  ..._sponsoredCompanies.map((company) => _buildSponsoredCompanyCard(company)),
                  
                  // Sponsored Wholesalers
                  ..._sponsoredWholesalers.map((wholesaler) => _buildSponsoredWholesalerCard(wholesaler)),
                  
                  // Sponsored Service Providers
                  ..._sponsoredServiceProviders.map((provider) => _buildSponsoredServiceProviderCard(provider)),
                  
                  // Sponsored Branches
                  ..._sponsoredBranches.map((branch) => _buildSponsoredBranchCard(branch)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build sponsored company card
  Widget _buildSponsoredCompanyCard(Map<String, dynamic> company) {
    final companyInfo = company['companyInfo'];
    final location = company['location'];
    final logoUrl = companyInfo?['logo'];

    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company logo section with sponsorship badge
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (logoUrl != null && logoUrl.isNotEmpty)
                    Image.network(
                      logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildSponsoredCompanyPlaceholder();
                      },
                    )
                  else
                    _buildSponsoredCompanyPlaceholder(),
                  
                  // Sponsorship badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 10),
                          SizedBox(width: 2),
                          Text(
                            'SPONSORED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company name
                Text(
                  companyInfo?['name'] ?? 'Unknown Company',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                // Category
                if (companyInfo?['category'] != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      companyInfo!['category'],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber[700],
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build sponsored wholesaler card
  Widget _buildSponsoredWholesalerCard(Map<String, dynamic> wholesaler) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wholesaler logo section with sponsorship badge
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildSponsoredWholesalerPlaceholder(),
                  
                  // Sponsorship badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 10),
                          SizedBox(width: 2),
                          Text(
                            'SPONSORED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business name
                Text(
                  wholesaler['businessName'] ?? 'Unknown Wholesaler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                // Category
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    wholesaler['category'] ?? 'Unknown Category',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build sponsored service provider card
  Widget _buildSponsoredServiceProviderCard(Map<String, dynamic> provider) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.purple, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service provider logo section with sponsorship badge
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildSponsoredServiceProviderPlaceholder(),
                  
                  // Sponsorship badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 10),
                          SizedBox(width: 2),
                          Text(
                            'SPONSORED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service provider name
                Text(
                  'Service Provider',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                // Category
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Professional Services',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build sponsored branch card
  Widget _buildSponsoredBranchCard(Map<String, dynamic> branch) {
    final branchInfo = branch['branchInfo'];
    final location = branch['location'];
    final logoUrl = branchInfo?['logo'];

    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch logo section with sponsorship badge
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (logoUrl != null && logoUrl.isNotEmpty)
                    Image.network(
                      logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildSponsoredBranchPlaceholder();
                      },
                    )
                  else
                    _buildSponsoredBranchPlaceholder(),
                  
                  // Sponsorship badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 10),
                          SizedBox(width: 2),
                          Text(
                            'SPONSORED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branch name
                Text(
                  branch['name'] ?? 'Unknown Branch',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                // Category
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    branch['category'] ?? 'Unknown Category',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder widgets for sponsored entities
  Widget _buildSponsoredCompanyPlaceholder() {
    return Container(
      color: Colors.amber.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 30, color: Colors.amber),
            SizedBox(height: 4),
            Text(
              'Sponsored',
              style: TextStyle(
                color: Colors.amber[700],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsoredWholesalerPlaceholder() {
    return Container(
      color: Colors.green.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 30, color: Colors.green),
            SizedBox(height: 4),
            Text(
              'Sponsored',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsoredServiceProviderPlaceholder() {
    return Container(
      color: Colors.purple.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 30, color: Colors.purple),
            SizedBox(height: 4),
            Text(
              'Sponsored',
              style: TextStyle(
                color: Colors.purple[700],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsoredBranchPlaceholder() {
    return Container(
      color: Colors.blue.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 30, color: Colors.blue),
            SizedBox(height: 4),
            Text(
              'Sponsored',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
