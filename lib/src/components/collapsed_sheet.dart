import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import '../services/api_service.dart';
import '../utils/api_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class CollapsedSheet extends StatefulWidget {
  final ScrollController? controller;
  final VoidCallback onLocationCardTap;

  const CollapsedSheet({
    Key? key,
    required this.controller,
    required this.onLocationCardTap,
  }) : super(key: key);

  @override
  State<CollapsedSheet> createState() => _CollapsedSheetState();
}

class _CollapsedSheetState extends State<CollapsedSheet> {
  final CompanyService _companyService = CompanyService();
  List<Branch> _branches = [];
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = true;
  String? _errorMessage;
  LatLng? _currentUserLocation;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  String _selectedTab = 'companies'; // Add tab selection

  @override
  void initState() {
    super.initState();
    _loadData();
    _getUserLocation();
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

      // Load both companies and branches in parallel
      await Future.wait([
        _loadCompanies(),
        _loadBranches(),
      ]);

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

  Future<void> _loadCompanies() async {
    try {
      final companies = await ApiService.getCompaniesWithLocations();
      
      // Filter out companies with status 'pending' or 'rejected'
      final filteredCompanies = companies.where((company) {
        final status = company['status'] ?? company['companyInfo']?['status'];
        return status == 'approved';
      }).toList();
      
      setState(() {
        _companies = List<Map<String, dynamic>>.from(filteredCompanies);
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

      final branchesData = await _companyService.getAllBranches();

      // Filter out branches whose companies have 'pending' or 'rejected' status
      final filteredBranchesData = branchesData.where((branchData) {
        final company = branchData['company'];
        if (company == null) return false;
        // Check company status - can be in different fields
        final status = company['status'] ?? company['companyInfo']?['status'];
        if (status != 'approved') return false;
        if (branchData['status'] == 'inactive') return false;
        return true;
      }).toList();

      // Convert the filtered data to Branch objects
      final branches = filteredBranchesData.map((data) {
        return Branch.fromJson(data);
      }).toList();

      setState(() {
        _branches = branches;
        _isLoading = false;
        if (branches.isEmpty) {
          _errorMessage = 'No branches found';
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

  Widget _buildLocationCard(Branch branch, LatLng? userLocation) {
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
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _isLoading
                                      ? 'Loading...'
                                      : _errorMessage != null
                                          ? ''
                                          : (_companies.isNotEmpty
                                              ? 'Companies Near You'
                                              : (_branches.isNotEmpty
                                                  ? 'Branches Near You'
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
                              else if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Center(
                                    child: Text(
                                      'No companies found',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              else if (_companies.isNotEmpty)
                                _buildCompaniesList()
                              else if (_branches.isNotEmpty)
                                _buildBranchesList()
                              else
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No companies or branches found nearby.',
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
            'No companies found nearby.',
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
            'No branches found nearby.',
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