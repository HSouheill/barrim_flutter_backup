import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:share_plus/share_plus.dart';
import '../features/authentication/screens/category/branch_details.dart';
import '../services/api_service.dart';
import '../services/company_service.dart';
import '../services/wholesaler_service.dart';
import 'package:flutter/foundation.dart';

class PlaceDetailsOverlay extends StatefulWidget {
  final Map<String, dynamic> place;
  final VoidCallback onClose;
  final Function(LatLng) onNavigate;
  final Function(LatLng, String)? onBranchSelect;
  final String? token;
  final double? duration;

  const PlaceDetailsOverlay({
    Key? key,
    required this.place,
    required this.onClose,
    required this.onNavigate,
    this.onBranchSelect,
    this.token,
    this.duration,
  }) : super(key: key);

  @override
  State<PlaceDetailsOverlay> createState() => _PlaceDetailsOverlayState();
}

class _PlaceDetailsOverlayState extends State<PlaceDetailsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  final double _dismissThreshold = 100.0;
  int _selectedBranchIndex = 0;
  bool _isLoadingBranches = false;
  List<dynamic> _branches = [];
  bool _isFavorite = false;
  bool _isProcessingFavorite = false;
  Map<String, dynamic>? _branchDetails;
  Map<String, dynamic>? _companyData;
  Map<String, dynamic>? _wholesalerData;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Load branches data if there are none provided
    if (widget.place['branches'] != null && widget.place['branches'].isNotEmpty) {
      _branches = widget.place['branches'];
    }

    // Otherwise fetch them from the API if we have a token
    else {
      _fetchBranchData();
    }
    // Check if the current branch is already in favorites
    _checkFavoriteStatus();
    // Fetch branch details for cost per customer
    _fetchBranchDetails();
    // Fetch company data
    _fetchCompanyData();
    // Fetch wholesaler data
    _fetchWholesalerData();
  }

  Future<void> _checkFavoriteStatus() async {
    if (widget.token == null) return;

    try {
      String branchId = '';

      // Get the current branch ID
      if (_branches.isNotEmpty) {
        final currentBranch = _branches[_selectedBranchIndex];
        branchId = currentBranch['_id'] ?? currentBranch['id'] ?? '';
      } else if (widget.place['_id'] != null) {
        branchId = widget.place['_id'];
      }

      if (branchId.isNotEmpty) {
        final isFavorite = await ApiService.isBranchFavorite(branchId, widget.token!);
        if (mounted) {
          setState(() {
            _isFavorite = isFavorite;
          });
        }
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error checking favorite status: $e');
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.token == null) {
      // Show login prompt if not authenticated
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to save favorites'),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () {
              // Navigate to login page
              Navigator.of(context).pushNamed('/login');
            },
          ),
        ),
      );
      return;
    }

    if (_isProcessingFavorite) return;

    setState(() {
      _isProcessingFavorite = true;
    });

    try {
      String branchId = '';

      // Get the current branch ID
      if (_branches.isNotEmpty) {
        final currentBranch = _branches[_selectedBranchIndex];
        branchId = currentBranch['_id'] ?? currentBranch['id'] ?? '';
      } else if (widget.place['_id'] != null) {
        branchId = widget.place['_id'];
      }

      if (branchId.isEmpty) {
        throw Exception('Branch ID not found');
      }

      Map<String, dynamic> result;
      if (_isFavorite) {
        result = await ApiService.removeFromFavorites(branchId, widget.token!);
      } else {
        result = await ApiService.addToFavorites(branchId, widget.token!);
      }

      // if (result['success']) {
      //   setState(() {
      //     _isFavorite = !_isFavorite;
      //   });

      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text(result['message']),
      //       duration: Duration(seconds: 2),
      //     ),
      //   );
      // } else {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text(result['message']),
      //       duration: Duration(seconds: 3),
      //     ),
      //   );
      // }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error toggling favorite: $e');
      }
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to update favorites. Please try again.'),
      //     duration: Duration(seconds: 3),
      //   ),
      // );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFavorite = false;
        });
      }
    }
  }

  Future<void> _fetchBranchData() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      // Fetch all branches
      final allBranchesData = await ApiService.getAllBranches();
      if (!kReleaseMode) {
        print('All branches data: $allBranchesData');
      }

      // Filter branches for the current place (company)
      final String placeId = widget.place['id'];
      final List<Map<String, dynamic>> filteredBranches = allBranchesData
          .where((branch) =>
      branch['company'] != null &&
          branch['company']['id'] == placeId)
          .toList();
      
      if (!kReleaseMode) {
        print('Filtered branches for place $placeId: $filteredBranches');
      }

      // Process branch data to ensure it has all required fields
      final processedBranches = filteredBranches.map((branch) {
        if (!kReleaseMode) {
          print('Processing branch: ${branch['name']}');
        }
        if (!kReleaseMode) {
          print('Original costPerCustomer: ${branch['costPerCustomer']}');
        }
        
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

        // Prepare the location data - convert from Address to a latitude/longitude
        final location = branch['location'];
        double latitude = 0.0;
        double longitude = 0.0;
        String formattedAddress = '';

        if (location != null) {
          latitude = location['lat'] is double ? location['lat'] : 0.0;
          longitude = location['lng'] is double ? location['lng'] : 0.0;
          formattedAddress = '${location['street'] ?? ''}, ${location['city'] ?? ''}, ${location['district'] ?? ''}';
          formattedAddress = formattedAddress.replaceAll(RegExp(r', $'), '');
        }

        final processedBranch = {
          ...branch,
          'name': branch['name'] ?? 'Unnamed Branch',
          'description': branch['description'] ?? 'No description available',
          'location': formattedAddress,
          'images': processedImages,
          'latitude': latitude,
          'longitude': longitude,
          'costPerCustomer': branch['costPerCustomer'] ?? 0.0,
        };
        
        if (!kReleaseMode) {
          print('Processed branch data: $processedBranch');
        }
        return processedBranch;
      }).toList();

      if (!kReleaseMode) {
        print('Final processed branches: $processedBranches');
      }

      setState(() {
        _branches = processedBranches;
        _isLoadingBranches = false;
      });
    } catch (e) {
      if (!kReleaseMode) {
        print('Error fetching branch data: $e');
      }
      setState(() {
        _branches = []; // Set to empty list on error
        _isLoadingBranches = false;
      });
    }
  }

  Future<void> _fetchBranchDetails() async {
    if (_branches.isNotEmpty) {
      final currentBranch = _branches[_selectedBranchIndex];
      final branchId = currentBranch['_id'] ?? currentBranch['id'];
      if (branchId != null) {
        try {
          final branchDetails = await CompanyService().getBranchById(branchId);
          setState(() {
            _branchDetails = branchDetails;
            // Update the current branch with costPerCustomer
            if (branchDetails['costPerCustomer'] != null) {
              _branches[_selectedBranchIndex]['costPerCustomer'] = branchDetails['costPerCustomer'];
            }
          });
        } catch (e) {
          if (!kReleaseMode) {
            print('Error fetching branch details: $e');
          }
        }
      }
    }
  }

  Future<void> _fetchCompanyData() async {
    if (widget.token != null) {
      try {
        final companyData = await ApiService.getCompanyData(widget.token!);
        setState(() {
          _companyData = companyData;
        });
      } catch (e) {
        if (!kReleaseMode) {
          print('Error fetching company data: $e');
        }
      }
    }
  }

  Future<void> _fetchWholesalerData() async {
    try {
      final wholesalerService = WholesalerService();
      final wholesaler = await wholesalerService.getWholesalerData();
      if (mounted && wholesaler != null) {
        setState(() {
          _wholesalerData = {
            'socialMedia': {
              'instagram': wholesaler.socialMedia.instagram,
              'facebook': wholesaler.socialMedia.facebook,
            },
            'contactInfo': {
              'whatsapp': wholesaler.contactInfo.whatsApp,
              'website': wholesaler.contactInfo.website,
            }
          };
        });
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error fetching wholesaler data: $e');
      }
    }
  }

  String _getCostPerCustomer() {
    if (_branches.isNotEmpty) {
      final currentBranch = _branches[_selectedBranchIndex];
      if (!kReleaseMode) {
        print('Current branch for cost: $currentBranch');
      }
      if (!kReleaseMode) {
        print('Cost per customer: ${currentBranch['costPerCustomer']}');
      }
      final cost = currentBranch['costPerCustomer'];
      if (cost != null) {
        return cost.toStringAsFixed(0);
      }
    }
    return '0';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta! > 0) {
      setState(() {
        _dragOffset += details.primaryDelta!;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset > _dismissThreshold) {
      _controller.animateTo(1.0).then((_) => widget.onClose());
    } else {
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  void _navigateToReviews() {
    // Close the overlay first
    widget.onClose();

    // Get the current branch or use the place data if no branches
    final currentBranch = _branches.isNotEmpty
        ? _branches[_selectedBranchIndex]
        : widget.place;

    // Navigate to the BranchDetailsPage
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BranchDetailsPage(branch: currentBranch),
      ),
    );
  }

  void _showNavigationOptions(LatLng coordinates) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),

      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Navigate using",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.map, color: Theme.of(context).primaryColor),
                title: Text("In-app Navigation"),
                onTap: () {
                  Navigator.pop(context);
                  widget.onNavigate(coordinates);
                  widget.onClose();
                },
              ),
              ListTile(
                leading: Image.asset(
                  'assets/icons/google_maps.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (ctx, err, _) => Icon(Icons.map_outlined, color: Colors.green),
                ),
                title: Text("Google Maps"),
                onTap: () {
                  Navigator.pop(context);
                  _launchGoogleMaps(coordinates);
                },
              ),
              // Another option for Apple Maps on iOS
              if (Theme.of(context).platform == TargetPlatform.iOS)
                ListTile(
                  leading: Icon(Icons.map_outlined, color: Colors.blue),
                  title: Text("Apple Maps"),
                  onTap: () {
                    Navigator.pop(context);
                    _launchAppleMaps(coordinates);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchGoogleMaps(LatLng coordinates) async {
    final String mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${coordinates.latitude},${coordinates.longitude}&travelmode=driving';
    final String mapsAppUrl = 'comgooglemaps://?daddr=${coordinates.latitude},${coordinates.longitude}&directionsmode=driving';
    final String geoUrl = 'geo:${coordinates.latitude},${coordinates.longitude}?q=${coordinates.latitude},${coordinates.longitude}';

    try {
      // Try launching Google Maps app first
      if (await canLaunchUrlString(mapsAppUrl)) {
        await launchUrlString(mapsAppUrl);
        return;
      }

      // Fallback to geo intent
      if (await canLaunchUrlString(geoUrl)) {
        await launchUrlString(geoUrl);
        return;
      }

      // Final fallback to web URL
      await launchUrlString(mapsUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error launching maps: $e');
      }
      _showErrorSnackBar('Could not launch maps. Please install Google Maps.');
    }
  }

  Future<void> _launchAppleMaps(LatLng coordinates) async {
    final appleMapsUrl = 'https://maps.apple.com/?daddr=${coordinates.latitude},${coordinates.longitude}&dirflg=d';

    try {
      if (await canLaunchUrlString(appleMapsUrl)) {
        await launchUrlString(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Cannot open Apple Maps');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error launching Apple Maps: $e');
      }
      _showErrorSnackBar('Error opening Apple Maps');
    }
  }

  void _showErrorSnackBar(String message) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(message),
    //         duration: Duration(seconds: 3),
    //         action: SnackBarAction(
    //           label: 'OK',
    //           onPressed: () {
    //             ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //           },
    //         ),
    //       ),
    //     );
  }

  void _showPhoneOptions(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Contact via",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.phone, color: Colors.green),
                title: Text("Phone Call"),
                onTap: () async {
                  Navigator.pop(context);
                  final url = 'tel:$phoneNumber';
                  if (await canLaunchUrlString(url)) {
                    await launchUrlString(url);
                  } else {
                    _showErrorSnackBar('Could not launch phone call');
                  }
                },
              ),
              ListTile(
                leading: Image.asset(
                  'assets/icons/whatsapp.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (ctx, err, _) => Icon(Icons.message, color: Colors.green),
                ),
                title: Text("WhatsApp"),
                onTap: () async {
                  Navigator.pop(context);
                  final url = 'https://wa.me/$phoneNumber';
                  if (await canLaunchUrlString(url)) {
                    await launchUrlString(url);
                  } else {
                    _showErrorSnackBar('Could not launch WhatsApp');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareBranchDetails() {
    final branch = _branches.isNotEmpty ? _branches[_selectedBranchIndex] : widget.place;
    final name = branch['name'] ?? 'Unknown Place';
    final location = branch['location'] ?? branch['address'] ?? 'No address available';
    final description = branch['description'] ?? 'No description available';
    
    final shareText = '''
$name

$description

Location: $location

Check it out on our app!
''';

    Share.share(shareText);
  }

  Widget _buildGradientCircularIconButton(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF0094FF), Color(0xFF05055A), Color(0xFF0094FF)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  String _getDurationText() {
    if (widget.duration == null) return '';

    final duration = widget.duration!;
    if (duration < 1) {
      final seconds = (duration * 60).round();
      return '( ${seconds} sec )';
    } else if (duration < 60) {
      return '( ${duration.toStringAsFixed(0)} min )';
    } else {
      final hours = (duration / 60).floor();
      final minutes = (duration % 60).round();
      return '( ${hours}h ${minutes}m )';
    }
  }

  Widget _buildBranchImage(dynamic branch) {
    try {
      // Check if branch has images
      final images = branch['images'];
      if (images == null || (images is List && images.isEmpty)) {
        return Container(
          color: Colors.grey[200],
          child: Center(
            child: Icon(
              Icons.store,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
        );
      }

      // Handle the case where images is a List
      if (images is List && images.isNotEmpty) {
        final imagePath = images[0];
        if (imagePath == null || imagePath is! String) {
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.store,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
          );
        }

        if (!kReleaseMode) {
          print("Loading branch image from path: $imagePath");
        }

        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (!kReleaseMode) {
              print("Error loading branch image: $error");
            }
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 60,
                  color: Colors.grey[400],
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        );
      }

      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.store,
            size: 60,
            color: Colors.grey[400],
          ),
        ),
      );
    } catch (e) {
      if (!kReleaseMode) {
        print("Exception while building branch image: $e");
      }
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red[400],
          ),
        ),
      );
    }
  }

  String _getFirstImageUrl(Map<String, dynamic> place) {
    // Handle case where images is a list
    if (place['images'] != null) {
      if (place['images'] is List && (place['images'] as List).isNotEmpty) {
        final firstImage = place['images'][0];
        if (firstImage is String) {
          // Add base URL if the path is relative
          if (firstImage.startsWith('uploads/') || !firstImage.startsWith('http')) {
            return '${ApiService.baseUrl}/${firstImage}';
          }
          return firstImage;
        }
      } else if (place['images'] is String) {
        final imagePath = place['images'];
        // Add base URL if the path is relative
        if (imagePath.startsWith('uploads/') || !imagePath.startsWith('http')) {
          return '${ApiService.baseUrl}/${imagePath}';
        }
        return imagePath;
      }
    }

    // Fallback to image field if it exists
    if (place['image'] != null && place['image'] is String) {
      final imagePath = place['image'];
      // Add base URL if the path is relative
      if (imagePath.startsWith('uploads/') || !imagePath.startsWith('http')) {
        return '${ApiService.baseUrl}/${imagePath}';
      }
      return imagePath;
    }

    // Default empty string if no valid image found
    return '';
  }

  Future<void> _launchSocialMedia(String? url) async {
    if (url == null || url.isEmpty) {
      _showErrorSnackBar('Social media link not available');
      return;
    }

    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not launch social media link');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error launching social media: $e');
      }
      _showErrorSnackBar('Error opening social media link');
    }
  }

  void _launchInstagram() {
    final branch = _branches.isNotEmpty ? _branches[_selectedBranchIndex] : widget.place;
    final instagramUrl = branch['socialMedia']?['instagram'] ?? 
                        _companyData?['socialMedia']?['instagram'] ?? 
                        _wholesalerData?['socialMedia']?['instagram'];
    _launchSocialMedia(instagramUrl);
  }

  void _launchFacebook() {
    final branch = _branches.isNotEmpty ? _branches[_selectedBranchIndex] : widget.place;
    final facebookUrl = branch['socialMedia']?['facebook'] ?? 
                       _companyData?['socialMedia']?['facebook'] ?? 
                       _wholesalerData?['socialMedia']?['facebook'];
    _launchSocialMedia(facebookUrl);
  }

  @override
  Widget build(BuildContext context) {
    final branches = _branches.isNotEmpty ? _branches : (widget.place['branches'] ?? []);
    final hasBranches = branches.isNotEmpty;
    final currentBranch = hasBranches ? branches[_selectedBranchIndex] : null;

    return GestureDetector(
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 230,
                    child: currentBranch != null && currentBranch['images'] != null && currentBranch['images'].isNotEmpty
                        ? _buildBranchImage(currentBranch)
                        :Image.network(
                      _getFirstImageUrl(widget.place),
                      width: double.infinity,
                      height: 230,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        if (!kReleaseMode) {
                          print("Error loading place image: $error");
                        }
                        return Container(
                          color: Colors.grey[200],
                          width: double.infinity,
                          height: 230,
                          child: Icon(
                            Icons.image_not_supported,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                        child: Container(
                          width: 60,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 230,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.0),
                          ),
                          child: IconButton(
                            icon: Image.asset(
                              'assets/icons/instagram.png',
                              width: 34,
                              height: 34,
                            ),
                            onPressed: _launchInstagram,
                          ),
                        ),
                        SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.0),
                          ),
                          child: IconButton(
                            icon: Image.asset(
                              'assets/icons/facebook.png',
                              width: 34,
                              height: 34,
                            ),
                            onPressed: _launchFacebook,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                     child: _buildCompanyLogo(_companyData ?? widget.place),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentBranch?['name'] ?? widget.place['name'],
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.restaurant, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Icon(Icons.star, color: Colors.blue, size: 24),
                                  Icon(Icons.star, color: Colors.blue, size: 24),
                                  Icon(Icons.star, color: Colors.blue, size: 24),
                                  Icon(Icons.star, color: Colors.blue, size: 24),
                                  Icon(Icons.star, color: Colors.blue, size: 24),
                                  SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _navigateToReviews,
                                    child: Text(
                                      'View reviews',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white,
                                        decorationThickness: 2.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currentBranch?['location'] ?? '${widget.place['address']} ${_getDurationText()}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person, color: Colors.white, size: 20),
                                  SizedBox(width: 4),
                                  Text(
                                    '\$${_getCostPerCustomer()}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
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
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasBranches && branches.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _isLoadingBranches
                            ? Center(child: CircularProgressIndicator())
                            : SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: branches.length,
                            itemBuilder: (context, index) {
                              final branch = branches[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(branch['name'] ?? 'Branch ${index + 1}'),
                                  selected: _selectedBranchIndex == index,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedBranchIndex = index;
                                      });
                                      if (widget.onBranchSelect != null) {
                                        final latitude = branch['latitude'] ?? widget.place['latitude'];
                                        final longitude = branch['longitude'] ?? widget.place['longitude'];
                                        widget.onBranchSelect!(
                                          LatLng(latitude, longitude),
                                          branch['name'] ?? '',
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    Text(
                      currentBranch?['name'] ?? widget.place['name'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      currentBranch?['description'] ?? widget.place['description'] ?? 'No description available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Branch location
                    if (currentBranch != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  currentBranch['location'] ?? 'No address available',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                        ],
                      ),

                    // Branch images if available
                    if (currentBranch != null && currentBranch['images'] != null && currentBranch['images'] is List && currentBranch['images'].isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Branch Images',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: currentBranch['images'].length,
                              itemBuilder: (context, index) {
                                final imagePath = currentBranch['images'][index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imagePath,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey[200],
                                          child: Icon(Icons.broken_image),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),

                    // Navigation button - navigate to selected branch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0094FF), Color(0xFF05055A), Color(0xFF0094FF)],
                                stops: [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.navigation, size: 20),
                              label: Text('Navigate'),
                              onPressed: () {
                                final branch = hasBranches
                                    ? branches[_selectedBranchIndex]
                                    : null;

                                final coordinates = LatLng(
                                  branch?['latitude'] ?? widget.place['latitude'],
                                  branch?['longitude'] ?? widget.place['longitude'],
                                );

                                // Show navigation options
                                _showNavigationOptions(coordinates);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        _buildGradientCircularIconButton(
                          Icons.phone,
                          onPressed: () {
                            final branch = _branches.isNotEmpty ? _branches[_selectedBranchIndex] : widget.place;
                            final phoneNumber = branch['phone'] ?? branch['phoneNumber'];
                            _showPhoneOptions(phoneNumber);
                          },
                        ),
                        SizedBox(width: 12),
                        _buildGradientCircularIconButton(
                          _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                          onPressed: _isProcessingFavorite ? null : _toggleFavorite,
                        ),
                        SizedBox(width: 12),
                        _buildGradientCircularIconButton(
                          Icons.share,
                          onPressed: _shareBranchDetails,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyLogo(Map<String, dynamic> place) {
    String? logoUrl;
    if (place['companyInfo'] != null && place['companyInfo']['logo'] != null) {
      logoUrl = place['companyInfo']['logo'];
    } else if (place['logo'] != null) {
      logoUrl = place['logo'];
    }
    if (logoUrl != null && logoUrl.isNotEmpty) {
      if (logoUrl.startsWith('uploads/') || !logoUrl.startsWith('http')) {
        logoUrl = '${ApiService.baseUrl}/$logoUrl';
      }
      return Image.network(
        logoUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.business, size: 40, color: Colors.blue);
        },
      );
    }
    return Icon(Icons.business, size: 40, color: Colors.blue);
  }
}