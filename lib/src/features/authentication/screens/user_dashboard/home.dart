import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import '../../../../components/category_circle_button.dart';
import '../../../../components/collapsed_sheet.dart';
import '../../../../components/map_component.dart';
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

class Home extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Home({super.key, required this.userData});
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isSidebarOpen = false;
  bool _isMapExpanded = true;
  Map<String, dynamic>? _selectedPlace;
// Add to your existing _HomeState class variables
  bool _showSearchResults = false;
  List<Map<String, dynamic>> _searchResults = [];
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  // OpenStreetMap related variables
  final MapController _mapController = MapController();
  final Location _locationTracker = Location();
  final PolylinePoints _polylinePoints = PolylinePoints();
  StreamSubscription<LocationData>? _locationSubscription;

  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  List<LatLng> _primaryRouteCoordinates = [];
  List<LatLng> _alternativeRouteCoordinates = [];
  bool _isTracking = false;
  bool _isNavigating = false;
  String _routeInstructions = '';
  bool _initialLocationSet = false;
  bool _isLoading = false;
  double _primaryDistance = 0;
  double _primaryDuration = 0;
  double _alternativeDistance = 0;
  double _alternativeDuration = 0;
  List<Map<String, dynamic>> _steps = [];
  bool _usingPrimaryRoute = true;
  List<Marker> _wayPointMarkers = [];
  final Color primaryRouteColor = Colors.blue;
  final Color alternativeRouteColor = Colors.purple;
  List<Map<String, dynamic>> _allBranches = [];
  List<Map<String, dynamic>> _allCompanies = [];
  List<Map<String, dynamic>> _wholesalerBranches = [];

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '';

  Wholesaler? _myWholesaler;
  Marker? _myWholesalerMarker;
  final WholesalerService _wholesalerService = WholesalerService();

  // Track if location is denied
  bool _locationDenied = false;

// Add this method to fetch branches
  Future<void> _fetchAllBranches() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final branches = await ApiService.getAllBranches();

      setState(() {
        _allBranches = branches;

        // Create markers for all branches
        final branchMarkers = branches.map((branch) {
          final location = branch['location'];
          final company = branch['company'];
          final logoUrl = company['logoUrl'];

          // Validate location data
          if (location == null ||
              location['lat'] == null ||
              location['lng'] == null) {
            return null;
          }

          return Marker(
            point: LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
            width: 40,
            height: 40,
            builder: (ctx) => GestureDetector(
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
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        logoUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.store,
                            color: Colors.green,
                            size: 40,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.store,
                      color: Colors.green,
                      size: 40,
                    ),
            ),
          );
        }).where((marker) => marker != null).cast<Marker>().toList();

        // Add branch markers to existing company markers
        _wayPointMarkers.addAll(branchMarkers);

        _isLoading = false;
      });

      // Move camera to the first marker if exists
      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].point, 14.0);
      }
    } catch (e) {
      print('Error fetching branches: $e');
      setState(() {
        _isLoading = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load branches: $e')),
      // );
    }
  }

// Add this function to filter branches by category
  void _filterBranchesByCategory(String categoryType) {
    setState(() {
      _isLoading = true;
    });

    try {
      // Map the UI category names to database category names
      final Map<String, String> categoryMapping = {
        'Stations': 'station',
        'Restaurant': 'restaurant',
        'Hotels': 'hotel',
        'Shops': 'shop',
      };

      // Get the database category name
      final String dbCategory = categoryMapping[categoryType]?.toLowerCase() ?? categoryType.toLowerCase();

      // Filter branches based on the category
      final filteredBranches = _allBranches.where((branch) {
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
        setState(() {
          _isLoading = false;
        });
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

          return Marker(
            point: LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
            width: 40,
            height: 40,
            builder: (ctx) => GestureDetector(
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
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        logoUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.store,
                            color: Colors.green,
                            size: 40,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.store,
                      color: Colors.green,
                      size: 40,
                    ),
            ),
          );
        }).where((marker) => marker != null).cast<Marker>().toList();

        _isLoading = false;
      });

      // Move camera to the first filtered marker if exists
      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].point, 15.0);
      }
    } catch (e) {
      print('Error filtering branches: $e');
      setState(() {
        _isLoading = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to filter branches: $e')),
      // );
    }
  }



  Future<void> _fetchCompanies() async {
    try {
      final companies = await ApiService.getCompaniesWithLocations();
      print('Raw companies data: ${jsonEncode(companies)}'); // Debug output

      // Store all companies for later use in filtering and searching
      _allCompanies = List<Map<String, dynamic>>.from(companies);

      setState(() {
        // Create markers for companies and their branches
        _wayPointMarkers = [];

        for (var company in companies) {
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
              Marker(
                point: LatLng(
                  location['lat'].toDouble(),
                  location['lng'].toDouble(),
                ),
                width: 50, // Slightly larger for company headquarters
                height: 50,
                builder: (ctx) => GestureDetector(
                  onTap: () async {
                    try {
                      // Fetch branches for this company
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('auth_token');
                      if (token != null) {
                        setState(() {
                          _isLoading = true;
                        });

                        final branches = await ApiService.getCompanyBranches(token);
                        // Filter branches for this specific company
                        final companyBranches = branches.where((b) => b['companyId'] == company['_id']).toList();

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
                          _isLoading = false;
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
                        _isLoading = false;
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
                  child: Stack(
                    children: [
                      // Company logo
                      logoUrl != null && logoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.network(
                                logoUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading company logo: $error');
                                  return Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Icon(
                                      Icons.business,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Icon(
                                Icons.business,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                      // Company indicator
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                  Marker(
                    point: LatLng(
                      branchLocation['lat'].toDouble(),
                      branchLocation['lng'].toDouble(),
                    ),
                    width: 40,
                    height: 40,
                    builder: (ctx) => GestureDetector(
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: logoUrl != null && logoUrl.isNotEmpty
                              ? Image.network(
                                  logoUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Error loading branch logo: $error');
                                    return Icon(
                                      Icons.store,
                                      color: Colors.blue,
                                      size: 30,
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.store,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                        ),
                      ),
                    ),
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
        _mapController.move(_wayPointMarkers[0].point, 15.0);
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

  void _createMarkersFromCompanies(List<Map<String, dynamic>> companies) {
    setState(() {
      _wayPointMarkers = companies.map((company) {
        final location = company['location'];
        final companyInfo = company['companyInfo'];
        final logoUrl = companyInfo?['logo'];

        return Marker(
          point: LatLng(
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          ),
          width: 40,
          height: 40,
          // Update the marker tap handler in home.dart
          builder: (ctx) => GestureDetector(
            onTap: () async {
              try {
                // Fetch branches for this company
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('auth_token');
                if (token != null) {
                  setState(() {
                    _isLoading = true; // Show loading indicator
                  });

                  final branches = await ApiService.getCompanyBranches(token);
                  // Filter branches for this specific company
                  final companyBranches = branches.where((b) => b['companyId'] == company['_id']).toList();

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
                    _isLoading = false;
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
                  _isLoading = false;
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
            child: logoUrl != null && logoUrl.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                logoUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.business,
                    color: Colors.blue,
                    size: 40,
                  );
                },
              ),
            )
                : Icon(
              Icons.business,
              color: Colors.blue,
              size: 40,
            ),
          ),
        );
      }).where((marker) => marker != null).cast<Marker>().toList();
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
        if (wholesaler.branches.isNotEmpty) {
          lat = wholesaler.branches.first.location.lat;
          lng = wholesaler.branches.first.location.lng;
          address = '${wholesaler.branches.first.location.street}, ${wholesaler.branches.first.location.city}';
        } else if (wholesaler.address != null) {
          lat = wholesaler.address!.lat;
          lng = wholesaler.address!.lng;
          address = '${wholesaler.address!.street}, ${wholesaler.address!.city}';
        }
        if (lat == 0.0 && lng == 0.0) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          builder: (ctx) => GestureDetector(
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
            child: Image.asset(
              'assets/icons/wholesaler.png',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.store,
                  color: Colors.blue,
                  size: 40,
                );
              },
            ),
          ),
        );
      }).where((marker) => marker != null).cast<Marker>().toList();

      setState(() {
        _wayPointMarkers = wholesalerMarkers;
      });

      if (_wayPointMarkers.isNotEmpty && _mapController != null) {
        _mapController.move(_wayPointMarkers[0].point, 14.0);
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
      _mapController.move(_wayPointMarkers[0].point, 14.0);
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
        return Marker(
          point: LatLng(place['latitude'], place['longitude']),
          width: 40,
          height: 40,
          builder: (ctx) => GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlace = place;
              });
            },
            child: Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          ),
        );
        print('Number of markers created: ${_wayPointMarkers.length}');
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _initLocationOrFallback();
    if (_allCompanies.isEmpty) {
      _fetchCompanies();
    }
    _fetchAllBranches();
    _fetchAllWholesalers();
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
  }

  void _initLocationOrFallback() async {
    var status = await Permission.location.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      // Permission denied, use default location
      setState(() {
        _currentLocation = _defaultLocation;
        _initialLocationSet = true;
        _locationDenied = true;
      });
      _mapController.move(_defaultLocation, 15.0);
      return;
    }
    if (status.isGranted) {
      try {
        await _getCurrentLocation();
        _startLocationTracking();
        setState(() {
          _locationDenied = false;
        });
      } catch (e) {
        setState(() {
          _currentLocation = _defaultLocation;
          _initialLocationSet = true;
          _locationDenied = true;
        });
        _mapController.move(_defaultLocation, 15.0);
      }
    } else {
      // Not granted, use default
      setState(() {
        _currentLocation = _defaultLocation;
        _initialLocationSet = true;
        _locationDenied = true;
      });
      _mapController.move(_defaultLocation, 15.0);
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
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

    setState(() {
      _isLoading = true;
    });

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
          _isLoading = false;
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
        _isLoading = false;
        _searchResults = [];
        _showSearchResults = false;
      });
    }
  }

  // Default location: Beirut, Lebanon
  static const LatLng _defaultLocation = LatLng(33.8938, 35.5018);

  Future<void> _getCurrentLocation() async {
    try {
      var location = await _locationTracker.getLocation();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(location.latitude!, location.longitude!);
          print('INITIAL USER LOCATION: Lat=location.latitude}, Lng=${location.longitude}');
          if (!_initialLocationSet && _mapController != null) {
            _mapController.move(_currentLocation!, 15.0);
            _initialLocationSet = true;
          }
        });
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
      }
    }
  }

  void _startLocationTracking() {
    bool _autoFollowUser = false;

    _locationSubscription?.cancel();

    _locationSubscription = _locationTracker.onLocationChanged.listen((location) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(location.latitude!, location.longitude!);
        });
        print('USER LIVE LOCATION: Lat=${location.latitude}, Lng=${location.longitude}');


        if (_autoFollowUser && _isNavigating && _destinationLocation != null) {
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

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(_toRadians(lat1)) * Math.cos(_toRadians(lat2)) *
                Math.sin(dLon/2) * Math.sin(dLon/2);

    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    double distance = earthRadius * c;

    return distance;
  }

  double _toRadians(double degree) {
    return degree * (Math.pi / 180);
  }

  void _setDestination(LatLng point) async {
    if (_isNavigating) {
      bool shouldContinue = await _showChangeDestinationDialog();
      if (!shouldContinue) return;
    }

    setState(() {
      _destinationLocation = point;
      _isNavigating = true;
      _isLoading = true;
      _wayPointMarkers = [];
      _primaryRouteCoordinates = [];
      _alternativeRouteCoordinates = [];
      _wayPointMarkers.add(
          Marker(
            point: point,
            width: 40,
            height: 40,
            builder: (ctx) => Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          )
      );
    });

    await _getRouteDirections();

    if (!_isTracking) {
      _startLocationTracking();
    }

    setState(() {
      _isLoading = false;
      if (_currentLocation != null) {
        _fitBounds();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation started. Follow the blue route.'),
        duration: Duration(seconds: 3),
      ),
    );
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
              .map((point) => LatLng(point.latitude, point.longitude))
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
              .map((point) => LatLng(point.latitude, point.longitude))
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
            Marker(
              point: LatLng(location[1], location[0]),
              width: 30,
              height: 30,
              builder: (ctx) => Icon(Icons.adjust, color: Colors.green, size: 20),
            ),
          );
        }
      }
    }
  }

  void _fitBounds() {
    List<LatLng> allPoints = [];

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

    final LatLngBounds bounds = LatLngBounds(
      LatLng(minLat - 0.05, minLng - 0.05),
      LatLng(maxLat + 0.05, maxLng + 0.05),
    );

    _mapController.fitBounds(
      bounds,
      options: FitBoundsOptions(padding: EdgeInsets.all(50.0)),
    );
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

  void _recalculateRoute() {
    if (_currentLocation != null && _destinationLocation != null) {
      setState(() {
        _isLoading = true;
      });
      _getRouteDirections().then((_) {
        setState(() {
          _isLoading = false;
        });
      });
    }
  }



  void _searchPlace(String query) {
    if (query.isEmpty) return;

    setState(() {
      _wayPointMarkers.clear();
      _primaryRouteCoordinates.clear();
      _alternativeRouteCoordinates.clear();
      _isLoading = true;
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

        return Marker(
          point: LatLng(
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          ),
          width: 40,
          height: 40,
          builder: (ctx) => GestureDetector(
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

                };
              });
            },
            child: logoUrl != null && logoUrl.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                logoUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.business,
                    color: Colors.blue,
                    size: 40,
                  );
                },
              ),
            )
                : Icon(
              Icons.business,
              color: Colors.blue,
              size: 40,
            ),
          ),
        );
      }).where((marker) => marker != null).cast<Marker>().toList();

      _isLoading = false;
    });

    // Move camera to the first match
    if (_wayPointMarkers.isNotEmpty && _mapController != null) {
      _mapController.move(_wayPointMarkers[0].point, 15.0);
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
        _mapController.move(_wayPointMarkers[0].point, 15.0);
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
                  profileImagePath: widget.userData['profilePic'] != null && widget.userData['profilePic'].toString().isNotEmpty
                      ? ApiService.getImageUrl(widget.userData['profilePic'])
                      : null,
                  onNotificationTap: () {
                    print('User Data: ${widget.userData}');
                    print('Profile Pic Path: ${widget.userData['profilePic']}');
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
                      if (_isLoading)
                        Center(
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Calculating routes...'),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 120,
                        left: 0,
                        right: 0,
                        child: Row(
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
                        ),
                      ),
                      Positioned(
                        bottom: 42,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
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
                          ),
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
                  onNavigate: (LatLng destination) {
                    _setDestination(destination);
                    if (!_isTracking) {
                      _startLocationTracking();
                    }
                    setState(() {
                      _selectedPlace = null;
                    });
                  },
                  onBranchSelect: (LatLng branchLocation, String branchName) {
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
                          LatLng(place['latitude'], place['longitude']),
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
      setState(() {
        _isLoading = true;
      });

      final wholesalers = await _wholesalerService.getAllWholesalers();
      
      // Print detailed wholesaler data for debugging
      print('\n=== WHOLESALER DATA DEBUG ===');
      print('Total wholesalers retrieved: ${wholesalers.length}');
      
      for (var wholesaler in wholesalers) {
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
      
      if (wholesalers.isNotEmpty) {
        // Create markers for each wholesaler
        final wholesalerMarkers = wholesalers.map((wholesaler) {
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
            // Use wholesaler's address if no branches
            lat = wholesaler.address!.lat;
            lng = wholesaler.address!.lng;
            address = '${wholesaler.address!.street}, ${wholesaler.address!.city}';
            print('Using wholesaler address for ${wholesaler.businessName}: $lat, $lng');
          } else {
            // Use default location (you can adjust these coordinates)
            lat = 0.0; // Replace with default latitude
            lng = 0.0; // Replace with default longitude
            address = 'Location not specified';
            print('No location available for wholesaler: ${wholesaler.businessName}');
          }

          // Skip if no valid coordinates
          if (lat == 0.0 && lng == 0.0) {
            print('Skipping wholesaler ${wholesaler.businessName} - no valid coordinates');
            return null;
          }

          print('Creating marker for wholesaler: ${wholesaler.businessName} at $lat, $lng');
          return Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            builder: (ctx) => GestureDetector(
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
              child: Image.asset(
              'assets/icons/wholesaler.png',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading wholesaler icon: $error');
                return Icon(
                  Icons.store,
                  color: Colors.blue,
                  size: 40,
                );
              },
            ),
            ),
          );
        }).where((marker) => marker != null).cast<Marker>().toList();

        print('\nCreated ${wholesalerMarkers.length} markers out of ${wholesalers.length} wholesalers');

        setState(() {
          // Add wholesaler markers to existing markers
          _wayPointMarkers.addAll(wholesalerMarkers);
          _isLoading = false;
        });

        // Move camera to the first marker if no other markers are present
        if (_wayPointMarkers.isNotEmpty && _mapController != null) {
          _mapController.move(_wayPointMarkers[0].point, 14.0);
        }
      } else {
        print('No wholesalers found');
      }
    } catch (e) {
      print('Error fetching all wholesalers: $e');
      setState(() {
        _isLoading = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load wholesalers: $e')),
      // );
    }
  }

  // Helper to always get a valid user location
  LatLng get _userLocation => _currentLocation ?? _defaultLocation;
}

