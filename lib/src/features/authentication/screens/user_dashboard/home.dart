import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../../../../components/banner_carousel.dart';
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
import '../../../../services/performance_optimized_api_service.dart';
import '../../../../services/data_loading_manager.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import '../category/categories.dart';
import '../../../../services/google_maps_service.dart';
import '../../../../services/user_provider.dart';
import '../../../../services/route_tracking_service.dart';
import 'notification.dart';
import 'package:provider/provider.dart';
import '../../../../utils/category_integration_test.dart';

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
  
  // Categories data
  List<dynamic> _categories = [];

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
  
  // Add categories from API
  Map<String, List<String>> _allCategories = {};
  List<String> _displayCategories = [];

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
  
  // Add variables to store active branches for CollapsedSheet
  List<Map<String, dynamic>> _activeCompanyBranches = [];
  List<Map<String, dynamic>> _activeWholesalerBranches = [];
  
  // Add variable to force map updates
  int _mapUpdateCounter = 0;
  
  // Add variable to track banner carousel state
  bool _isBannerCollapsed = true;



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

  // Add method to fetch categories from API
  Future<void> _fetchCategories() async {
    try {
      print('Fetching categories from API...');
      final categories = await ApiService.getAllCategories();
      print('Raw categories from API: $categories');
      
      setState(() {
        _allCategories = categories;
        // Select first 4 categories for display
        _displayCategories = categories.keys.take(4).toList();
      });
      
      print('Successfully fetched ${categories.length} categories');
      print('Display categories: $_displayCategories');
      
      // Print each category with its subcategories
      categories.forEach((categoryName, subcategories) {
        print('Category: "$categoryName" -> Subcategories: $subcategories');
      });
    } catch (e) {
      print('Error fetching categories: $e');
      // Set default categories if API fails
      setState(() {
        _allCategories = {
          'Stores': ['Retail', 'Shopping', 'Market'],
          'Lodging': ['Hotel', 'Hostel', 'Resort'],
          'Food & Beverage': ['Restaurant', 'Cafe', 'Bar'],
          'Sports': ['Gym', 'Stadium', 'Sports Center'],
          'Vehicles': ['Car Dealer', 'Auto Repair', 'Gas Station'],
        };
        _displayCategories = ['Stores', 'Lodging', 'Food & Beverage', 'Sports'];
      });
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
        print('DEBUG: First branch socialMedia: ${branches[0]['socialMedia']}');
        print('DEBUG: First branch company socialMedia: ${branches[0]['company']?['socialMedia']}');
      }

      // Filter out branches whose status is not 'active'
      final filteredBranches = branches.where((branch) {
        // Check branch status - only show active branches
        final branchStatus = branch['status'];
        print('Branch: ${branch['name']}, Status: $branchStatus');
        print('DEBUG: Branch socialMedia in filter: ${branch['socialMedia']}');
        print('DEBUG: Branch company socialMedia in filter: ${branch['company']?['socialMedia']}');
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

      // Update active branches data
      _updateActiveBranches();

      // Create markers for filtered branches
      final branchMarkers = await Future.wait(filteredBranches.map((branch) async {
        final location = branch['location'];
        final company = branch['company'];
        final logoUrl = company?['logoUrl'];
        final category = branch['category']?.toString() ?? company?['category']?.toString() ?? '';

        print('Processing branch: ${branch['name']}, Location: $location, Company: $company');
        print('DEBUG: Branch socialMedia: ${branch['socialMedia']}');
        print('DEBUG: Company socialMedia: ${company['socialMedia']}');

        // Validate location data
        if (location == null ||
            location['lat'] == null ||
            location['lng'] == null) {
          print('Branch ${branch['name']} has invalid location data');
          return null;
        }
        
        // Check if coordinates are valid (not 0,0)
        final lat = location['lat'].toDouble();
        final lng = location['lng'].toDouble();
        
        if (lat == 0.0 && lng == 0.0) {
          print('Branch ${branch['name']} has invalid coordinates (0,0), skipping marker creation but keeping for social media');
          // Don't create a marker, but we'll still process this branch for social media
          return null;
        }
        
        print('Creating marker for branch: ${branch['name']} at lat: $lat, lng: $lng');

        print('Branch category: "$category"');
        // Create custom marker based on category with dynamic color and logo
        final customIcon = await _createCategoryMarkerIcon(category);

        return google_maps.Marker(
          markerId: google_maps.MarkerId('branch_${branch['id']}'),
          position: google_maps.LatLng(lat, lng),
          onTap: () {
            print('Branch marker tapped: ${branch['name']}');
            setState(() {
              _selectedPlace = {
                'name': branch['name'] ?? 'Unnamed Branch',
                '_id': branch['id'],
                'latitude': lat,
                'longitude': lng,
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
                // Include social media information - prefer branch, fallback to company
                'socialMedia': _getValidSocialMedia(branch['socialMedia'], company['socialMedia']),
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

      // Process branches with invalid coordinates for social media display
      final branchesWithInvalidCoords = filteredBranches.where((branch) {
        final location = branch['location'];
        if (location == null || location['lat'] == null || location['lng'] == null) return false;
        final lat = location['lat'].toDouble();
        final lng = location['lng'].toDouble();
        return lat == 0.0 && lng == 0.0;
      }).toList();

      print('Found ${branchesWithInvalidCoords.length} branches with invalid coordinates but valid social media');

      // Create special markers for branches with invalid coordinates but valid social media
      // These will be placed at a default location (Beirut center) but marked as "social media only"
      final socialMediaOnlyMarkers = await Future.wait(branchesWithInvalidCoords.map((branch) async {
        final company = branch['company'];
        final logoUrl = company?['logoUrl'];
        final category = branch['category']?.toString() ?? company?['category']?.toString() ?? '';
        final location = branch['location'];
        
        // Debug: Print the raw branch and company data
        print('DEBUG: Raw branch data for ${branch['name']}:');
        print('  Branch socialMedia: ${branch['socialMedia']}');
        print('  Company socialMedia: ${company['socialMedia']}');
        print('  Company data: $company');
        
        // Check if this branch has valid social media
        final hasValidSocial = _getValidSocialMedia(branch['socialMedia'], company['socialMedia']).isNotEmpty;
        if (!hasValidSocial) {
          print('Branch ${branch['name']} has no valid social media, skipping');
          return null;
        }
        
        print('Creating social media only marker for branch: ${branch['name']}');
        
        // Create custom marker based on category
        final customIcon = await _createCategoryMarkerIcon(category);
        
        return google_maps.Marker(
          markerId: google_maps.MarkerId('social_media_${branch['id']}'),
          position: google_maps.LatLng(33.8938, 35.5018), // Beirut center as default
          onTap: () {
            print('Social media only marker tapped: ${branch['name']}');
            setState(() {
              _selectedPlace = {
                'name': branch['name'] ?? 'Unnamed Branch',
                '_id': branch['id'],
                'latitude': 33.8938, // Default Beirut coordinates
                'longitude': 35.5018,
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
                'socialMediaOnly': true, // Mark as social media only
                // Include social media information - prefer branch, fallback to company
                'socialMedia': _getValidSocialMedia(branch['socialMedia'], company['socialMedia']),
              };
            });
            print('_selectedPlace set to social media only branch: ${_selectedPlace?['name']}');
            print('_selectedPlace socialMedia: ${_selectedPlace?['socialMedia']}');
          },
          icon: customIcon,
          visible: false, // Hide these markers from the map
        );
      })).then((markers) => markers.where((marker) => marker != null).cast<google_maps.Marker>().toList());

      print('Created ${socialMediaOnlyMarkers.length} social media only markers');

      // Remove test marker - it was causing duplicate markers at same location
      // The branch marker already handles the onTap functionality

      setState(() {
        // Add branch markers to existing company markers
        _wayPointMarkers.addAll(branchMarkers);
        // Add social media only markers (these are hidden but accessible via search)
        _wayPointMarkers.addAll(socialMediaOnlyMarkers);
        print('Total markers on map: ${_wayPointMarkers.length} (${branchMarkers.length} branch markers, ${socialMediaOnlyMarkers.length} social media only)');
        print('Home: Marker types: ${_wayPointMarkers.map((m) => m.runtimeType).toList()}');
        print('Home: Marker IDs: ${_wayPointMarkers.map((m) => m is google_maps.Marker ? m.markerId.value : 'unknown').toList()}');
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

      // Filter existing markers to show only the selected category
      setState(() {
        _wayPointMarkers = _wayPointMarkers.where((marker) {
          if (marker is google_maps.Marker) {
            final markerId = marker.markerId.value;
            
            // Always keep company and wholesaler markers visible
            if (markerId.startsWith('company_') || markerId.startsWith('wholesaler_') || markerId.startsWith('wholesaler_branch_')) {
              return true;
            }
            
            // For branch markers, keep them visible (simplified filtering)
            if (markerId.startsWith('branch_')) {
              return true;
            }
            
            return false;
          }
          return false;
        }).toList();
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

  // Method to filter branches by category from API
  void _filterCompaniesByApiCategory(String categoryName) {
    try {
      print('Filtering branches by API category: $categoryName');
      
      // Get subcategories for this category
      final subcategories = _allCategories[categoryName] ?? [];
      print('Subcategories for $categoryName: $subcategories');
      
      // Filter branches based on category and subcategories
      final filteredBranches = _allBranches.where((branch) {
        final branchCategory = branch['category']?.toString().toLowerCase() ?? '';
        final companyCategory = branch['company']?['category']?.toString().toLowerCase() ?? '';
        final companyIndustryType = branch['company']?['industryType']?.toString().toLowerCase() ?? '';
        
        // Check if branch or company category matches the selected category
        final branchCategoryMatch = branchCategory.contains(categoryName.toLowerCase());
        final companyCategoryMatch = companyCategory.contains(categoryName.toLowerCase()) ||
                                    companyIndustryType.contains(categoryName.toLowerCase());
        
        // Check subcategories
        final subcategoryMatch = subcategories.any((subcategory) =>
          branchCategory.contains(subcategory.toLowerCase()) ||
          companyCategory.contains(subcategory.toLowerCase()) ||
          companyIndustryType.contains(subcategory.toLowerCase())
        );
        
        return branchCategoryMatch || companyCategoryMatch || subcategoryMatch;
      }).toList();
      
      print('Found ${filteredBranches.length} branches in category: $categoryName');
      
      if (filteredBranches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No branches found in category: $categoryName')),
        );
        return;
      }
      
      // Filter markers to show only branches in the selected category
      setState(() {
        _wayPointMarkers = _wayPointMarkers.where((marker) {
          if (marker is google_maps.Marker) {
            final markerId = marker.markerId.value;
            
            // Keep branch markers that match the category
            if (markerId.startsWith('branch_')) {
              // Extract branch ID from marker ID
              final branchId = markerId.replaceFirst('branch_', '');
              
              // Check if this branch is in the filtered list
              return filteredBranches.any((branch) => branch['id'] == branchId);
            }
            
            // Keep company markers (show company headquarters too)
            if (markerId.startsWith('company_')) {
              return true;
            }
            
            // Keep wholesaler markers
            if (markerId.startsWith('wholesaler_') || markerId.startsWith('wholesaler_branch_')) {
              return true;
            }
            
            // Hide other markers
            return false;
          }
          return false;
        }).toList();
      });
      
      // Move camera to the first filtered marker if exists
      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].position, 15.0);
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Showing ${filteredBranches.length} branches in $categoryName'),
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      print('Error filtering branches by category: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to filter branches: $e')),
      );
    }
  }

  // Method to clear category filter and show all markers
  void _clearCategoryFilter() {
    setState(() {
      _selectedCategory = '';
    });
    
    // Re-fetch all data to restore all markers
    _fetchAllBranches();
    _fetchCompanies();
    _fetchAllWholesalers().catchError((e) {
      print('Error fetching wholesalers: $e');
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing all locations'),
        duration: Duration(seconds: 2),
      ),
    );
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
        // Don't clear existing markers - add to them instead
        // _wayPointMarkers = [];

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
                          // Include social media information from company data
                          'socialMedia': _getValidSocialMedia(null, companyInfo?['socialMedia']),
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
                        // Include social media information from company data
                        'socialMedia': _getValidSocialMedia(null, companyInfo?['socialMedia']),
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
                          // Prefer branch social media; fallback to company
                          'socialMedia': _getValidSocialMedia(branch['socialMedia'], companyInfo?['socialMedia']),
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
    print('_toggleSidebar called - Current state: $_isSidebarOpen');
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
    print('_toggleSidebar completed - New state: $_isSidebarOpen');
  }

  void _closeSidebar() {
    print('_closeSidebar called - Current state: $_isSidebarOpen');
    if (_isSidebarOpen) {
      setState(() {
        _isSidebarOpen = false;
      });
      print('_closeSidebar completed - Sidebar closed');
    }
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
    // Don't replace all markers - add company markers to existing ones
    final companyMarkers = companies.map((company) {
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
                  // Include social media information from company data
                  'socialMedia': _getValidSocialMedia(null, companyInfo?['socialMedia']),
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
                // Include social media information from company data
                'socialMedia': _getValidSocialMedia(null, companyInfo?['socialMedia']),
              };
            });
          }
        },
        icon: _getCategoryMarkerIconSync(companyInfo?['category']?.toString() ?? ''),
      );
    }).where((marker) => marker != null).cast<google_maps.Marker>().toList();
    
    // Add company markers to existing markers instead of replacing them
    _wayPointMarkers.addAll(companyMarkers);
  });

    print('Number of markers created: ${_wayPointMarkers.length}');
  }

  void _applyFilters(Map<String, dynamic> filters) async {
    print('Applying filters: $filters'); // Debug log
    
    setState(() {
      // Don't clear all markers - preserve company and wholesaler markers
      // Only clear route-related data
      _primaryRouteCoordinates.clear();
      _alternativeRouteCoordinates.clear();
    });

    // If Wholesaler is selected, filter wholesalers
    if (filters['type'] == 'Wholesaler') {
      // Filter existing wholesaler markers instead of recreating them
      setState(() {
        _wayPointMarkers = _wayPointMarkers.where((marker) {
          if (marker is google_maps.Marker) {
            final markerId = marker.markerId.value;
            // Keep wholesaler markers
            if (markerId.startsWith('wholesaler_') || markerId.startsWith('wholesaler_branch_')) {
              return true;
            }
            // Hide non-wholesaler markers
            return false;
          }
          return false;
        }).toList();
      });

      print('Filtered to show only wholesaler markers: ${_wayPointMarkers.length}');
      return;
    }

    // Filter branches based on category and subcategory
    String? selectedCategory = filters['category'];
    String? selectedSubCategory = filters['subcategory'];
    
    if (selectedCategory != null && selectedCategory != 'All' && selectedCategory != '') {
      // Filter branches by category
      final filteredBranches = _allBranches.where((branch) {
        // First check if the branch is active
        final branchStatus = branch['status'];
        if (branchStatus != 'active') {
          return false;
        }
        
        final branchCategory = branch['category']?.toString().toLowerCase() ?? '';
        final companyCategory = branch['company']?['category']?.toString().toLowerCase() ?? '';
        final companyIndustryType = branch['company']?['industryType']?.toString().toLowerCase() ?? '';
        
        // Check if branch or company category matches the selected category
        final branchCategoryMatch = branchCategory.contains(selectedCategory.toLowerCase());
        final companyCategoryMatch = companyCategory.contains(selectedCategory.toLowerCase()) ||
                                    companyIndustryType.contains(selectedCategory.toLowerCase());
        
        // Check subcategory if specified
        bool subcategoryMatch = true;
        if (selectedSubCategory != null && selectedSubCategory != 'All' && selectedSubCategory != '') {
          subcategoryMatch = branchCategory.contains(selectedSubCategory.toLowerCase()) ||
                            companyCategory.contains(selectedSubCategory.toLowerCase()) ||
                            companyIndustryType.contains(selectedSubCategory.toLowerCase());
        }
        
        return (branchCategoryMatch || companyCategoryMatch) && subcategoryMatch;
      }).toList();
      
      print('Found ${filteredBranches.length} branches matching category: $selectedCategory');
      
      // Filter markers to show only matching branches
      setState(() {
        _wayPointMarkers = _wayPointMarkers.where((marker) {
          if (marker is google_maps.Marker) {
            final markerId = marker.markerId.value;
            
            // Keep branch markers that match the category
            if (markerId.startsWith('branch_')) {
              // Extract branch ID from marker ID
              final branchId = markerId.replaceFirst('branch_', '');
              
              // Check if this branch is in the filtered list
              return filteredBranches.any((branch) => branch['id'] == branchId);
            }
            
            // Keep company markers (show company headquarters too)
            if (markerId.startsWith('company_')) {
              return true;
            }
            
            // Keep wholesaler markers
            if (markerId.startsWith('wholesaler_') || markerId.startsWith('wholesaler_branch_')) {
              return true;
            }
            
            // Hide other markers
            return false;
          }
          return false;
        }).toList();
      });
    } else {
      // No category filter - show all markers but apply distance filter
      setState(() {
        _wayPointMarkers = _wayPointMarkers.where((marker) {
          if (marker is google_maps.Marker) {
            final markerId = marker.markerId.value;
            
            // Keep all branch, company, and wholesaler markers
            if (markerId.startsWith('branch_') || 
                markerId.startsWith('company_') || 
                markerId.startsWith('wholesaler_') || 
                markerId.startsWith('wholesaler_branch_')) {
              
              // Apply distance filter if specified
              if (filters['distance'] != null && filters['distance'] != '') {
                try {
                  double maxDistance = double.parse(filters['distance'].toString().replaceAll(' km', ''));
                  double distance = _calculateDistance(
                    _userLocation.latitude,
                    _userLocation.longitude,
                    marker.position.latitude,
                    marker.position.longitude,
                  );
                  return distance <= maxDistance;
                } catch (e) {
                  print('Error parsing distance filter: $e');
                  return true;
                }
              }
              
              return true;
            }
            
            return false;
          }
          return false;
        }).toList();
      });
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
    
    // Track this route using the route tracking service
    RouteTrackingService.trackDashboardRoute(
      context,
      'user',
      pageData: widget.userData,
    );
    
    // Prioritize getting user location immediately upon login
    _getUserLocationOnLogin();
    
    _fetchUserData(); // Add this line to fetch user data
    
    // OPTIMIZED: Load all data in parallel for better performance
    _loadAllDataInParallel();
    
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
                  'socialMedia': {
                    'instagram': branch.socialMedia.instagram,
                    'facebook': branch.socialMedia.facebook,
                  },
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

              // Calculate distance if current location is available and coordinates are valid
              double? distance;
              double? latitude = branch['location']?['lat']?.toDouble();
              double? longitude = branch['location']?['lng']?.toDouble();
              
              if (branch['location'] != null && latitude != null && longitude != null) {
                if (latitude != 0.0 && longitude != 0.0) {
                  distance = _calculateDistance(
                    _userLocation.latitude,
                    _userLocation.longitude,
                    latitude,
                    longitude,
                  );
                } else {
                  // For branches with invalid coordinates, set a high distance to sort them last
                  distance = 999999.0; // Use a large finite number instead of infinity
                }
              } else {
                distance = 999999.0; // Use a large finite number instead of infinity
              }

              // Use default coordinates for branches with invalid coordinates
              if (latitude == null || longitude == null || (latitude == 0.0 && longitude == 0.0)) {
                latitude = 33.8938; // Default Beirut coordinates
                longitude = 35.5018;
              }

              results.add({
                'name': branch['name'] ?? 'Unnamed Branch',
                'id': branch['id'],
                'latitude': latitude,
                'longitude': longitude,
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
                'category': branch['category'] ?? 'Unknown Category',
                'socialMedia': _getValidSocialMedia(branch['socialMedia'], branch['company']?['socialMedia']),
                'company': branch['company'] ?? {},
                'status': branch['status'] ?? 'active',
                'socialMediaOnly': (latitude == 33.8938 && longitude == 35.5018), // Mark as social media only if using default coordinates
              });
            }
          }
        }

        // Sort results by distance if current location is available
        results.sort((a, b) {
          final distanceA = a['distance'] as double? ?? 999999.0; // Use large finite number instead of infinity
          final distanceB = b['distance'] as double? ?? 999999.0; // Use large finite number instead of infinity
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
    print('🔍 _showNearbyCompanies called - markers before: ${_wayPointMarkers.length}');
    const double maxDistance = 5.0; // km
    final List<Map<String, dynamic>> nearbyCompanies = _allCompanies.where((company) {
      final companyLocation = company['location'];
      if (companyLocation == null || companyLocation['lat'] == null || companyLocation['lng'] == null) return false;
      final double lat = companyLocation['lat'].toDouble();
      final double lng = companyLocation['lng'].toDouble();
      final double distance = _calculateDistance(_userLocation.latitude, _userLocation.longitude, lat, lng);
      return distance <= maxDistance;
    }).toList();
    print('🔍 Nearby companies found: ${nearbyCompanies.length}');
    _createMarkersFromCompanies(nearbyCompanies);
    print('🔍 Markers after _createMarkersFromCompanies: ${_wayPointMarkers.length}');
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
    print('=== GETTING ROUTE DIRECTIONS ===');
    print('Current location: $_currentLocation');
    print('Destination location: $_destinationLocation');
    
    if (_destinationLocation == null) {
      print('ERROR: Missing destination location');
      return;
    }
    
    // Use current location or default to Beirut if not available
    final currentLoc = _currentLocation ?? _defaultLocation;
    print('Current location status:');
    print('- _currentLocation: $_currentLocation');
    print('- _defaultLocation: $_defaultLocation');
    print('- Using location: ${currentLoc.latitude}, ${currentLoc.longitude}');
    print('- Is using default location: ${_currentLocation == null}');

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${currentLoc.longitude},${currentLoc.latitude};'
          '${_destinationLocation!.longitude},${_destinationLocation!.latitude}'
          '?overview=full&geometries=polyline&steps=true&alternatives=true';
      
      print('Making request to: $url');
      
      final response = await http.get(Uri.parse(url));

      print('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data keys: ${data.keys.toList()}');
        print('Routes in response: ${data['routes']?.length ?? 'null'}');
        
        if (data['routes'] == null || data['routes'].isEmpty) {
          print('ERROR: No routes found in response');
          throw Exception('No route found');
        }

        final List<dynamic> routes = data['routes'];
        print('Number of routes received: ${routes.length}');

        if (routes.isNotEmpty) {
          final primaryRoute = routes[0];
          final String polyline = primaryRoute['geometry'];

          print('=== ROUTE CALCULATION DEBUG ===');
          print('Primary route distance: ${primaryRoute['distance']} meters');
          print('Primary route duration: ${primaryRoute['duration']} seconds');
          print('Polyline string length: ${polyline.length}');

          final primaryPoints = _polylinePoints.decodePolyline(polyline);
          print('Decoded polyline points: ${primaryPoints.length}');
          
          _primaryRouteCoordinates = primaryPoints
              .map((point) => latlong.LatLng(point.latitude, point.longitude))
              .toList();

          print('Primary route coordinates set: ${_primaryRouteCoordinates.length}');
          if (_primaryRouteCoordinates.isNotEmpty) {
            print('First coordinate: ${_primaryRouteCoordinates.first}');
            print('Last coordinate: ${_primaryRouteCoordinates.last}');
          }

          _primaryDistance = primaryRoute['distance'] / 1000;
          _primaryDuration = primaryRoute['duration'] / 60;

          print('Primary distance: ${_primaryDistance} km');
          print('Primary duration: ${_primaryDuration} minutes');
          print('===============================');

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
        
        // Force map to update with new route
        print('Forcing map update with new route data...');
        print('Route data summary:');
        print('- Primary route: ${_primaryRouteCoordinates.length} coordinates');
        print('- Alternative route: ${_alternativeRouteCoordinates.length} coordinates');
        print('- Destination: $_destinationLocation');
        print('- Is navigating: $_isNavigating');
        
        // Try to fit bounds to the route, but if no route coordinates, move to destination
        if (_primaryRouteCoordinates.isNotEmpty || _alternativeRouteCoordinates.isNotEmpty) {
          _fitBounds();
        } else {
          // No route coordinates available, just move to destination
          print('No route coordinates available, moving map to destination');
          if (_destinationLocation != null) {
            _mapController.move(_destinationLocation!, 15.0);
          }
        }
        
        setState(() {
          _mapUpdateCounter++;
          // This will trigger a rebuild of the MapComponent
        });
        
        // Add a small delay to ensure the route data is processed
        await Future.delayed(Duration(milliseconds: 100));
        setState(() {
          _mapUpdateCounter++;
          // Trigger another rebuild to ensure polylines are updated
        });
        
        print('Map update counter incremented to: $_mapUpdateCounter');

      } else {
        print('ERROR: Failed to load route. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load route: ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR getting route: $e');
      print('Error type: ${e.runtimeType}');
      
      // Even if route calculation fails, move map to destination
      if (_destinationLocation != null) {
        print('Route calculation failed, but moving map to destination: $_destinationLocation');
        _mapController.move(_destinationLocation!, 15.0);
      }
      
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Could not calculate route: $e')),
      // );
      setState(() {
        _isNavigating = false;
      });
    }
    
    print('=== END GETTING ROUTE DIRECTIONS ===');
  }

  void _processRouteSteps(List<dynamic> steps) {
    _steps = [];
    // Only clear waypoint markers, preserve business/wholesaler markers
    _wayPointMarkers.removeWhere((marker) => 
      marker is google_maps.Marker && 
      marker.markerId.value.startsWith('waypoint_'));

    for (var step in steps) {
      _steps.add({
        'instruction': step['maneuver']['type'],
        'distance': step['distance'],
        'duration': step['duration'],
      });

      // Remove the waypoint marker creation - we don't want green markers at every turn
      // if (step['distance'] > 100) {
      //   final location = step['maneuver']['location'];
      //   if (location != null && location.length >= 2) {
      //     _wayPointMarkers.add(
      //       google_maps.Marker(
      //         markerId: google_maps.MarkerId('waypoint_${_wayPointMarkers.length}'),
      //         position: google_maps.LatLng(location[1], location[0]),
      //         icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
      //       ),
      //     );
      //   }
      // }
    }
    
    print('Route steps processed: ${_steps.length} steps, no waypoint markers created');
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
      _primaryRouteCoordinates.clear();
      _alternativeRouteCoordinates.clear();
      _routeInstructions = '';
      _isNavigating = false;
      _primaryDistance = 0;
      _primaryDuration = 0;
      _alternativeDistance = 0;
      _alternativeDuration = 0;
      _steps.clear();
      _usingPrimaryRoute = true;
      // Only remove waypoint markers, preserve business/wholesaler markers
      _wayPointMarkers.removeWhere((marker) => 
        marker is google_maps.Marker && 
        marker.markerId.value.startsWith('waypoint_'));
    });
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
  }

  // Helper method to get active company branches
  List<Map<String, dynamic>> _getActiveCompanyBranches() {
    return _activeCompanyBranches;
  }

  // Helper method to get active wholesaler branches
  List<Map<String, dynamic>> _getActiveWholesalerBranches() {
    print('Home - _getActiveWholesalerBranches called, returning ${_activeWholesalerBranches.length} branches');
    return _activeWholesalerBranches;
  }

  // Method to update active branches data
  void _updateActiveBranches() {
    List<Map<String, dynamic>> activeBranches = [];
    
    // Extract active branches from _allBranches
    for (var branch in _allBranches) {
      if (branch['status'] == 'active') {
        final location = branch['location'];
        final company = branch['company'];
        
        // Only include branches with valid coordinates
        if (location != null && 
            location['lat'] != null && 
            location['lng'] != null &&
            location['lat'] != 0.0 && 
            location['lng'] != 0.0) {
          
          activeBranches.add({
            'id': branch['id'],
            '_id': branch['id'],
            'name': branch['name'] ?? 'Unnamed Branch',
            'description': branch['description'] ?? '',
            'phone': branch['phone'] ?? '',
            'category': branch['category'] ?? company?['category'] ?? 'Unknown Category',
            'latitude': location['lat'].toDouble(),
            'longitude': location['lng'].toDouble(),
            'address': '${location['street'] ?? ''}, ${location['city'] ?? ''}',
            'images': branch['images'] ?? [],
            'logoUrl': company?['logoUrl'],
            'companyName': company?['businessName'] ?? 'Unknown Company',
            'companyId': company?['id'],
            'company': company,
            'status': 'active',
            'socialMedia': _getValidSocialMedia(branch['socialMedia'], company?['socialMedia']),
            'type': 'Branch',
          });
        }
      }
    }
    
    // Also extract branches from _allCompanies
    for (var company in _allCompanies) {
      if (company['branches'] != null && company['branches'] is List) {
        for (var branch in company['branches']) {
          if (branch['status'] == 'active') {
            final branchLocation = branch['location'];
            final companyInfo = company['companyInfo'];
            
            // Only include branches with valid coordinates
            if (branchLocation != null && 
                branchLocation['lat'] != null && 
                branchLocation['lng'] != null &&
                branchLocation['lat'] != 0.0 && 
                branchLocation['lng'] != 0.0) {
              
              activeBranches.add({
                'id': branch['id'] ?? branch['_id'],
                '_id': branch['id'] ?? branch['_id'],
                'name': branch['name'] ?? 'Unnamed Branch',
                'description': branch['description'] ?? '',
                'phone': branch['phone'] ?? '',
                'category': branch['category'] ?? companyInfo?['category'] ?? 'Unknown Category',
                'latitude': branchLocation['lat'].toDouble(),
                'longitude': branchLocation['lng'].toDouble(),
                'address': '${branchLocation['street'] ?? ''}, ${branchLocation['city'] ?? ''}',
                'images': branch['images'] ?? [],
                'logoUrl': companyInfo?['logo'],
                'companyName': companyInfo?['name'] ?? 'Unknown Company',
                'companyId': company['_id'],
                'company': companyInfo,
                'status': 'active',
                'socialMedia': _getValidSocialMedia(branch['socialMedia'], companyInfo?['socialMedia']),
                'type': 'Branch',
              });
            }
          }
        }
      }
    }
    
    setState(() {
      _activeCompanyBranches = activeBranches;
    });
  }

  // Method to update active wholesaler branches data
  Future<void> _updateActiveWholesalerBranches() async {
    print('Home - _updateActiveWholesalerBranches called');
    List<Map<String, dynamic>> activeWholesalerBranches = [];
    
    try {
      // Get actual wholesaler data from the service
      final wholesalers = await _wholesalerService.getAllWholesalers();
      print('Home - Retrieved ${wholesalers.length} wholesalers for active branches update');
      
      for (var wholesaler in wholesalers) {
        // Get only active branches
        final activeBranches = wholesaler.branches.where((b) => b.status == 'active');
        print('Home - Processing wholesaler ${wholesaler.businessName} with ${activeBranches.length} active branches');
        
        for (var branch in activeBranches) {
          print('Home - Processing branch: ${branch.name}, coordinates: ${branch.location.lat}, ${branch.location.lng}');
          // Only include branches with valid coordinates
          if (branch.location.lat != 0.0 && branch.location.lng != 0.0) {
            print('Home - Adding branch ${branch.name} to active wholesaler branches');
            activeWholesalerBranches.add({
              'id': branch.id,
              '_id': branch.id,
              'name': branch.name,
              'description': branch.description,
              'phone': branch.phone,
              'category': branch.category,
              'latitude': branch.location.lat,
              'longitude': branch.location.lng,
              'address': '${branch.location.street}, ${branch.location.city}',
              'images': branch.images,
              'logoUrl': wholesaler.logoUrl,
              'companyName': wholesaler.businessName,
              'companyId': wholesaler.id,
              'company': {
                'businessName': wholesaler.businessName,
                'logoUrl': wholesaler.logoUrl,
                'id': wholesaler.id,
              },
              'status': 'active',
              'socialMedia': {
                'instagram': branch.socialMedia.instagram,
                'facebook': branch.socialMedia.facebook,
              },
              'type': 'Wholesaler Branch',
            });
          } else {
            print('Home - Skipping branch ${branch.name} due to invalid coordinates (${branch.location.lat}, ${branch.location.lng})');
          }
        }
      }
      
      print('Updated active wholesaler branches: ${activeWholesalerBranches.length}');
      if (activeWholesalerBranches.isNotEmpty) {
        print('First wholesaler branch: ${activeWholesalerBranches.first}');
      }
    } catch (e) {
      print('Error updating active wholesaler branches: $e');
    }
    
    if (mounted) {
      print('Home - Calling setState to update _activeWholesalerBranches with ${activeWholesalerBranches.length} branches');
      setState(() {
        _activeWholesalerBranches = activeWholesalerBranches;
      });
      print('Home - setState completed, _activeWholesalerBranches now has ${_activeWholesalerBranches.length} branches');
    } else {
      print('Home - Widget not mounted, skipping setState');
    }
  }

  void _searchPlace(String query) {
    if (query.isEmpty) return;

    setState(() {
      // Don't clear all markers - preserve company and wholesaler markers
      // Only clear route-related data
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

    // Filter existing markers based on search query instead of recreating them
    setState(() {
      _wayPointMarkers = _wayPointMarkers.where((marker) {
        if (marker is google_maps.Marker) {
          final markerId = marker.markerId.value;
          
          // Always keep company and wholesaler markers visible
          if (markerId.startsWith('company_') || markerId.startsWith('wholesaler_') || markerId.startsWith('wholesaler_branch_')) {
            return true;
          }
          
          // For branch markers, check if they match the search query
          if (markerId.startsWith('branch_')) {
            // This is a simplified search - in a real implementation, you'd need to store
            // searchable data with the marker or look it up from the original data
            // For now, keep all branch markers visible during search
            return true;
          }
          
          return false;
        }
        return false;
      }).toList();
    });

    // Move camera to the first match if any markers are visible
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
    print('Building UserDashboard, _selectedPlace type: ${_selectedPlace?['type'] ?? 'NULL'}');
    print('Building UserDashboard, _selectedPlace status: ${_selectedPlace?['status'] ?? 'NULL'}');
    
    // Safety check: Ensure Google Maps services are ready before building
    // This prevents crashes when the dashboard tries to create map widgets
    if (!GoogleMapsService.isInitialized) {
      print('Google Maps services not ready, showing loading screen');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing map services...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Please wait...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          print('GestureDetector tapped - Sidebar open: $_isSidebarOpen');
          if (!_isMapExpanded) {
            setState(() {
              _isMapExpanded = true;
            });
          }
          if (_isSidebarOpen) {
            print('Closing sidebar via tap');
            _closeSidebar();
          }
        },
        behavior: HitTestBehavior.opaque, // Ensure taps are detected even on transparent areas
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationsPage(),
                      ),
                    );
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
                // Banner Carousel for Advertisements
                BannerCarousel(
                  imageUrls: [
                    'assets/images/subscription.png',
                    'assets/images/6months_subscription.png',
                    'assets/images/monthly_subscription.png',
                    'assets/images/yearly_subscription.png',
                  ],
                  height: 150,
                  autoPlayInterval: const Duration(seconds: 5),
                  autoPlay: true,
                  
                ),
                
                Expanded(
                  child: Stack(
                    children: [
                      MapComponent(
                        key: ValueKey('map_${_primaryRouteCoordinates.length}_${_alternativeRouteCoordinates.length}_${_destinationLocation?.hashCode ?? 0}_${_isNavigating ? 'nav' : 'no_nav'}_$_mapUpdateCounter'),
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
                            ? Container(
                                height: 100, // Fixed height for category buttons row
                                child: _buildCategoryButtons(),
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
                child: Builder(
                  builder: (context) {
                    print('Rendering PlaceDetailsOverlay for: ${_selectedPlace!['name']}');
                    return PlaceDetailsOverlay(
                  place: _selectedPlace!,
                  onClose: () {
                    print('PlaceDetailsOverlay closing for: ${_selectedPlace?['name']}');
                    setState(() {
                      _selectedPlace = null;
                    });
                  },
                  onNavigate: (latlong.LatLng destination) {
                    print('Home: onNavigate called with destination: ${destination.latitude}, ${destination.longitude}');
                    _startNavigation(destination);
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
                    );
                  },
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
                key: ValueKey('collapsed_sheet_${_activeCompanyBranches.length}_${_activeWholesalerBranches.length}'),
                controller: null,
                onLocationCardTap: () {
                  // Handle location card tap
                },
                onPlaceTap: (Map<String, dynamic> place) {
                  // Open PlaceDetailsOverlay when a place is tapped
                  setState(() {
                    _selectedPlace = place;
                  });
                },
                onCloseSheet: () {
                  // Close the CollapsedSheet by expanding the map
                  setState(() {
                    _isMapExpanded = true;
                  });
                },
                activeBranches: _getActiveCompanyBranches(),
                activeWholesalerBranches: _getActiveWholesalerBranches(),
              ),
            // Semi-transparent overlay when sidebar is open
            if (_isSidebarOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSidebar,
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
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
      print('Home - _fetchAllWholesalers called');
      final wholesalers = await _wholesalerService.getAllWholesalers();
      print('Home - Retrieved ${wholesalers.length} wholesalers from service');
      
      // Filter wholesalers and their active branches
      final filteredWholesalers = wholesalers.where((wholesaler) {
        // Check if wholesaler has any active branches
        final hasActiveBranches = wholesaler.branches.any((branch) => branch.status == 'active');
        print('Home - Wholesaler ${wholesaler.businessName} has ${wholesaler.branches.length} branches, active: ${wholesaler.branches.where((b) => b.status == 'active').length}');
        return hasActiveBranches;
      }).toList();
      
      print('Home - Filtered to ${filteredWholesalers.length} wholesalers with active branches');
      
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
            
            print('Creating icon for wholesaler marker...');
            // Use the custom wholesaler icon
            final customIcon = await _createWholesalerMarkerIcon();
            print('Using custom wholesaler icon');
            
            final markerId = 'wholesaler_branch_${wholesaler.id}_${branch.id}_${DateTime.now().millisecondsSinceEpoch}';
            print('Creating marker with ID: $markerId');
            print('Marker position: lat=$lat, lng=$lng');
            
            final marker = google_maps.Marker(
              markerId: google_maps.MarkerId(markerId),
              position: google_maps.LatLng(lat, lng),
              onTap: () {
                print('Wholesaler marker tapped: ${wholesaler.businessName}');
                print('Branch social media: ${branch.socialMedia.instagram}, ${branch.socialMedia.facebook}');
                setState(() {
                  _selectedPlace = {
                    'name': branch.name, // Use branch name instead of wholesaler name
                    '_id': branch.id, // Use branch ID instead of wholesaler ID
                    'latitude': lat,
                    'longitude': lng,
                    'address': address,
                    'phone': branch.phone, // Use branch phone instead of wholesaler phone
                    'description': branch.description, // Use branch description instead of wholesaler category
                    'image': wholesaler.logoUrl ?? 'assets/images/company_placeholder.png',
                    'logoUrl': wholesaler.logoUrl,
                    'companyName': wholesaler.businessName,
                    'companyId': wholesaler.id,
                    'images': branch.images, // Use branch images
                    'category': branch.category, // Use branch category
                    'company': {
                      'businessName': wholesaler.businessName,
                      'logoUrl': wholesaler.logoUrl,
                      'id': wholesaler.id,
                      'logo': wholesaler.logoUrl,
                      'socialMedia': {
                        'instagram': wholesaler.socialMedia.instagram,
                        'facebook': wholesaler.socialMedia.facebook,
                      },
                    },
                    'companyInfo': {
                      'name': wholesaler.businessName,
                      'logo': wholesaler.logoUrl,
                      'id': wholesaler.id,
                      'socialMedia': {
                        'instagram': wholesaler.socialMedia.instagram,
                        'facebook': wholesaler.socialMedia.facebook,
                      },
                    },
                    'type': 'Wholesaler Branch', // Use Wholesaler Branch type
                    'status': branch.status, // Use branch status
                    'socialMedia': {
                      'instagram': branch.socialMedia.instagram,
                      'facebook': branch.socialMedia.facebook,
                    },
                    'branches': wholesaler.branches.map((b) => {
                      'id': b.id,
                      '_id': b.id,
                      'name': b.name,
                      'description': b.description,
                      'phone': b.phone,
                      'latitude': b.location.lat,
                      'longitude': b.location.lng,
                      'location': '${b.location.street}, ${b.location.city}',
                      'images': b.images,
                      'category': b.category,
                      'status': b.status,
                      'socialMedia': {
                        'instagram': b.socialMedia.instagram,
                        'facebook': b.socialMedia.facebook,
                      },
                    }).toList(),
                    'contactInfo': {
                      'whatsapp': wholesaler.contactInfo.whatsApp,
                      'website': wholesaler.contactInfo.website,
                    },
                    'email': wholesaler.email,
                    'subCategory': wholesaler.subCategory,
                    'rating': 5.0,
                    'price': '0',
                  };
                });
                print('Wholesaler place data set: ${_selectedPlace?['name']}');
                print('Place social media: ${_selectedPlace?['socialMedia']}');
              },
              icon: customIcon,
              visible: true, // Ensure marker is always visible
            );
            
            print('Wholesaler marker created successfully with icon');
            return marker;
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
          print('Home: All marker types: ${_wayPointMarkers.map((m) => m.runtimeType).toList()}');
          print('Home: All marker IDs: ${_wayPointMarkers.map((m) => m is google_maps.Marker ? m.markerId.value : 'unknown').toList()}');
          
          // Force a rebuild of the map to show new markers
          if (mounted) {
            print('Forcing map rebuild to show new wholesaler markers');
            // Trigger a rebuild by calling setState again
            Future.delayed(Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() {
                  print('Map rebuild triggered for wholesaler markers');
                });
              }
            });
          }
        });

        // Update active wholesaler branches data
        await _updateActiveWholesalerBranches();

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

  // OPTIMIZED: Load all data in parallel for better performance
  Future<void> _loadAllDataInParallel() async {
    print('🚀 Starting parallel data loading...');
    
    try {
      // Initialize data loading manager
      final dataManager = DataLoadingManager();
      await dataManager.initialize();
      
      // Load all critical data in parallel
      final results = await dataManager.loadMultipleData({
        'categories': () => _fetchCategoriesOptimized(),
        'companies': () => _fetchCompaniesOptimized(),
        'branches': () => _fetchBranchesOptimized(),
        'wholesalers': () => _fetchWholesalersOptimized(),
        'categoryData': () => _fetchCategoryDataOptimized(),
      });
      
      print('✅ Parallel data loading completed');
      print('Results: ${results.keys.map((k) => '$k: ${results[k] != null ? 'loaded' : 'failed'}').join(', ')}');
      
      // Process results and update UI
      await _processParallelResults(results);
      
    } catch (e) {
      print('❌ Error in parallel data loading: $e');
      // Fallback to sequential loading
      await _fallbackSequentialLoading();
    }
  }
  
  // Optimized fetch methods that use the performance service
  Future<List<dynamic>> _fetchCategoriesOptimized() async {
    try {
      return await PerformanceOptimizedApiService.fetchCategories();
    } catch (e) {
      print('Error fetching categories (optimized): $e');
      return [];
    }
  }
  
  Future<List<dynamic>> _fetchCompaniesOptimized() async {
    try {
      return await PerformanceOptimizedApiService.fetchCompanies();
    } catch (e) {
      print('Error fetching companies (optimized): $e');
      return [];
    }
  }
  
  Future<List<dynamic>> _fetchBranchesOptimized() async {
    try {
      return await PerformanceOptimizedApiService.fetchBranches();
    } catch (e) {
      print('Error fetching branches (optimized): $e');
      return [];
    }
  }
  
  Future<List<dynamic>> _fetchWholesalersOptimized() async {
    try {
      return await PerformanceOptimizedApiService.fetchWholesalers();
    } catch (e) {
      print('Error fetching wholesalers (optimized): $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> _fetchCategoryDataOptimized() async {
    try {
      // This would be your category data fetching logic
      return {};
    } catch (e) {
      print('Error fetching category data (optimized): $e');
      return {};
    }
  }
  
  // Process results from parallel loading
  Future<void> _processParallelResults(Map<String, dynamic> results) async {
    try {
      // Process categories
      if (results['categories'] != null) {
        final categories = results['categories'] as List<dynamic>;
        setState(() {
          _categories = categories;
        });
        print('✅ Categories processed: ${categories.length} items');
      }
      
      // Process companies
      if (results['companies'] != null) {
        final companies = results['companies'] as List<dynamic>;
        await _processCompaniesData(companies);
        print('✅ Companies processed: ${companies.length} items');
      }
      
      // Process branches
      if (results['branches'] != null) {
        final branches = results['branches'] as List<dynamic>;
        await _processBranchesData(branches);
        print('✅ Branches processed: ${branches.length} items');
      }
      
      // Process wholesalers
      if (results['wholesalers'] != null) {
        final wholesalers = results['wholesalers'] as List<dynamic>;
        await _processWholesalersData(wholesalers);
        print('✅ Wholesalers processed: ${wholesalers.length} items');
      }
      
      // Process category data
      if (results['categoryData'] != null) {
        final categoryData = results['categoryData'] as Map<String, dynamic>;
        setState(() {
          _categoryData = categoryData.cast<String, Map<String, dynamic>>();
        });
        print('✅ Category data processed');
      }
      
      // Show nearby companies if location is available
      // Temporarily disabled to avoid conflicts with parallel processing
      // if (_currentLocation != null || _initialLocationSet) {
      //   print('🔍 Calling _showNearbyCompanies after parallel processing');
      //   _showNearbyCompanies();
      // }
      
      print('🔍 Final marker count after parallel processing: ${_wayPointMarkers.length}');
      
    } catch (e) {
      print('❌ Error processing parallel results: $e');
    }
  }
  
  // Fallback to sequential loading if parallel fails
  Future<void> _fallbackSequentialLoading() async {
    print('🔄 Falling back to sequential loading...');
    
    try {
      // Load data sequentially as before
      await _fetchCategoryData();
      await _fetchCategories();
      await _fetchCompanies();
      await _fetchAllBranches();
      await _fetchAllWholesalers();
      
      print('✅ Sequential loading completed');
    } catch (e) {
      print('❌ Error in sequential loading: $e');
    }
  }
  
  // Helper methods to process data with actual implementation
  Future<void> _processCompaniesData(List<dynamic> companies) async {
    try {
      print('Processing ${companies.length} companies...');
      
      // Filter out companies with status 'pending' or 'rejected'
      final filteredCompanies = companies.where((company) {
        final status = company['status'] ?? company['companyInfo']?['status'];
        return status == 'active';
      }).toList();

      // Store all companies for later use
      _allCompanies = List<Map<String, dynamic>>.from(filteredCompanies);

      setState(() {
        // Create markers for companies
        for (var company in filteredCompanies) {
          if (company['location'] != null &&
              company['location']['lat'] != null &&
              company['location']['lng'] != null) {

            final location = company['location'];
            final companyInfo = company['companyInfo'];

            _wayPointMarkers.add(
              google_maps.Marker(
                markerId: google_maps.MarkerId('company_${company['_id']}'),
                position: google_maps.LatLng(
                  location['lat'].toDouble(),
                  location['lng'].toDouble(),
                ),
                onTap: () {
                  setState(() {
                    _selectedPlace = {
                      'name': companyInfo?['name'] ?? 'Unknown Company',
                      '_id': company['_id'],
                      'latitude': location['lat'],
                      'longitude': location['lng'],
                      'address': company['address'] ?? 'No address available',
                      'phone': companyInfo?['phone'] ?? 'No phone available',
                      'description': companyInfo?['description'] ?? 'No description available',
                      'image': companyInfo?['logo'] ?? 'assets/images/company_placeholder.png',
                      'logoUrl': companyInfo?['logo'],
                      'companyName': companyInfo?['name'],
                      'companyId': company['_id'],
                      'category': companyInfo?['category'],
                      'company': companyInfo,
                    };
                  });
                },
                icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue),
              ),
            );
          }
        }
      });
      
      print('✅ Companies processed: ${filteredCompanies.length} items');
    } catch (e) {
      print('❌ Error processing companies: $e');
    }
  }
  
  Future<void> _processBranchesData(List<dynamic> branches) async {
    try {
      print('Processing ${branches.length} branches...');
      
      // Filter out branches whose status is not 'active'
      print('🔍 Total branches received: ${branches.length}');
      final filteredBranches = branches.where((branch) {
        final branchStatus = branch['status'];
        final isActive = branchStatus == 'active';
        if (!isActive) {
          print('🔍 Filtered out branch: ${branch['name']} - Status: $branchStatus');
        }
        return isActive;
      }).toList();
      print('🔍 Active branches after filtering: ${filteredBranches.length}');
      
      setState(() {
        _allBranches = List<Map<String, dynamic>>.from(filteredBranches);
      });

      // Update active branches data
      _updateActiveBranches();

      // Create markers for filtered branches
      final branchMarkers = await Future.wait(filteredBranches.map((branch) async {
        final location = branch['location'];
        if (location == null ||
            location['lat'] == null ||
            location['lng'] == null) {
          return null;
        }

        final lat = location['lat'].toDouble();
        final lng = location['lng'].toDouble();
        
        if (lat == 0.0 && lng == 0.0) {
          return null;
        }

        // Debug: Print branch data structure
        print('🔍 Branch data keys: ${branch.keys.toList()}');
        print('🔍 Branch _id: ${branch['_id']}');
        print('🔍 Branch id: ${branch['id']}');
        print('🔍 Branch name: ${branch['name']}');

        // Use id or _id or generate a unique ID
        final branchId = branch['_id'] ?? branch['id'] ?? 'branch_${DateTime.now().millisecondsSinceEpoch}_${lat.toString()}_${lng.toString()}';
        
        return google_maps.Marker(
          markerId: google_maps.MarkerId('branch_$branchId'),
          position: google_maps.LatLng(lat, lng),
          onTap: () {
            setState(() {
              _selectedPlace = {
                'name': branch['name'] ?? 'Unknown Branch',
                '_id': branch['_id'],
                'latitude': lat,
                'longitude': lng,
                'address': branch['address'] ?? 'No address available',
                'phone': branch['phone'] ?? 'No phone available',
                'description': branch['description'] ?? 'No description available',
                'image': branch['images']?.isNotEmpty == true 
                    ? branch['images'][0] 
                    : 'assets/images/branch_placeholder.png',
                'category': branch['category'],
                'company': branch['company'],
                'socialMedia': _getValidSocialMedia(branch['socialMedia'], branch['company']?['socialMedia']),
              };
            });
          },
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
        );
      }));

      final validBranchMarkers = branchMarkers.where((marker) => marker != null).cast<google_maps.Marker>().toList();
      print('🔍 Valid branch markers created: ${validBranchMarkers.length}');
      
      setState(() {
        _wayPointMarkers.addAll(validBranchMarkers);
      });
      
      print('✅ Branches processed: ${filteredBranches.length} items');
      print('🔍 Total markers after branches: ${_wayPointMarkers.length}');
    } catch (e) {
      print('❌ Error processing branches: $e');
    }
  }
  
  Future<void> _processWholesalersData(List<dynamic> wholesalers) async {
    try {
      print('Processing ${wholesalers.length} wholesalers...');
      
      // Filter wholesalers with active branches
      final filteredWholesalers = wholesalers.where((wholesaler) {
        final hasActiveBranches = wholesaler['branches']?.any((branch) => branch['status'] == 'active') ?? false;
        return hasActiveBranches;
      }).toList();

      // Create markers for wholesaler branches
      final wholesalerMarkers = <google_maps.Marker>[];
      
      for (var wholesaler in filteredWholesalers) {
        for (var branch in wholesaler['branches'] ?? []) {
          if (branch['status'] == 'active' && branch['location'] != null) {
            final location = branch['location'];
            final lat = location['lat']?.toDouble();
            final lng = location['lng']?.toDouble();
            
            if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
              // Debug: Print wholesaler branch data
              print('🔍 Wholesaler data keys: ${wholesaler.keys.toList()}');
              print('🔍 Branch data keys: ${branch.keys.toList()}');
              print('🔍 Wholesaler _id: ${wholesaler['_id']}');
              print('🔍 Branch _id: ${branch['_id']}');
              
              // Use id or _id or generate unique IDs
              final wholesalerId = wholesaler['_id'] ?? wholesaler['id'] ?? 'wholesaler_${DateTime.now().millisecondsSinceEpoch}';
              final branchId = branch['_id'] ?? branch['id'] ?? 'branch_${DateTime.now().millisecondsSinceEpoch}';
              
              wholesalerMarkers.add(
                google_maps.Marker(
                  markerId: google_maps.MarkerId('wholesaler_branch_${wholesalerId}_${branchId}'),
                  position: google_maps.LatLng(lat, lng),
                  onTap: () {
                    setState(() {
                      _selectedPlace = {
                        'name': branch['name'] ?? 'Unknown Branch',
                        '_id': branch['_id'],
                        'latitude': lat,
                        'longitude': lng,
                        'address': branch['address'] ?? 'No address available',
                        'phone': branch['phone'] ?? 'No phone available',
                        'description': branch['description'] ?? 'No description available',
                        'image': wholesaler['logoUrl'] ?? 'assets/images/wholesaler_placeholder.png',
                        'logoUrl': wholesaler['logoUrl'],
                        'companyName': wholesaler['businessName'],
                        'companyId': wholesaler['_id'],
                        'category': branch['category'],
                        'company': {
                          'businessName': wholesaler['businessName'],
                          'logoUrl': wholesaler['logoUrl'],
                          'id': wholesaler['_id'],
                        },
                      };
                    });
                  },
                  icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueOrange),
                ),
              );
            }
          }
        }
      }

      setState(() {
        _wayPointMarkers.addAll(wholesalerMarkers);
      });
      
      print('✅ Wholesalers processed: ${filteredWholesalers.length} items');
      print('🔍 Total markers after wholesalers: ${_wayPointMarkers.length}');
    } catch (e) {
      print('❌ Error processing wholesalers: $e');
    }
  }

  // Helper to always get a valid user location
  latlong.LatLng get _userLocation => _currentLocation ?? _defaultLocation;

  // Helper to get valid social media, preferring branch over company
  Map<String, dynamic> _getValidSocialMedia(dynamic branchSocial, dynamic companySocial) {
    print('_getValidSocialMedia called with:');
    print('  branchSocial: $branchSocial');
    print('  companySocial: $companySocial');
    print('  branchSocial type: ${branchSocial.runtimeType}');
    print('  companySocial type: ${companySocial.runtimeType}');
    
    // Debug: Check if the data is actually null or if it's being processed incorrectly
    if (branchSocial == null) {
      print('  WARNING: branchSocial is null');
    } else if (branchSocial is Map) {
      print('  branchSocial is a Map with keys: ${branchSocial.keys.toList()}');
      print('  branchSocial values: ${branchSocial.values.toList()}');
    }
    
    if (companySocial == null) {
      print('  WARNING: companySocial is null');
    } else if (companySocial is Map) {
      print('  companySocial is a Map with keys: ${companySocial.keys.toList()}');
      print('  companySocial values: ${companySocial.values.toList()}');
    }
    
    // Check if branch has valid social media
    if (branchSocial != null && branchSocial is Map && branchSocial.isNotEmpty) {
      final branchIg = branchSocial['instagram']?.toString().trim();
      final branchFb = branchSocial['facebook']?.toString().trim();
      
      final hasValidBranchIg = branchIg != null && branchIg.isNotEmpty && branchIg != '{}' && branchIg != '""' && branchIg != 'null';
      final hasValidBranchFb = branchFb != null && branchFb.isNotEmpty && branchFb != '{}' && branchFb != '""' && branchFb != 'null';
      
      print('  Branch social media: instagram="$branchIg", facebook="$branchFb"');
      print('  Has valid branch IG: $hasValidBranchIg, Has valid branch FB: $hasValidBranchFb');
      
      if (hasValidBranchIg || hasValidBranchFb) {
        final result = {
          'instagram': hasValidBranchIg ? branchIg : '',
          'facebook': hasValidBranchFb ? branchFb : '',
        };
        print('  Using branch social media: $result');
        return result;
      }
    }
    
    // Fallback to company social media
    if (companySocial != null && companySocial is Map) {
      final companyIg = companySocial['instagram']?.toString().trim();
      final companyFb = companySocial['facebook']?.toString().trim();
      
      final hasValidCompanyIg = companyIg != null && companyIg.isNotEmpty && companyIg != '{}' && companyIg != '""' && companyIg != 'null';
      final hasValidCompanyFb = companyFb != null && companyFb.isNotEmpty && companyFb != '{}' && companyFb != '""' && companyFb != 'null';
      
      print('  Company social media: instagram="$companyIg", facebook="$companyFb"');
      print('  Has valid company IG: $hasValidCompanyIg, Has valid company FB: $hasValidCompanyFb');
      
      final result = {
        'instagram': hasValidCompanyIg ? companyIg : '',
        'facebook': hasValidCompanyFb ? companyFb : '',
      };
      print('  Using company social media: $result');
      return result;
    }
    
    print('  No valid social media found, returning empty');
    return {'instagram': '', 'facebook': ''};
  }

  // Method to restore all markers (company, wholesaler, and branch markers)
  void _restoreAllMarkers() {
    setState(() {
      // This will trigger a rebuild with all existing markers
      // The markers are already loaded in _wayPointMarkers from initState
      print('Restoring all markers: ${_wayPointMarkers.length}');
    });
  }

  // Add a test marker to verify map rendering works
  void _addTestMarker() {
    print('Adding test marker...');
    final testMarker = google_maps.Marker(
      markerId: google_maps.MarkerId('test_marker'),
      position: google_maps.LatLng(33.8938, 35.5018), // Beirut center
      icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed),
      infoWindow: google_maps.InfoWindow(title: 'Test Marker'),
      visible: true,
      onTap: () {
        print('Test marker tapped!');
      },
    );
    
    setState(() {
      _wayPointMarkers.add(testMarker);
      print('Test marker added. Total markers: ${_wayPointMarkers.length}');
    });
  }



  // Helper method to create custom wholesaler marker icon
  Future<google_maps.BitmapDescriptor> _createWholesalerMarkerIcon() async {
    try {
      print('Loading wholesaler icon from assets/icons/wholesaler.png...');
      final ByteData data = await rootBundle.load('assets/icons/wholesaler.png');
      final Uint8List bytes = data.buffer.asUint8List();
      print('Successfully loaded wholesaler icon, size: ${bytes.length} bytes');
      
      // Create the bitmap descriptor from the image bytes
      final bitmapDescriptor = await google_maps.BitmapDescriptor.fromBytes(bytes);
      print('Successfully created BitmapDescriptor from wholesaler icon');
      return bitmapDescriptor;
    } catch (e) {
      print('Error loading wholesaler icon: $e');
      print('Error details: ${e.toString()}');
      print('Falling back to default orange marker');
      // Fallback to default orange marker if image loading fails
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueOrange);
    }
  }

  // Alternative method to create wholesaler icon with different approach
  Future<google_maps.BitmapDescriptor> _createWholesalerMarkerIconAlternative() async {
    try {
      print('Trying alternative wholesaler icon creation...');
      
      // Try using a different approach - create a simple colored marker
      // This ensures we always have a visible marker
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueOrange);
    } catch (e) {
      print('Error in alternative icon creation: $e');
      // Final fallback
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed);
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

  // Test function to verify wholesaler icon loading
  void _testWholesalerIcon() async {
    print('=== Testing Wholesaler Icon Loading ===');
    try {
      final icon = await _createWholesalerMarkerIcon();
      print('Wholesaler icon loaded successfully: $icon');
      print('Icon type: ${icon.runtimeType}');
    } catch (e) {
      print('Error loading wholesaler icon: $e');
    }
    print('=== End Wholesaler Icon Test ===');
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

  // Build dynamic category buttons from API data
  Widget _buildCategoryButtons() {
    if (_displayCategories.isEmpty) {
      // Show default categories while loading
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // Align all buttons to center
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: CategoryCircleButton(
                icon: Icons.store,
                label: 'Stores',
                isSelected: _selectedCategory == 'Stores',
                onTap: () {
                  if (_selectedCategory == 'Stores') {
                    _clearCategoryFilter();
                  } else {
                    _filterCompaniesByApiCategory('Stores');
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: CategoryCircleButton(
                icon: Icons.hotel,
                label: 'Lodging',
                isSelected: _selectedCategory == 'Lodging',
                onTap: () {
                  if (_selectedCategory == 'Lodging') {
                    _clearCategoryFilter();
                  } else {
                    _filterCompaniesByApiCategory('Lodging');
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: CategoryCircleButton(
                icon: Icons.restaurant,
                label: 'Food & Beverage',
                isSelected: _selectedCategory == 'Food & Beverage',
                onTap: () {
                  if (_selectedCategory == 'Food & Beverage') {
                    _clearCategoryFilter();
                  } else {
                    _filterCompaniesByApiCategory('Food & Beverage');
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: CategoryCircleButton(
                icon: Icons.sports,
                label: 'Sports',
                isSelected: _selectedCategory == 'Sports',
                onTap: () {
                  if (_selectedCategory == 'Sports') {
                    _clearCategoryFilter();
                  } else {
                    _filterCompaniesByApiCategory('Sports');
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Align all buttons to center
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _displayCategories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < _displayCategories.length - 1 ? 4.0 : 0.0,
              ),
              child: CategoryCircleButton(
                icon: _getCategoryIcon(category),
                label: category,
                isSelected: _selectedCategory == category,
                onTap: () {
                  if (_selectedCategory == category) {
                    _clearCategoryFilter();
                  } else {
                    setState(() {
                      _selectedCategory = category;
                    });
                    _filterCompaniesByApiCategory(category);
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Get appropriate icon for each category
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'stores':
        return Icons.store;
      case 'lodging':
        return Icons.hotel;
      case 'food & beverage':
        return Icons.restaurant;
      case 'sports':
        return Icons.sports;
      case 'vehicles':
        return Icons.directions_car;
      case 'health':
        return Icons.local_hospital;
      case 'entertainment':
        return Icons.movie;
      case 'education':
        return Icons.school;
      case 'beauty & fashion':
        return Icons.face;
      case 'financial services':
        return Icons.account_balance;
      case 'automotive services':
        return Icons.build;
      case 'real estate':
        return Icons.home;
      case 'technology':
        return Icons.computer;
      case 'travel':
        return Icons.flight;
      case 'services':
        return Icons.room_service;
      default:
        return Icons.category;
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    try {
      // Validate input coordinates
      if (lat1.isNaN || lon1.isNaN || lat2.isNaN || lon2.isNaN ||
          lat1.isInfinite || lon1.isInfinite || lat2.isInfinite || lon2.isInfinite) {
        print('Invalid coordinates: lat1=$lat1, lon1=$lon1, lat2=$lat2, lon2=$lon2');
        return 999999.0; // Return large finite number for invalid coordinates
      }
      
      // Check if coordinates are within valid ranges
      if (lat1 < -90 || lat1 > 90 || lat2 < -90 || lat2 > 90 ||
          lon1 < -180 || lon1 > 180 || lon2 < -180 || lon2 > 180) {
        print('Coordinates out of range: lat1=$lat1, lon1=$lon1, lat2=$lat2, lon2=$lon2');
        return 999999.0; // Return large finite number for out-of-range coordinates
      }
      
      const R = 6371.0; // Earth's radius in kilometers
      final dLat = _toRadians(lat2 - lat1);
      final dLon = _toRadians(lon2 - lon1);
      final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos(_toRadians(lat1)) * Math.cos(_toRadians(lat2)) *
          Math.sin(dLon / 2) * Math.sin(dLon / 2);
      final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      final result = R * c;
      
      // Validate the result
      if (result.isNaN || result.isInfinite) {
        print('Invalid distance calculation result: $result');
        return 999999.0; // Return large finite number for invalid results
      }
      
      return result;
    } catch (e) {
      print('Error calculating distance: $e');
      return 999999.0; // Return large finite number on error
    }
  }

  // Convert degrees to radians
  double _toRadians(double degree) {
    return degree * Math.pi / 180;
  }

  Future<void> _setDestination(latlong.LatLng destination) async {
    print('=== SETTING DESTINATION ===');
    print('Destination: ${destination.latitude}, ${destination.longitude}');
    print('Current location: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
    print('Currently navigating: $_isNavigating');
    print('Selected place: ${_selectedPlace?['name']}');

    // Close PlaceDetailsOverlay if it's open when map is tapped
    if (_selectedPlace != null) {
      setState(() {
        _selectedPlace = null;
      });
      print('Closed PlaceDetailsOverlay due to map tap');
      return; // Don't set destination if just closing the overlay
    }

    await _startNavigation(destination);
  }

  Future<void> _startNavigation(latlong.LatLng destination) async {
    print('=== STARTING NAVIGATION ===');
    print('Destination: ${destination.latitude}, ${destination.longitude}');
    print('Current location: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');

    if (_isNavigating) {
      // If already navigating, ask user if they want to change destination
      final shouldChange = await _showChangeDestinationDialog();
      if (!shouldChange) return;
    }

    print('Setting new destination and clearing old routes...');
    setState(() {
      _destinationLocation = destination;
      _isNavigating = true;
      // Clear old routes before setting new destination
      _primaryRouteCoordinates.clear();
      _alternativeRouteCoordinates.clear();
      _routeInstructions = '';
      _primaryDistance = 0;
      _primaryDuration = 0;
      _alternativeDistance = 0;
      _alternativeDuration = 0;
      _steps.clear();
      _usingPrimaryRoute = true;
      // Remove old route waypoint markers
      _wayPointMarkers.removeWhere((marker) => 
        marker is google_maps.Marker && 
        marker.markerId.value.startsWith('waypoint_'));
      
      // Increment map update counter to force rebuild
      _mapUpdateCounter++;
    });

    // Immediately move map to destination while route calculation is happening
    print('Moving map to destination immediately: ${destination.latitude}, ${destination.longitude}');
    _mapController.move(destination, 15.0);

    print('About to call _getRouteDirections...');
    await _getRouteDirections();
    print('_getRouteDirections completed');
    print('Route coordinates after calculation:');
    print('Primary route: ${_primaryRouteCoordinates.length} points');
    print('Alternative route: ${_alternativeRouteCoordinates.length} points');
    print('==============================');
  }


















}
