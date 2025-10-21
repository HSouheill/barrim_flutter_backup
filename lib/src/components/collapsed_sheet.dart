import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../models/company_model.dart' as company_model;
import '../services/company_service.dart';
import '../services/api_service.dart';
import '../utils/api_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:barrim/src/components/secure_network_image.dart';
import '../features/authentication/screens/user_dashboard/notification.dart';
import '../services/wholesaler_service.dart';
import '../models/wholesaler_model.dart' as wholesaler_model;

class CollapsedSheet extends StatefulWidget {
  final ScrollController? controller;
  final VoidCallback onLocationCardTap;
  final Function(Map<String, dynamic>)? onPlaceTap;
  final VoidCallback? onCloseSheet;
  final List<Map<String, dynamic>>? activeBranches;
  final List<Map<String, dynamic>>? activeWholesalerBranches;

  const CollapsedSheet({
    Key? key,
    required this.controller,
    required this.onLocationCardTap,
    this.onPlaceTap,
    this.onCloseSheet,
    this.activeBranches,
    this.activeWholesalerBranches,
  }) : super(key: key);

  @override
  State<CollapsedSheet> createState() => _CollapsedSheetState();
}

class _CollapsedSheetState extends State<CollapsedSheet> {
  final CompanyService _companyService = CompanyService();
  final WholesalerService _wholesalerService = WholesalerService();
  List<company_model.Branch> _branches = [];
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = true;
  String? _errorMessage;
  LatLng? _currentUserLocation;
  VideoPlayerController? _videoController; // Add this line
  bool _isVideoPlaying = false;
  String _selectedTab = 'companies';
  
  // Active branches data from parent
  List<Map<String, dynamic>> _activeBranches = [];
  List<Map<String, dynamic>> _activeWholesalerBranches = [];

  // Top Listed section state variables
  List<Map<String, dynamic>> _sponsoredCompanies = [];
  List<Map<String, dynamic>> _sponsoredWholesalers = [];
  List<Map<String, dynamic>> _sponsoredServiceProviders = [];
  List<Map<String, dynamic>> _sponsoredBranches = []; // Add this line
  bool _isLoadingSponsored = true;
  String? _sponsoredErrorMessage;

  @override
  void initState() {
    super.initState();
    
    // Initialize active branches data from parent
    _activeBranches = widget.activeBranches ?? [];
    _activeWholesalerBranches = widget.activeWholesalerBranches ?? [];
    
    // Debug logging
    print('CollapsedSheet initState - Active branches received: ${_activeBranches.length}');
    print('CollapsedSheet initState - Active wholesaler branches received: ${_activeWholesalerBranches.length}');
    
    _loadData();
    _getUserLocation();
    _loadSponsoredEntities(); // Add this line to load sponsored entities
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load companies first, then branches (since branches now depend on companies data)
      await _loadCompanies();
      await _loadBranches();
      await _loadSponsoredEntities();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
        if (!kReleaseMode) {
          print(_errorMessage);
        }
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
        _loadSponsoredBranches(), // Add this line
      ]);

      setState(() {
        _isLoadingSponsored = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSponsored = false;
        _sponsoredErrorMessage = 'Failed to load sponsored entities: $e';
      });
      if (!kReleaseMode) {
        print('Error loading sponsored entities: $e');
      }
    }
  }


  Future<void> _loadSponsoredCompanies() async {
    try {
      final companies = await ApiService.getCompaniesWithLocations();
      
      // Check company sponsorship (companyInfo.sponsorship: true)
      final sponsoredCompanies = companies.where((company) {
        return company['sponsorship'] == true;
      }).toList();
      
      // ALSO check for sponsored branches within companies (branch.sponsorship: true)
      final sponsoredCompanyBranches = companies.expand((company) {
        final branches = company['branches'] ?? [];
        return branches.where((branch) {
          return branch['sponsorship'] == true;  // Check individual branch sponsorship
                              }).map((branch) => {
          // Map branch data with company context
          'id': branch['id'] ?? branch['_id'],
          'name': branch['name'],
          'category': branch['category'],
          'subCategory': branch['subCategory'],
          'phone': branch['phone'],
          'images': branch['images'] ?? [],
          'status': branch['status'],
          'sponsorship': branch['sponsorship'],
          'location': branch['location'],
          'type': 'company_branch',
          'companyId': company['_id'],
          'companyName': company['companyInfo']?['name'],
          'companyCategory': company['companyInfo']?['category'],
          'companyLogo': company['companyInfo']?['logo'],
        });
      }).toList();
      
      if (!kReleaseMode) {
        print('Found ${sponsoredCompanies.length} sponsored companies');
        print('Found ${sponsoredCompanyBranches.length} sponsored company branches');
      }
      
      // Combine both company-level and branch-level sponsored entities
      final allSponsoredCompanyEntities = [
        ...sponsoredCompanies,
        ...sponsoredCompanyBranches,
      ];
      
      setState(() {
        _sponsoredCompanies = allSponsoredCompanyEntities.map((entity) => entity as Map<String, dynamic>).toList();
      });
    } catch (e) {
      if (!kReleaseMode) {
        print('Error loading sponsored companies: $e');
      }
      throw e;
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
      if (!kReleaseMode) {
        print('Error loading sponsored wholesalers: $e');
      }
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
      if (!kReleaseMode) {
        print('Error loading sponsored service providers: $e');
      }
    }
  }

  Future<void> _loadSponsoredBranches() async {
    try {
      // Get sponsored branches from direct branch API
      final sponsoredBranches = await ApiService.getSponsoredBranches();
      
      // Also check for sponsored branches within wholesalers
      final wholesalers = await _wholesalerService.getAllWholesalers();
      
      // Extract sponsored branches from wholesalers
      final sponsoredBranchesFromWholesalers = wholesalers.expand((wholesaler) {
        return wholesaler.branches.where((branch) {
          // Check if the branch has sponsorship: true
          return branch.sponsorship == true;
        }).map((branch) => {
          'id': branch.id,
          'name': branch.name,
          'category': branch.category,
          'subCategory': branch.subCategory,
          'phone': branch.phone,
          'images': branch.images,
          'status': branch.status,
          'sponsorship': branch.sponsorship,
          'location': {
            'lat': branch.location.lat,
            'lng': branch.location.lng,
            'city': branch.location.city,
            'street': branch.location.street,
            'district': branch.location.district,
            'country': branch.location.country,
            'postalCode': branch.location.postalCode,
          },
          'type': 'wholesaler_branch',
          'wholesalerId': wholesaler.id,
          'wholesalerName': wholesaler.businessName,
          'wholesalerCategory': wholesaler.category,
        });
      }).toList();

      print('Found ${sponsoredBranchesFromWholesalers.length} sponsored branches from wholesalers');
      
      // Combine both sources
      final allSponsoredBranches = [
        ...sponsoredBranches,
        ...sponsoredBranchesFromWholesalers,
      ];

      print('Total sponsored branches: ${allSponsoredBranches.length}');

      setState(() {
        _sponsoredBranches = allSponsoredBranches;
      });
    } catch (e) {
      if (!kReleaseMode) {
        print('Error loading sponsored branches: $e');
      }
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await ApiService.getCompaniesWithLocations();
      
      // Filter out companies with status 'pending' or 'rejected'
      final filteredCompanies = companies.where((company) {
        final status = company['status'] ?? company['companyInfo']?['status'];
        return status == 'active';
      }).toList();
      
      // Show all companies regardless of distance
      List<Map<String, dynamic>> nearbyCompanies = [];
      
      // Convert all filtered companies to the required format
      nearbyCompanies = filteredCompanies.map((company) => company as Map<String, dynamic>).toList();
      
      // Sort companies by distance if user location is available (closest first)
      if (_currentUserLocation != null) {
        nearbyCompanies.sort((a, b) {
          final locationA = a['location'];
          final locationB = b['location'];
          
          if (locationA == null || locationB == null) return 0;
          
          // Check if both locations have valid coordinates
          if (locationA['lat'] == null || locationA['lng'] == null || 
              locationB['lat'] == null || locationB['lng'] == null) {
            return 0;
          }
          
          final distanceA = _calculateDistance(
            _currentUserLocation!.latitude,
            _currentUserLocation!.longitude,
            locationA['lat'].toDouble(),
            locationA['lng'].toDouble(),
          );
          
          final distanceB = _calculateDistance(
            _currentUserLocation!.latitude,
            _currentUserLocation!.longitude,
            locationB['lat'].toDouble(),
            locationB['lng'].toDouble(),
          );
          
          return distanceA.compareTo(distanceB);
        });
      }
      
      setState(() {
        _companies = nearbyCompanies;
      });
    } catch (e) {
      if (!kReleaseMode) {
        print('Error loading companies: $e');
      }
      throw e;
    }
  }

  Future<void> _loadBranches() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Instead of calling getAllBranches, extract branches from the companies data
      // This ensures we use the same data structure that's working in _loadCompanies
      List<company_model.Branch> allBranches = [];
      
      if (!kReleaseMode) {
        print('Loading branches from ${_companies.length} companies');
      }
      
      for (var company in _companies) {
        if (company['branches'] != null) {
          final branches = company['branches'];
          if (branches is! List) {
            if (!kReleaseMode) {
              print('Company ${company['businessName'] ?? 'Unknown'} has invalid branches data type: ${branches.runtimeType}');
            }
            continue;
          }
          
          if (!kReleaseMode) {
            print('Company ${company['businessName'] ?? 'Unknown'} has ${branches.length} branches');
          }
          
          for (var branchData in branches) {
            try {
              if (branchData is! Map<String, dynamic>) {
                if (!kReleaseMode) {
                  print('Branch data is not a Map: ${branchData.runtimeType}');
                }
                continue;
              }
              
              if (!kReleaseMode) {
                print('Processing branch: ${branchData['name'] ?? 'No name'}');
              }
              
              // Add company information to branch data for context
              final enrichedBranchData = Map<String, dynamic>.from(branchData);
              enrichedBranchData['company'] = company;
              
              final branch = company_model.Branch.fromJson(enrichedBranchData);
              allBranches.add(branch);
              
              if (!kReleaseMode) {
                print('Successfully parsed branch: ${branch.name}');
              }
            } catch (e) {
              if (!kReleaseMode) {
                print('Error parsing branch: $e');
                print('Branch data: $branchData');
              }
            }
          }
        }
      }
      
      if (!kReleaseMode) {
        print('Total branches loaded: ${allBranches.length}');
      }

      // Show all branches regardless of distance
      List<company_model.Branch> nearbyBranches = [];
      
      // Use all branches
      nearbyBranches = allBranches;
      
      // Sort branches by distance if user location is available (closest first)
      if (_currentUserLocation != null) {
        nearbyBranches.sort((a, b) {
          final distanceA = _calculateDistance(
            _currentUserLocation!.latitude,
            _currentUserLocation!.longitude,
            a.location.lat,
            a.location.lng,
          );
          
          final distanceB = _calculateDistance(
            _currentUserLocation!.latitude,
            _currentUserLocation!.longitude,
            b.location.lat,
            b.location.lng,
          );
          
          return distanceA.compareTo(distanceB);
        });
      }

      setState(() {
        _branches = nearbyBranches;
        _isLoading = false;
        if (nearbyBranches.isEmpty) {
          _errorMessage = 'No branches found nearby';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No branches found';
      });
    }
  }

  // Updated video initialization and display logic
  Future<void> _initializeVideo(String videoUrl) async {
    // Dispose of the previous controller if it exists
    await _videoController?.dispose();

    try {
      // Verify video URL accessibility
      try {
        final response = await http.head(Uri.parse(videoUrl));
        print('Video URL Head Request Status: ${response.statusCode}');
        print('Content-Type: ${response.headers['content-type']}');

        // Check if the video is actually accessible
        if (response.statusCode != 200) {
          print('Error: Video URL is not accessible. Status code: ${response.statusCode}');
          setState(() {
            _isVideoPlaying = false;
          });
          return;
        }
      } catch (headError) {
        print('Error checking video URL accessibility: $headError');
        setState(() {
          _isVideoPlaying = false;
        });
        return;
      }

      // Create a new controller with full URL
      _videoController = VideoPlayerController.network(videoUrl);

      // Add more detailed listeners
      _videoController!.addListener(() {
        if (_videoController!.value.hasError) {
          print('Video Player Error Details:');
          print('Error Description: ${_videoController!.value.errorDescription}');
          print('Is Initialized: ${_videoController!.value.isInitialized}');
          print('Duration: ${_videoController!.value.duration}');

          setState(() {
            _isVideoPlaying = false;
          });
        }
      });

      // Initialize the video with timeout
      await _videoController!.initialize().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('Video initialization timed out');
            throw TimeoutException('Video initialization took too long');
          }
      );

      // Verify video properties after initialization
      print('Video Properties:');
      print('Duration: ${_videoController!.value.duration}');
      print('Aspect Ratio: ${_videoController!.value.aspectRatio}');
      print('Size: ${_videoController!.value.size}');

      // Update state and start playing
      setState(() {
        _isVideoPlaying = true;
      });
      _videoController!.play();

      // Add completion listener
      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration) {
          setState(() {
            _isVideoPlaying = false;
          });
        }
      });
    } catch (e) {
      print('Comprehensive error initializing video:');
      print('Error Type: ${e.runtimeType}');
      print('Error Details: $e');

      setState(() {
        _isVideoPlaying = false;
      });
    }
  }

  void _stopVideo() {
    _videoController?.pause();
    _videoController?.dispose();
    setState(() {
      _isVideoPlaying = false;
      _videoController = null;
    });
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading branches...'),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An unknown error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBranches,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(company_model.Branch branch, LatLng? userLocation) {
    // Construct full URLs with proper error handling
    String? imagePath;
    String? videoPath;

    try {
      // Image URL construction
      imagePath = branch.images.isNotEmpty
          ? '${ApiConstants.baseUrl}/${branch.images.first}'
          : null;

      // Video URL construction
      videoPath = branch.videos != null && branch.videos!.isNotEmpty
          ? '${ApiConstants.baseUrl}/${branch.videos!.first}'
          : null;
    } catch (e) {
      print('Error constructing media URLs: $e');
    }

    // Calculate distance if user location is available
    String distanceText = 'Distance not available';
    if (userLocation != null) {
      final branchLocation = LatLng(
        branch.location.lat,
        branch.location.lng,
      );
      final distance = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        branchLocation.latitude,
        branchLocation.longitude,
      );
      distanceText = '${distance.toStringAsFixed(1)} km away';
    }

    return GestureDetector(
      onTap: widget.onLocationCardTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media section with improved handling
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Prioritize video thumbnail or image
                    if (videoPath != null)
                      _buildMediaThumbnail(
                        mediaUrl: videoPath,
                        isVideo: true,
                        fallbackImageUrl: imagePath,
                      )
                    else if (imagePath != null)
                      _buildMediaThumbnail(
                        mediaUrl: imagePath,
                        isVideo: false,
                      )
                    else
                      _buildPlaceholderContainer(),

                    // Video play icon overlay
                    if (videoPath != null)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Rest of the card remains the same...
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch name and distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          branch.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Location and category
                  Text(
                    '${branch.location.city}, ${branch.location.street}',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  if (branch.category.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        branch.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
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
      ),
    );
  }

  Widget _buildMediaThumbnail({
    required String mediaUrl,
    bool isVideo = false,
    String? fallbackImageUrl,
  }) {
    return SecureNetworkImage(
      imageUrl: mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 120,
      errorWidget: (context, url, error) {
        print('Error loading ${isVideo ? 'video' : 'image'} thumbnail: $error');
        if (fallbackImageUrl != null) {
          return SecureNetworkImage(
            imageUrl: fallbackImageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 120,
            errorWidget: (context, url, error) {
              print('Error loading fallback image: $error');
              return _buildPlaceholderContainer();
            },
          );
        }
        return _buildPlaceholderContainer();
      },
      placeholder: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // Helper method to build placeholder container
  Widget _buildPlaceholderContainer() {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 40, color: Colors.grey[600]),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  // Helper function to calculate distance between two coordinates
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 16,
                  right: 24,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.notifications,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  top: 21,
                  child: CustomPaint(
                    painter: BorderPainter(Colors.blue, 3.0),
                    child: Container(),
                  ),
                ),
                ClipPath(
                  clipper: TopArcWithSemicircleClipper(),
                  child: Container(
                    margin: EdgeInsets.only(top: 23),
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Removed tab selection
                        Expanded(
                          child: ListView(
                            controller: controller,
                            padding: EdgeInsets.only(top: 16),
                            children: [
                              // Top Listed section
                              _buildTopListedSection(),
                              
                              // Divider between Top Listed and regular content
                              if (_sponsoredCompanies.isNotEmpty || 
                                  _sponsoredWholesalers.isNotEmpty || 
                                  _sponsoredServiceProviders.isNotEmpty ||
                                  _sponsoredBranches.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Divider(
                                    color: Colors.grey[300],
                                    thickness: 1,
                                  ),
                                ),
                              
                              // Active Branches section
                              _buildActiveBranchesSection(),
                              
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _isLoading
                                      ? 'Loading...'
                                      : _errorMessage != null
                                          ? ''
                                          : (_companies.isNotEmpty
                                              ? 'All Companies (${_companies.length})'
                                              : (_branches.isNotEmpty
                                                  ? 'All Branches (${_branches.length})'
                                                  : '')),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (_isLoading)
                                _buildLoadingIndicator()
                              // else if (_errorMessage != null)
                              //   Padding(
                              //     padding: const EdgeInsets.all(32.0),
                              //     child: Center(
                              //       child: Text(
                              //         'No companies found',
                              //         style: TextStyle(
                              //           color: Colors.black,
                              //           fontSize: 18,
                              //           fontWeight: FontWeight.normal,
                              //         ),
                              //         textAlign: TextAlign.center,
                              //       ),
                              //     ),
                              //   )
                              else if (_companies.isNotEmpty)
                                _buildCompaniesList()
                              else if (_branches.isNotEmpty)
                                _buildBranchesList()
                              else
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      '',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompaniesList() {
    if (_companies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No companies found.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var company in _companies) ...[
            _buildCompanyCard(company, _currentUserLocation),
            SizedBox(width: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildBranchesList() {
    if (_branches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No branches found.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var branch in _branches) ...[
            _buildLocationCard(branch, _currentUserLocation),
            SizedBox(width: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyCard(Map<String, dynamic> company, LatLng? userLocation) {
    final companyInfo = company['companyInfo'];
    final location = company['location'];
    final logoUrl = companyInfo?['logo'];

    // Calculate distance if user location is available
    String distanceText = 'Distance not available';
    if (userLocation != null && location != null) {
      final companyLocation = LatLng(
        location['lat'].toDouble(),
        location['lng'].toDouble(),
      );
      final distance = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        companyLocation.latitude,
        companyLocation.longitude,
      );
      distanceText = '${distance.toStringAsFixed(1)} km away';
    }

    return GestureDetector(
      onTap: widget.onLocationCardTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company logo section
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (logoUrl != null && logoUrl.isNotEmpty)
                      SecureNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorWidget: (context, url, error) {
                          return _buildCompanyPlaceholder();
                        },
                        placeholder: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _buildCompanyPlaceholder(),
                    // Company indicator
                    Positioned(
                      top: 8,
                      right: 8,
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company name and distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          companyInfo?['name'] ?? 'Unknown Company',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Location
                  if (location != null)
                    Text(
                      '${location['city'] ?? ''}, ${location['street'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 4),
                  // Category
                  if (companyInfo?['category'] != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        companyInfo!['category'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
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
      ),
    );
  }

  Widget _buildCompanyPlaceholder() {
    return Container(
      color: Colors.blue.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 40, color: Colors.blue),
            SizedBox(height: 8),
            Text(
              'Company',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Active Branches section
  Widget _buildActiveBranchesSection() {
    final totalActiveBranches = _activeBranches.length + _activeWholesalerBranches.length;
    
    // Debug logging
    print('CollapsedSheet - Active branches: ${_activeBranches.length}');
    print('CollapsedSheet - Active wholesaler branches: ${_activeWholesalerBranches.length}');
    print('CollapsedSheet - Total active branches: $totalActiveBranches');
    
    if (totalActiveBranches == 0) {
      return SizedBox.shrink(); // Don't show section if no active branches
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Branches title
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Active Branches (${totalActiveBranches})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        
        // Company Branches
        if (_activeBranches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Company Branches (${_activeBranches.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var branch in _activeBranches) ...[
                  _buildActiveBranchCard(branch, _currentUserLocation, 'company'),
                  SizedBox(width: 16),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        
        // Wholesaler Branches
        if (_activeWholesalerBranches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Wholesaler Branches (${_activeWholesalerBranches.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var branch in _activeWholesalerBranches) ...[
                  _buildActiveBranchCard(branch, _currentUserLocation, 'wholesaler'),
                  SizedBox(width: 16),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
      ],
    );
  }

  // Build Top Listed section
  Widget _buildTopListedSection() {
    if (_isLoadingSponsored) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                           _sponsoredBranches.length; // Add this line

    if (totalSponsored == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No sponsored entities found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Listed title
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                'Top Listed (${totalSponsored})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
        ),
        
        // Sponsored Companies
        if (_sponsoredCompanies.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Sponsored Companies',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var company in _sponsoredCompanies) ...[
                  _buildSponsoredCompanyCard(company, _currentUserLocation),
                  SizedBox(width: 16),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],

        // Sponsored Wholesalers
        if (_sponsoredWholesalers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Sponsored Wholesalers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var wholesaler in _sponsoredWholesalers) ...[
                  _buildSponsoredWholesalerCard(wholesaler, _currentUserLocation),
                  SizedBox(width: 16),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],

        // Sponsored Service Providers
        if (_sponsoredServiceProviders.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Sponsored Service Providers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.purple[700],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var provider in _sponsoredServiceProviders) ...[
                  _buildSponsoredServiceProviderCard(provider, _currentUserLocation),
                  SizedBox(width: 16),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],

        // Sponsored Branches
        if (_sponsoredBranches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Sponsored Wholesalers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var branch in _sponsoredBranches) ...[
                  _buildSponsoredBranchCard(branch, _currentUserLocation),
                  SizedBox(width: 16),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
      ],
    );
  }

  // Build sponsored company card
  Widget _buildSponsoredCompanyCard(Map<String, dynamic> company, LatLng? userLocation) {
    final companyInfo = company['companyInfo'];
    final location = company['location'];
    final logoUrl = companyInfo?['logo'];
    
    // For company branches, try to get the branch logo first
    String? displayLogoUrl = logoUrl;
    if (company['type'] == 'company_branch' && company['images'] != null && company['images'].isNotEmpty) {
      // Use the first branch image if available
      final firstImage = company['images'].first;
      if (firstImage != null && firstImage.toString().isNotEmpty) {
        if (firstImage.toString().startsWith('http')) {
          displayLogoUrl = firstImage.toString();
        } else {
          displayLogoUrl = '${ApiConstants.baseUrl}/$firstImage';
        }
      }
    }
    
    // Calculate distance if user location is available
    String distanceText = 'Distance not available';
    if (userLocation != null && location != null) {
      final companyLocation = LatLng(
        location['lat'].toDouble(),
        location['lng'].toDouble(),
      );
      final distance = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        companyLocation.latitude,
        companyLocation.longitude,
      );
      distanceText = '${distance.toStringAsFixed(1)} km away';
    }

    return GestureDetector(
      onTap: () {
        if (widget.onPlaceTap != null) {
          // Close the sheet first
          if (widget.onCloseSheet != null) {
            widget.onCloseSheet!();
          }
          
          // Prepare place data for PlaceDetailsOverlay
          final placeData = {
            'name': company['type'] == 'company_branch' 
                ? (company['name'] ?? 'Unknown Branch')
                : (companyInfo?['name'] ?? 'Unknown Company'),
            '_id': company['id'] ?? company['_id'] ?? company['companyId'],
            'latitude': location?['lat']?.toDouble() ?? 0.0,
            'longitude': location?['lng']?.toDouble() ?? 0.0,
            'address': '${location?['street'] ?? ''}, ${location?['city'] ?? ''}',
            'phone': company['phone'] ?? '',
            'description': companyInfo?['description'] ?? '',
            'image': displayLogoUrl ?? 'assets/images/company_placeholder.png',
            'logoUrl': displayLogoUrl,
            'companyName': companyInfo?['name'] ?? 'Unknown Company',
            'companyId': company['companyId'] ?? company['_id'],
            'images': company['images'] ?? [],
            'type': company['type'] == 'company_branch' ? 'branch' : 'company',
            'category': companyInfo?['category'] ?? company['category'] ?? 'Unknown Category',
            'company': companyInfo,
            'status': 'active',
            // Include social media information from company data
            'socialMedia': {
              'instagram': companyInfo?['socialMedia']?['instagram'],
              'facebook': companyInfo?['socialMedia']?['facebook'],
            },
          };
          widget.onPlaceTap!(placeData);
        } else {
          widget.onLocationCardTap();
        }
      },
      child: Container(
        width: 200,
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
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (displayLogoUrl != null && displayLogoUrl.isNotEmpty)
                      SecureNetworkImage(
                        imageUrl: displayLogoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorWidget: (context, url, error) {
                          return _buildSponsoredCompanyPlaceholder();
                        },
                        placeholder: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _buildSponsoredCompanyPlaceholder(),
                    
                    // Sponsorship badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'SPONSORED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                  // Company/Branch name and distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          company['type'] == 'company_branch' 
                              ? (company['name'] ?? 'Unknown Branch')
                              : (companyInfo?['name'] ?? 'Unknown Company'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Location
                  if (location != null)
                    Text(
                      '${location['city'] ?? ''}, ${location['street'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 4),
                  // Category
                  if (companyInfo?['category'] != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        companyInfo!['category'],
                        style: TextStyle(
                          fontSize: 12,
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
      ),
    );
  }

  // Build sponsored wholesaler card
  Widget _buildSponsoredWholesalerCard(Map<String, dynamic> wholesaler, LatLng? userLocation) {
    // Get wholesaler logo or branch image
    String? displayLogoUrl = wholesaler['logoUrl'];
    String? displayName = wholesaler['businessName'];
    
    // If wholesaler has branches with images, use the first branch image and name
    if (wholesaler['branches'] != null && wholesaler['branches'] is List && wholesaler['branches'].isNotEmpty) {
      final branches = wholesaler['branches'] as List;
      for (var branch in branches) {
        if (branch['images'] != null && branch['images'] is List && branch['images'].isNotEmpty) {
          final firstImage = branch['images'].first;
          if (firstImage != null && firstImage.toString().isNotEmpty) {
            if (firstImage.toString().startsWith('http')) {
              displayLogoUrl = firstImage.toString();
            } else {
              displayLogoUrl = '${ApiConstants.baseUrl}/$firstImage';
            }
            // Also get the branch name if available
            if (branch['name'] != null && branch['name'].toString().isNotEmpty) {
              displayName = branch['name'].toString();
            }
            break; // Use the first branch with images
          }
        }
      }
    }
    
    // Calculate distance if user location is available
    String distanceText = 'Distance not available';
    if (userLocation != null && wholesaler['address'] != null) {
      final address = wholesaler['address'] as wholesaler_model.Address;
      final distance = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        address.lat,
        address.lng,
      );
      distanceText = '${distance.toStringAsFixed(1)} km away';
    }

    return GestureDetector(
      onTap: () {
        if (widget.onPlaceTap != null) {
          // Close the sheet first
          if (widget.onCloseSheet != null) {
            widget.onCloseSheet!();
          }
          
          // Prepare place data for PlaceDetailsOverlay
          final placeData = {
            'name': displayName ?? 'Unknown Wholesaler',
            '_id': wholesaler['id'],
            'latitude': wholesaler['address'] != null ? (wholesaler['address'] as wholesaler_model.Address).lat : 0.0,
            'longitude': wholesaler['address'] != null ? (wholesaler['address'] as wholesaler_model.Address).lng : 0.0,
            'address': wholesaler['address'] != null ? '${(wholesaler['address'] as wholesaler_model.Address).city}, ${(wholesaler['address'] as wholesaler_model.Address).street}' : '',
            'phone': wholesaler['phone'] ?? '',
            'description': wholesaler['category'] ?? '',
            'image': displayLogoUrl ?? 'assets/images/company_placeholder.png',
            'logoUrl': displayLogoUrl,
            'companyName': wholesaler['businessName'] ?? 'Unknown Wholesaler',
            'companyId': wholesaler['id'],
            'images': wholesaler['branches'] != null && wholesaler['branches'].isNotEmpty 
                ? wholesaler['branches'].first['images'] ?? []
                : [],
            'type': 'Wholesaler',
            'category': wholesaler['category'] ?? 'Unknown Category',
            'company': {
              'businessName': wholesaler['businessName'],
              'logoUrl': wholesaler['logoUrl'],
              'id': wholesaler['id'],
            },
            'status': 'active',
            'branches': wholesaler['branches'] ?? [],
            // Include social media information from wholesaler data
            'socialMedia': {
              'instagram': wholesaler['socialMedia']?['instagram'],
              'facebook': wholesaler['socialMedia']?['facebook'],
            },
          };
          widget.onPlaceTap!(placeData);
        } else {
          widget.onLocationCardTap();
        }
      },
      child: Container(
        width: 200,
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
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (displayLogoUrl != null && displayLogoUrl.isNotEmpty)
                      SecureNetworkImage(
                        imageUrl: displayLogoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorWidget: (context, url, error) {
                          return _buildSponsoredWholesalerPlaceholder();
                        },
                        placeholder: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _buildSponsoredWholesalerPlaceholder(),
                    
                    // Sponsorship badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'SPONSORED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                  // Business/Branch name and distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName ?? 'Unknown Wholesaler',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Location
                  if (wholesaler['address'] != null)
                    Text(
                      '${(wholesaler['address'] as wholesaler_model.Address).city}, ${(wholesaler['address'] as wholesaler_model.Address).street}',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 4),
                  // Category
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      wholesaler['category'] ?? 'Unknown Category',
                      style: TextStyle(
                        fontSize: 12,
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
      ),
    );
  }

  // Build sponsored service provider card
  Widget _buildSponsoredServiceProviderCard(Map<String, dynamic> provider, LatLng? userLocation) {
    return GestureDetector(
      onTap: widget.onLocationCardTap,
      child: Container(
        width: 200,
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
                height: 120,
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
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'SPONSORED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  // Category
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Professional Services',
                      style: TextStyle(
                        fontSize: 12,
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
      ),
    );
  }

  // Build active branch card
  Widget _buildActiveBranchCard(Map<String, dynamic> branch, LatLng? userLocation, String type) {
    // Get branch logo/image
    String? branchLogoUrl;
    String branchName = branch['name'] ?? 'Unknown Branch';
    String companyName = branch['companyName'] ?? branch['company']?['businessName'] ?? 'Unknown Company';
    
    // Try to get logo from different sources
    if (branch['logoUrl'] != null && branch['logoUrl'].toString().isNotEmpty) {
      branchLogoUrl = branch['logoUrl'];
    } else if (branch['company'] != null && branch['company']['logoUrl'] != null && branch['company']['logoUrl'].toString().isNotEmpty) {
      branchLogoUrl = branch['company']['logoUrl'];
    } else if (branch['images'] != null && branch['images'] is List && branch['images'].isNotEmpty) {
      final firstImage = branch['images'].first;
      if (firstImage != null && firstImage.toString().isNotEmpty) {
        if (firstImage.toString().startsWith('http')) {
          branchLogoUrl = firstImage.toString();
        } else {
          branchLogoUrl = '${ApiConstants.baseUrl}/$firstImage';
        }
      }
    }
    
    // Calculate distance if user location is available
    String distanceText = 'Distance not available';
    if (userLocation != null && branch['latitude'] != null && branch['longitude'] != null) {
      final branchLocation = LatLng(
        branch['latitude'].toDouble(),
        branch['longitude'].toDouble(),
      );
      final distance = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        branchLocation.latitude,
        branchLocation.longitude,
      );
      distanceText = '${distance.toStringAsFixed(1)} km away';
    }

    // Determine card color based on type
    Color cardColor = type == 'wholesaler' ? Colors.orange : Colors.blue;
    Color borderColor = type == 'wholesaler' ? Colors.orange : Colors.blue;

    return GestureDetector(
      onTap: () {
        if (widget.onPlaceTap != null) {
          // Close the sheet first
          if (widget.onCloseSheet != null) {
            widget.onCloseSheet!();
          }
          
          // Prepare place data for PlaceDetailsOverlay
          final placeData = {
            'name': branchName,
            '_id': branch['id'] ?? branch['_id'],
            'latitude': branch['latitude'] ?? 0.0,
            'longitude': branch['longitude'] ?? 0.0,
            'address': branch['address'] ?? '',
            'phone': branch['phone'] ?? '',
            'description': branch['description'] ?? '',
            'image': branchLogoUrl ?? 'assets/images/company_placeholder.png',
            'logoUrl': branchLogoUrl,
            'companyName': companyName,
            'companyId': branch['companyId'] ?? branch['company']?['id'],
            'images': branch['images'] ?? [],
            'type': type == 'wholesaler' ? 'Wholesaler Branch' : 'Branch',
            'category': branch['category'] ?? 'Unknown Category',
            'company': branch['company'] ?? {},
            'status': 'active',
            'socialMedia': branch['socialMedia'] ?? {},
          };
          widget.onPlaceTap!(placeData);
        } else {
          widget.onLocationCardTap();
        }
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branch logo section
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (branchLogoUrl != null && branchLogoUrl.isNotEmpty)
                      SecureNetworkImage(
                        imageUrl: branchLogoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorWidget: (context, url, error) {
                          return _buildActiveBranchPlaceholder(type);
                        },
                        placeholder: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _buildActiveBranchPlaceholder(type),
                    
                    // Active badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Type indicator
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            color: cardColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
                  // Branch name and distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          branchName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Company name
                  Text(
                    companyName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  // Category
                  if (branch['category'] != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        branch['category'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: cardColor,
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
      ),
    );
  }

  // Build sponsored branch card
  Widget _buildSponsoredBranchCard(Map<String, dynamic> branch, LatLng? userLocation) {
    // Get branch logo/image
    String? branchLogoUrl;
    if (branch['images'] != null && branch['images'].isNotEmpty) {
      final firstImage = branch['images'].first;
      if (firstImage != null && firstImage.toString().isNotEmpty) {
        if (firstImage.toString().startsWith('http')) {
          branchLogoUrl = firstImage.toString();
        } else {
          branchLogoUrl = '${ApiConstants.baseUrl}/$firstImage';
        }
      }
    }
    
    // Calculate distance if user location is available
    String distanceText = 'Distance not available';
    if (userLocation != null && branch['location'] != null) {
      final branchLocation = LatLng(
        branch['location']['lat'].toDouble(),
        branch['location']['lng'].toDouble(),
      );
      final distance = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        branchLocation.latitude,
        branchLocation.longitude,
      );
      distanceText = '${distance.toStringAsFixed(1)} km away';
    }

    return GestureDetector(
      onTap: () {
        if (widget.onPlaceTap != null) {
          // Close the sheet first
          if (widget.onCloseSheet != null) {
            widget.onCloseSheet!();
          }
          
          // Prepare place data for PlaceDetailsOverlay
          final placeData = {
            'name': branch['name'] ?? 'Unknown Branch',
            '_id': branch['id'],
            'latitude': branch['location'] != null ? branch['location']['lat'].toDouble() : 0.0,
            'longitude': branch['location'] != null ? branch['location']['lng'].toDouble() : 0.0,
            'address': branch['location'] != null ? '${branch['location']['street'] ?? ''}, ${branch['location']['city'] ?? ''}' : '',
            'phone': branch['phone'] ?? '',
            'description': branch['description'] ?? '',
            'image': branchLogoUrl ?? 'assets/images/company_placeholder.png',
            'logoUrl': branchLogoUrl,
            'companyName': branch['wholesalerName'] ?? 'Unknown Wholesaler',
            'companyId': branch['wholesalerId'],
            'images': branch['images'] ?? [],
            'type': 'Wholesaler Branch',
            'category': branch['category'] ?? 'Unknown Category',
            'company': {
              'businessName': branch['wholesalerName'],
              'id': branch['wholesalerId'],
            },
            'status': 'active',
            // Include social media information from branch's wholesaler data
            'socialMedia': {
              'instagram': branch['wholesalerSocialMedia']?['instagram'],
              'facebook': branch['wholesalerSocialMedia']?['facebook'],
            },
          };
          widget.onPlaceTap!(placeData);
        } else {
          widget.onLocationCardTap();
        }
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branch logo section with sponsorship badge
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (branchLogoUrl != null && branchLogoUrl.isNotEmpty)
                      SecureNetworkImage(
                        imageUrl: branchLogoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorWidget: (context, url, error) {
                          return _buildSponsoredBranchPlaceholder();
                        },
                        placeholder: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _buildSponsoredBranchPlaceholder(),
                    
                    // Sponsorship badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'SPONSORED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                  // Branch name and distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          branch['name'] ?? 'Unknown Branch',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Location
                  if (branch['location'] != null)
                    Text(
                      '${(branch['location'] as Map<String, dynamic>)['city'] ?? ''}, ${(branch['location'] as Map<String, dynamic>)['street'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 4),
                  // Category
                  if (branch['category'] != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        branch['category'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
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
            Icon(Icons.business, size: 40, color: Colors.amber),
            SizedBox(height: 8),
            Text(
              'Company',
              style: TextStyle(
                color: Colors.amber[700],
                fontWeight: FontWeight.bold,
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
            Icon(Icons.inventory, size: 40, color: Colors.green),
            SizedBox(height: 8),
            Text(
              'Wholesaler',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
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
            Icon(Icons.star, size: 40, color: Colors.purple),
            SizedBox(height: 8),
            Text(
              'Sponsored Service Provider',
              style: TextStyle(
                color: Colors.purple[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsoredBranchPlaceholder() {
    return Container(
      color: Colors.orange.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 40, color: Colors.orange),
            SizedBox(height: 8),
            Text(
              'Branch',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBranchPlaceholder(String type) {
    Color color = type == 'wholesaler' ? Colors.orange : Colors.blue;
    IconData icon = type == 'wholesaler' ? Icons.store : Icons.business;
    String label = type == 'wholesaler' ? 'Wholesaler Branch' : 'Company Branch';
    
    return Container(
      color: color.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BorderPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;

  BorderPainter(this.borderColor, this.borderWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final circleRadius = 45.0;

    path.moveTo(0, 0);
    path.lineTo((size.width / 1.94) - circleRadius, 0);

    path.arcToPoint(
      Offset((size.width / 2.06) + circleRadius, 0),
      radius: Radius.circular(circleRadius),
      clockwise: false,
    );

    path.lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TopArcWithSemicircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final circleRadius = 45.0;

    path.lineTo(0, 0);
    path.lineTo((size.width / 2) - circleRadius, 0);

    path.arcToPoint(
      Offset((size.width / 2) + circleRadius, 0),
      radius: Radius.circular(circleRadius),
      clockwise: false,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);

    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}