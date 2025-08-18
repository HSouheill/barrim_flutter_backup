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
import 'dart:typed_data';
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

  // Add category data for custom markers
  Map<String, Map<String, dynamic>> _categoryData = {};

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

  // Add method to fetch category data for custom markers
  Future<void> _fetchCategoryData() async {
    try {
      print('Fetching category data for custom markers...');
      final categories = await ApiService.getAllCategoriesWithLogos();
      setState(() {
        _categoryData = categories;
      });
      print('Successfully fetched ${categories.length} categories with logos and colors');
      print('Category data structure:');
      categories.forEach((categoryName, data) {
        print('Category: "$categoryName", Color: ${data['color']}, Logo: ${data['logo']}');
      });
      print('Category keys: ${categories.keys.toList()}');
    } catch (e) {
      print('Error fetching category data: $e');
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

        // Debug: Print available categories in branch data
        print('\n=== AVAILABLE CATEGORIES IN BRANCH DATA ===');
        Set<String> availableCategories = {};
        for (var branch in filteredBranches) {
          final branchCategory = branch['category']?.toString() ?? '';
          final companyCategory = branch['company']?['category']?.toString() ?? '';
          if (branchCategory.isNotEmpty) availableCategories.add(branchCategory);
          if (companyCategory.isNotEmpty) availableCategories.add(companyCategory);
        }
        print('Available categories: ${availableCategories.toList()}');
        print('Category data keys: ${_categoryData.keys.toList()}');
        print('===========================================\n');
      });

      // Create markers for filtered branches
      final branchMarkers = await Future.wait(filteredBranches.map((branch) async {
        final location = branch['location'];
        final company = branch['company'];
        final logoUrl = company?['logoUrl'];
        final category = branch['category']?.toString() ?? company?['category']?.toString() ?? '';

        print('Processing branch: ${branch['name']}, Location: $location, Company: $company');

        // Validate location data
        if (location == null ||
            location['lat'] == null ||
            location['lng'] == null) {
          print('Branch ${branch['name']} has invalid location data');
          return null;
        }
        
        print('Creating marker for branch: ${branch['name']} at lat: ${location['lat']}, lng: ${location['lng']}');

        print('Branch category: "$category"');
        // Create custom marker based on category with dynamic color and logo
        final customIcon = await _createCategoryMarkerIcon(category);

        return google_maps.Marker(
          markerId: google_maps.MarkerId('branch_${branch['id']}'),
          position: google_maps.LatLng(
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          ),
          onTap: () {
            print('Branch marker tapped: ${branch['name']}');
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
                'category': category,
                'company': company,
                'type': 'branch',
                'status': 'active',
              };
            });
            print('_selectedPlace set to: ${_selectedPlace?['name']}');
            print('_selectedPlace is now: ${_selectedPlace != null ? 'NOT NULL' : 'NULL'}');
          },
          icon: customIcon,
          visible: true, // Ensure marker is always visible
        );
      })).then((markers) => markers.where((marker) => marker != null).cast<google_maps.Marker>().toList());

      print('Created ${branchMarkers.length} branch markers');

      // Remove test marker - it was causing duplicate markers at same location
      // The branch marker already handles the onTap functionality

      setState(() {
        // Add branch markers to existing company markers
        _wayPointMarkers.addAll(branchMarkers);
        print('Total markers on map: ${_wayPointMarkers.length} (${branchMarkers.length} branch markers)');
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
          final category = branch['category']?.toString() ?? company['category']?.toString() ?? '';

          if (location == null ||
              location['lat'] == null ||
              location['lng'].toDouble() == null) {
            return null;
          }

          // Create dynamic marker based on category
          google_maps.BitmapDescriptor markerIcon;
          
          // Check if we have category data loaded
          if (_categoryData.containsKey(category)) {
            final categoryInfo = _categoryData[category]!;
            final String color = categoryInfo['color'] ?? '#2079C2';
            
            // Convert hex color to marker hue
            markerIcon = _getMarkerHueFromColor(color);
            print('Using dynamic color for category $category: $color');
          } else {
            // Fallback to default colors based on category type
            if (_isRestaurantCategory(category)) {
              markerIcon = google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed);
            } else if (_isHotelCategory(category)) {
              markerIcon = google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue);
            } else {
              // Use custom business marker instead of green
              markerIcon = _getCategoryMarkerIconSync(category);
            }
            print('Using fallback color for category $category');
          }

          return google_maps.Marker(
            markerId: google_maps.MarkerId('branch_${branch['id']}'),
            position: google_maps.LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
            onTap: () {
              print('Filtered branch marker tapped: ${branch['name']}');
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
                  'type': 'branch',
                  'status': 'active',
                };
              });
              print('_selectedPlace set to: ${_selectedPlace?['name']}');
              print('_selectedPlace is now: ${_selectedPlace != null ? 'NOT NULL' : 'NULL'}');
            },
            icon: markerIcon,
            visible: true, // Ensure marker is always visible
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
                      print('_selectedPlace set to company: ${_selectedPlace?['name']}');
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
                    print('_selectedPlace set to company (fallback): ${_selectedPlace?['name']}');
                  }
                },
                icon: _getCategoryMarkerIconSync(companyInfo?['category']?.toString() ?? ''),
                visible: true, // Ensure marker is always visible
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
                      print('Company branch marker tapped: ${branch['name']}');
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
                          'status': 'active',
                        };
                      });
                      print('_selectedPlace set to company branch: ${_selectedPlace?['name']}');
                    },
                    icon: _getCategoryMarkerIconSync(branch['category']?.toString() ?? ''),
                    visible: true, // Ensure marker is always visible
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
          visible: true, // Ensure marker is always visible
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
                  'type': 'company',
                  'category': companyInfo?['category'] ?? 'Unknown Category',
                  'status': 'active',
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
                'type': 'company',
                'category': companyInfo?['category'] ?? 'Unknown Category',
                'status': 'active',
              };
            });
          }
        },
        icon: _getCategoryMarkerIconSync(companyInfo?['category']?.toString() ?? ''),
      );
    }).where((marker) => marker != null).cast<google_maps.Marker>().toList();
  });

    print('Number of markers created: ${_wayPointMarkers.length}');
  }

  void _applyFilters(Map<String, dynamic> filters) async {
    print('Applying filters: $filters'); // Debug log
    
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
      if (filters['category'] != null && filters['category'] != 'All' && filters['category'] != '') {
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
      final wholesalerMarkers = await Future.wait(filteredWholesalers.map((wholesaler) async {
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
        
        final customIcon = await _createWholesalerMarkerIcon();
        
        return google_maps.Marker(
          markerId: google_maps.MarkerId('wholesaler_${wholesaler.id}'),
          position: google_maps.LatLng(lat, lng),
          visible: true, // Ensure marker is always visible
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
                'type': 'Wholesaler',
                'status': 'active',
              };
            });
          },
          icon: customIcon,
        );
      })).then((markers) => markers.where((marker) => marker != null).cast<google_maps.Marker>().toList());

      setState(() {
        _wayPointMarkers = wholesalerMarkers;
      });

      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].position, 15.0);
      }

      print('Filtered wholesalers: ${filteredWholesalers.length}');
      return;
    }

    // Otherwise, filter branches
    if (_allBranches.isEmpty) {
      await _fetchAllBranches();
    }

    print('Total branches available for filtering: ${_allBranches.length}');

    // Filter branches
    List<Map<String, dynamic>> filteredBranches = _allBranches.where((branch) {
      // First check if the branch is active
      final branchStatus = branch['status'];
      if (branchStatus != 'active') {
        return false; // Skip branches that are not active
      }
      
      final location = branch['location'];
      if (location == null || location['lat'] == null || location['lng'] == null) return false;
      
      // Category filter - check both branch category and company category
      if (filters['category'] != null && filters['category'] != 'All' && filters['category'] != '') {
        final branchCategory = branch['category']?.toString().toLowerCase() ?? '';
        final companyCategory = branch['company']?['category']?.toString().toLowerCase() ?? '';
        final filterCategory = filters['category'].toString().toLowerCase();
        
        // Debug logging for category matching
        print('Checking category for branch ${branch['name']}:');
        print('  Branch category: "$branchCategory"');
        print('  Company category: "$companyCategory"');
        print('  Filter category: "$filterCategory"');
        
        // Check if either branch or company category matches the filter
        // Use contains() for more flexible matching
        bool categoryMatches = branchCategory.contains(filterCategory) || 
                              companyCategory.contains(filterCategory) ||
                              filterCategory.contains(branchCategory) ||
                              filterCategory.contains(companyCategory);
        
        if (!categoryMatches) {
          print('  ❌ Category does not match - filtering out');
          return false;
        } else {
          print('  ✅ Category matches - keeping branch');
        }
      }
      
      // Subcategory filter (if implemented)
      if (filters['subcategory'] != null && filters['subcategory'] != 'All' && filters['subcategory'] != '') {
        final branchSubCategory = branch['subcategory']?.toString().toLowerCase() ?? '';
        final companySubCategory = branch['company']?['subcategory']?.toString().toLowerCase() ?? '';
        final filterSubCategory = filters['subcategory'].toString().toLowerCase();
        
        if (!branchSubCategory.contains(filterSubCategory) && !companySubCategory.contains(filterSubCategory)) {
          print('Branch ${branch['name']} filtered out by subcategory: branch=$branchSubCategory, company=$companySubCategory, filter=$filterSubCategory');
          return false;
        }
      }
      
      // Distance filter
      if (filters['distance'] != null && filters['distance'] != '') {
        try {
          double maxDistance = double.parse(filters['distance'].toString().replaceAll(' km', ''));
          double distance = _calculateDistance(
            _userLocation.latitude,
            _userLocation.longitude,
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          );
          if (distance > maxDistance) {
            print('Branch ${branch['name']} filtered out by distance: $distance > $maxDistance km');
            return false;
          }
        } catch (e) {
          print('Error parsing distance filter: $e');
        }
      }
      
      return true;
    }).toList();

    print('Branches after filtering: ${filteredBranches.length}');

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

    print('Final filtered markers: ${_wayPointMarkers.length}');
  }

  void _createMarkers(List<Map<String, dynamic>> places) {
    setState(() {
      _wayPointMarkers = places.map((place) {
        // Extract location data - handle both direct lat/lng and nested location structure
        double latitude, longitude;
        
        if (place['latitude'] != null && place['longitude'] != null) {
          // Direct lat/lng fields
          latitude = place['latitude'].toDouble();
          longitude = place['longitude'].toDouble();
        } else if (place['location'] != null) {
          // Nested location structure
          final location = place['location'];
          if (location['lat'] != null && location['lng'] != null) {
            latitude = location['lat'].toDouble();
            longitude = location['lng'].toDouble();
          } else {
            print('Invalid location data for place: ${place['name']}');
            return null;
          }
        } else {
          print('No location data found for place: ${place['name']}');
          return null;
        }
        
        // Get category for dynamic marker
        final category = place['category']?.toString() ?? '';
        
        // Create dynamic marker based on category
        google_maps.BitmapDescriptor markerIcon;
        
        // Check if we have category data loaded
        if (_categoryData.containsKey(category)) {
          final categoryInfo = _categoryData[category]!;
          final String color = categoryInfo['color'] ?? '#2079C2';
          
          // Convert hex color to marker hue
          markerIcon = _getMarkerHueFromColor(color);
          print('Using dynamic color for category $category: $color');
        } else {
          // Fallback to default colors based on category type
          if (_isRestaurantCategory(category)) {
            markerIcon = google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed);
          } else if (_isHotelCategory(category)) {
            markerIcon = google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue);
          } else {
            // Use custom business marker instead of green
            markerIcon = _getCategoryMarkerIconSync(category);
          }
          print('Using fallback color for category $category');
        }
        
        return google_maps.Marker(
          markerId: google_maps.MarkerId('branch_${place['id'] ?? place['_id']}'),
          position: google_maps.LatLng(latitude, longitude),
          onTap: () {
            print('Created marker tapped: ${place['name']}');
            setState(() {
              _selectedPlace = place;
            });
            print('_selectedPlace set to: ${_selectedPlace?['name']}');
            print('_selectedPlace is now: ${_selectedPlace != null ? 'NOT NULL' : 'NULL'}');
          },
          icon: markerIcon,
          visible: true, // Ensure marker is always visible
        );
      }).where((marker) => marker != null).cast<google_maps.Marker>().toList();
      
      print('Number of markers created: ${_wayPointMarkers.length}');
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Prioritize getting user location immediately upon login
    _getUserLocationOnLogin();
    
    _fetchUserData(); // Add this line to fetch user data
    
    // Fetch category data first, then fetch branches and companies
    _fetchCategoryData().then((_) {
      print('Category data loaded, now fetching branches and companies');
      
      // Test color conversion
      _testColorConversion();
      
      if (_allCompanies.isEmpty) {
        _fetchCompanies().then((_) {
          // After companies are fetched, show nearby companies if location is already set
          if (_currentLocation != null || _initialLocationSet) {
            _showNearbyCompanies();
          }
        });
      }
      _fetchAllBranches();
      _fetchAllWholesalers().catchError((e) {
        print('Error fetching wholesalers: $e');
      });
    });
    
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
        final category = branch['category']?.toString() ?? company['category']?.toString() ?? '';

        if (location == null ||
            location['lat'] == null ||
            location['lng'] == null) {
          return null;
        }

        // Create dynamic marker based on category
        google_maps.BitmapDescriptor markerIcon;
        
        // Check if we have category data loaded
        if (_categoryData.containsKey(category)) {
          final categoryInfo = _categoryData[category]!;
          final String color = categoryInfo['color'] ?? '#2079C2';
          
          // Convert hex color to marker hue
          markerIcon = _getMarkerHueFromColor(color);
          print('Search result - Using dynamic color for category $category: $color');
        } else {
          // Fallback to default colors based on category type
          if (_isRestaurantCategory(category)) {
            markerIcon = google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed);
          } else if (_isHotelCategory(category)) {
            markerIcon = google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue);
          } else {
            // Use custom business marker instead of green
            markerIcon = _getCategoryMarkerIconSync(category);
          }
          print('Search result - Using fallback color for category $category');
        }

        return google_maps.Marker(
          markerId: google_maps.MarkerId('branch_${branch['id']}'),
          position: google_maps.LatLng(
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          ),
                      onTap: () {
              print('Search result marker tapped: ${branch['name']}');
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
                  'type': 'branch',
                  'status': 'active',
                };
              });
              print('_selectedPlace set to: ${_selectedPlace?['name']}');
              print('_selectedPlace is now: ${_selectedPlace?['name'] != null ? 'NOT NULL' : 'NULL'}');
            },
          icon: markerIcon,
          visible: true, // Ensure marker is always visible
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
    print('Building UserDashboard, _selectedPlace: ${_selectedPlace?['name'] ?? 'NULL'}');
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
                        child: FloatingActionButton(
                          heroTag: "recenter",
                          onPressed: () {
                            print('Recenter button pressed!');
                            print('Map controller: $_mapController');
                            print('Current location: $_currentLocation');
                            
                            // if (_currentLocation == null) {
                            //   print('No current location available');
                            //   ScaffoldMessenger.of(context).showSnackBar(
                            //     SnackBar(
                            //       content: Text('No location available. Please wait...'),
                            //       backgroundColor: Colors.orange,
                            //     ),
                            //   );
                            //   return;
                            // }
                            
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
                    print('PlaceDetailsOverlay closing for: ${_selectedPlace?['name']}');
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
        print('Creating markers for ${filteredWholesalers.length} wholesalers...');
        
        // Create markers for each wholesaler's active branches
        final wholesalerMarkers = await Future.wait(filteredWholesalers.expand((wholesaler) {
          // Get only active branches
          final activeBranches = wholesaler.branches.where((b) => b.status == 'active');
          print('Wholesaler ${wholesaler.businessName} has ${activeBranches.length} active branches');
          
          return activeBranches.map((branch) async {
            double lat = branch.location.lat;
            double lng = branch.location.lng;
            String address = '${branch.location.street}, ${branch.location.city}';
            
            print('Creating marker for branch ${branch.name} at lat: $lat, lng: $lng');
            
            if (lat == 0.0 && lng == 0.0) {
              print('Branch ${branch.name} has invalid coordinates, skipping');
              return null;
            }
            
            // Additional validation for coordinates
            if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
              print('Branch ${branch.name} has out-of-range coordinates: lat=$lat, lng=$lng, skipping');
              return null;
            }
            
            final customIcon = await _createWholesalerMarkerIcon();
            
            final markerId = 'wholesaler_branch_${wholesaler.id}_${branch.id}_${DateTime.now().millisecondsSinceEpoch}';
            print('Creating marker with ID: $markerId');
            
            return google_maps.Marker(
              markerId: google_maps.MarkerId(markerId),
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
                    'type': 'Wholesaler',
                    'status': 'active',
                  };
                });
              },
              icon: customIcon,
              visible: true, // Ensure marker is always visible
            );
          });
        }).toList()).then((markers) => markers.where((marker) => marker != null).cast<google_maps.Marker>().toList());

        print('\nCreated ${wholesalerMarkers.length} markers out of ${filteredWholesalers.length} wholesalers');
        
        // Debug: Print details of each created marker
        for (int i = 0; i < wholesalerMarkers.length; i++) {
          final marker = wholesalerMarkers[i];
          print('Marker $i: ID=${marker.markerId.value}, Position=${marker.position}, Visible=${marker.visible}');
        }

        setState(() {
          // Add wholesaler markers to existing markers
          _wayPointMarkers.addAll(wholesalerMarkers);
          print('Added ${wholesalerMarkers.length} wholesaler markers to map');
          print('Total markers on map now: ${_wayPointMarkers.length}');
          
          // Force a rebuild of the map to show new markers
          if (mounted) {
            print('Forcing map rebuild to show new wholesaler markers');
          }
        });

        // Move camera to the first marker if no other markers are present
        if (_wayPointMarkers.isNotEmpty && _mapController != null) {
          // Add a small delay to ensure the map is ready
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted && _wayPointMarkers.isNotEmpty) {
              try {
                _mapController.move(_wayPointMarkers[0].position, 15.0);
                print('Moved camera to first wholesaler marker at: ${_wayPointMarkers[0].position}');
              } catch (e) {
                print('Error moving camera to wholesaler marker: $e');
              }
            }
          });
        } else {
          print('Cannot move camera: markers=${_wayPointMarkers.isNotEmpty}, controller=${_mapController != null}');
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

  // Helper method to create custom wholesaler marker icon
  Future<google_maps.BitmapDescriptor> _createWholesalerMarkerIcon() async {
    try {
      print('Loading wholesaler icon from assets...');
      final ByteData data = await rootBundle.load('assets/icons/wholesaler.png');
      final Uint8List bytes = data.buffer.asUint8List();
      print('Successfully loaded wholesaler icon, size: ${bytes.length} bytes');
      return google_maps.BitmapDescriptor.fromBytes(bytes);
    } catch (e) {
      print('Error loading wholesaler icon: $e');
      print('Falling back to default orange marker');
      // Fallback to default orange marker if image loading fails
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueOrange);
    }
  }

  // Helper method to create custom business marker icon
  Future<google_maps.BitmapDescriptor> _createCustomBusinessMarkerIcon() async {
    try {
      print('Loading custom business icon from assets...');
      final ByteData data = await rootBundle.load('assets/icons/business.png');
      final Uint8List bytes = data.buffer.asUint8List();
      print('Successfully loaded custom business icon, size: ${bytes.length} bytes');
      return google_maps.BitmapDescriptor.fromBytes(bytes);
    } catch (e) {
      print('Error loading custom business icon: $e');
      print('Falling back to default blue marker');
      // Fallback to default blue marker if image loading fails
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue);
    }
  }

  // Helper method to create custom category marker icon
  Future<google_maps.BitmapDescriptor> _createCategoryMarkerIcon(String categoryName) async {
    try {
      print('_createCategoryMarkerIcon called for category: "$categoryName"');
      print('Available categories in _categoryData: ${_categoryData.keys.toList()}');
      
      // Find the correct category name (case-insensitive)
      final String? actualCategoryName = _findCategoryName(categoryName);
      if (actualCategoryName == null) {
        print('No category data found for: $categoryName, using default marker');
        return _getCategoryMarkerIconSync(categoryName);
      }
      
      // Get category data using the correct name
      final categoryInfo = _categoryData[actualCategoryName]!;

      final String? logoUrl = categoryInfo['logo'];
      final String color = categoryInfo['color'] ?? '#2079C2';
      print('Category info found: logo=$logoUrl, color=$color');
      print('Using category name: $actualCategoryName');

      if (logoUrl == null || logoUrl.isEmpty) {
        print('No logo found for category: $categoryName, using colored marker');
        // Convert hex color to hue for default marker
        final result = _getMarkerHueFromColor(color);
        print('Converted color $color to marker hue: $result');
        return result;
      }

      // Try to load the logo image
      try {
        // If it's a network image, we'll need to download it first
        if (logoUrl.startsWith('http')) {
          // For network images, we'll use a colored marker with the category color
          print('Network logo for category: $categoryName, using colored marker');
          return _getMarkerHueFromColor(color);
        } else {
          // For local assets, try to load them
          final ByteData data = await rootBundle.load(logoUrl);
          final Uint8List bytes = data.buffer.asUint8List();
          return google_maps.BitmapDescriptor.fromBytes(bytes);
        }
      } catch (e) {
        print('Error loading logo for category: $categoryName, using colored marker. Error: $e');
        return _getMarkerHueFromColor(color);
      }
    } catch (e) {
      print('Error creating category marker for: $categoryName, using default. Error: $e');
      return _getCategoryMarkerIconSync(categoryName);
    }
  }

  // Test function to verify color conversion
  void _testColorConversion() {
    print('=== Testing Color Conversion ===');
    final testColors = ['#2079C2', '#FF1708', '#00FF00', '#FF0000'];
    
    for (String color in testColors) {
      print('Testing color: $color');
      final result = _getMarkerHueFromColor(color);
      print('Result: $result');
      print('---');
    }
    print('=== End Color Conversion Test ===');
  }

  // Helper method to find category name regardless of case
  String? _findCategoryName(String categoryName) {
    if (categoryName.isEmpty) return null;
    
    print('Looking for category: "$categoryName"');
    print('Available categories: ${_categoryData.keys.toList()}');
    
    // First try exact match
    if (_categoryData.containsKey(categoryName)) {
      print('Found exact match for: "$categoryName"');
      return categoryName;
    }
    
    // Try case-insensitive match
    for (String key in _categoryData.keys) {
      if (key.toLowerCase() == categoryName.toLowerCase()) {
        print('Found case-insensitive match: "$categoryName" -> "$key"');
        return key;
      }
    }
    
    print('No category match found for: "$categoryName"');
    return null;
  }

  // Helper method to convert hex color to marker hue
  google_maps.BitmapDescriptor _getMarkerHueFromColor(String hexColor) {
    try {
      print('Converting hex color: $hexColor');
      
      // Remove # if present
      String color = hexColor.startsWith('#') ? hexColor.substring(1) : hexColor;
      print('Color without #: $color');
      
      // Convert hex to RGB
      int r = int.parse(color.substring(0, 2), radix: 16);
      int g = int.parse(color.substring(2, 4), radix: 16);
      int b = int.parse(color.substring(4, 6), radix: 16);
      print('RGB values: R=$r, G=$g, B=$b');
      
      // Convert RGB to HSV to get hue
      double hue = _rgbToHue(r, g, b);
      print('Calculated hue: $hue');
      
      // Map hue to predefined Google Maps marker colors based on our calculated hue
      // This is more reliable than using custom hue values
      if (hue >= 0 && hue < 30) {
        // Red range
        print('Using red marker for hue: $hue');
        return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed);
      } else if (hue >= 30 && hue < 90) {
        // Orange/Yellow range
        print('Using orange marker for hue: $hue');
        return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueOrange);
      } else if (hue >= 90 && hue < 150) {
        // Green range - use custom business marker instead
        print('Using custom business marker for hue: $hue');
        return _getCategoryMarkerIconSync('business');
      } else if (hue >= 150 && hue < 210) {
        // Cyan/Blue range
        print('Using cyan marker for hue: $hue');
        return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueCyan);
      } else if (hue >= 210 && hue < 270) {
        // Blue range
        print('Using blue marker for hue: $hue');
        return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue);
      } else if (hue >= 270 && hue < 330) {
        // Magenta range
        print('Using magenta marker for hue: $hue');
        return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueViolet);
      } else {
        // Red range (330-360)
        print('Using red marker for hue: $hue');
        return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed);
      }
    } catch (e) {
      print('Error converting color $hexColor to hue, using default: $e');
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen);
    }
  }

  // Helper method to convert RGB to Hue
  double _rgbToHue(int r, int g, int b) {
    print('_rgbToHue called with R=$r, G=$g, B=$b');
    
    // Normalize RGB values to 0-1 range using double division
    double rNorm = r / 255.0;
    double gNorm = g / 255.0;
    double bNorm = b / 255.0;
    print('Normalized RGB: R=${rNorm.toStringAsFixed(3)}, G=${gNorm.toStringAsFixed(3)}, B=${bNorm.toStringAsFixed(3)}');
    
    double max = [rNorm, gNorm, bNorm].reduce((a, b) => a > b ? a : b);
    double min = [rNorm, gNorm, bNorm].reduce((a, b) => a < b ? a : b);
    double delta = max - min;
    print('Max=${max.toStringAsFixed(3)}, Min=${min.toStringAsFixed(3)}, Delta=${delta.toStringAsFixed(3)}');
    
    double hue = 0;
    
    if (delta == 0) {
      hue = 0;
    } else if (max == rNorm) {
      hue = ((gNorm - bNorm) / delta) % 6;
    } else if (max == gNorm) {
      hue = (bNorm - rNorm) / delta + 2;
    } else if (max == bNorm) {
      hue = (rNorm - gNorm) / delta + 4;
    }
    
    hue = hue * 60;
    if (hue < 0) hue += 360;
    print('Calculated hue: $hue');
    
    // Convert to Google Maps hue range (0-360)
    print('Final calculated hue: ${hue.toStringAsFixed(2)}');
    return hue;
  }

  // Synchronous helper method to get category marker icon
  google_maps.BitmapDescriptor _getCategoryMarkerIconSync(String categoryName) {
    try {
      print('_getCategoryMarkerIconSync called for category: "$categoryName"');
      print('Available categories in _categoryData: ${_categoryData.keys.toList()}');
      
      // Find the correct category name (case-insensitive)
      final String? actualCategoryName = _findCategoryName(categoryName);
      if (actualCategoryName == null) {
        print('No category data found for: $categoryName, using default marker');
        return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen);
      }
      
      // Get category data using the correct name
      final categoryInfo = _categoryData[actualCategoryName]!;

      final String color = categoryInfo['color'] ?? '#2079C2';
      print('Using dynamic color for category $categoryName (matched to $actualCategoryName): $color');
      
      // Convert hex color to hue for default marker
      final result = _getMarkerHueFromColor(color);
      print('Converted color $color to marker hue: $result');
      return result;
    } catch (e) {
      print('Error getting category marker icon for: $categoryName, using default. Error: $e');
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen);
    }
  }



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


















}
