import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/api_service.dart';
import '../../headers/dashboard_headers.dart';
import 'reviews_section.dart';
import '../../headers/sidebar.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class BranchDetailsPage extends StatefulWidget {
  final Map<String, dynamic> branch;

  const BranchDetailsPage({Key? key, required this.branch}) : super(key: key);

  @override
  _BranchDetailsPageState createState() => _BranchDetailsPageState();
}

class _BranchDetailsPageState extends State<BranchDetailsPage> {
  String? _profileImagePath;
  bool _isSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Custom header from dashboard_headers.dart
              AppHeader(
                onMenuTap: _toggleSidebar,
                onNotificationTap: () {
                  // Handle notification tap
                },
                profileImagePath: _profileImagePath,
              ),
              // Main content with image background
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero image and title overlay
                      Stack(
                        children: [
                          _buildHeroImage(),
                          // Back button overlay
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: Colors.black.withOpacity(0.5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.branch['name'] ?? 'Unnamed Branch',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  
                                  _buildRatingStars(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Tab Bar for Description
                      _buildTabHeader(),

                      // Description content
                      _buildDescriptionContent(),

                      // Divider between sections
                      Divider(height: 8, thickness: 8, color: Colors.grey.shade200),

                      // Reviews section header
                      _buildSectionHeader("Reviews"),

                      // Reviews content
                      ReviewsSection(branch: widget.branch),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Sidebar overlay
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
            child: Sidebar(
              onCollapse: _toggleSidebar,
              parentContext: context,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text(
          'Description',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: Colors.blue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    // Get image URLs from the branch data
    List<String> imageUrls = _extractImageUrls();

    // If no images, use default
    if (imageUrls.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/default_place.jpg'),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Use the first image
    String imageUrl = imageUrls.first;

    // Check if it's an asset or network image
    bool isAsset = imageUrl.startsWith('assets/');

    return Container(
      height: 220,
      decoration: isAsset ? BoxDecoration(
        image: DecorationImage(
          image: AssetImage(imageUrl) as ImageProvider,
          fit: BoxFit.cover,
        ),
      ) : null,
      // Add an error fallback
      child: imageUrl.isNotEmpty && !isAsset ? SecureNetworkImage(
        imageUrl: imageUrl,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: Container(
          height: 220,
          color: Colors.grey[300],
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          print('Error loading image: $error');
          return Container(
            height: 220,
            color: Colors.grey[300],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 40, color: Colors.grey[600]),
                  SizedBox(height: 8),
                  Text('Image could not be loaded'),
                ],
              ),
            ),
          );
        },
      ) : null,
    );
  }

  // Helper method to extract image URLs from branch data
  List<String> _extractImageUrls() {
    List<String> urls = [];

    if (widget.branch.containsKey('images')) {
      if (widget.branch['images'] is List) {
        // If images is already a list, use it directly
        urls = (widget.branch['images'] as List).map((img) => img.toString()).toList();
      } else if (widget.branch['images'] is String) {
        // If images is a comma-separated string, split it
        String imagesStr = widget.branch['images'] as String;
        if (imagesStr.isNotEmpty) {
          urls = imagesStr.split(',').map((img) => img.trim()).toList();
        }
      }
    }

    // Ensure URLs are fully formed
    for (int i = 0; i < urls.length; i++) {
      if (!urls[i].startsWith('http') && !urls[i].startsWith('https') && !urls[i].startsWith('assets/')) {
        // In a real app, you would use your base URL
        String baseUrl = ApiService.baseUrl;
        urls[i] = urls[i].startsWith('/') ? '$baseUrl${urls[i]}' : '$baseUrl/${urls[i]}';
      }
    }

    return urls;
  }

  String _formatLocationDistance(dynamic location) {
    // In a real app, you would calculate the actual distance
    // For now, just use a placeholder like in the screenshot
    return '56 meters away';
  }

  Widget _buildRatingStars() {
    final double rating = widget.branch['rating'] is num
        ? (widget.branch['rating'] as num).toDouble()
        : 0.0;

    // Round to nearest 0.5
    final roundedRating = (rating * 2).round() / 2;

    return Row(
      children: List.generate(5, (index) {
        if (index < roundedRating.floor()) {
          // Full star
          return Icon(Icons.star, color: Colors.blue, size: 24);
        } else if (index < roundedRating.ceil() && roundedRating.floor() != roundedRating.ceil()) {
          // Half star
          return Icon(Icons.star_half, color: Colors.blue, size: 24);
        } else {
          // Empty star
          return Icon(Icons.star_border, color: Colors.blue, size: 24);
        }
      }),
    );
  }

  Widget _buildDescriptionContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Name
          Text(
            'Event Name: ${widget.branch['name'] ?? 'Unnamed Event'}',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),

          // Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location: ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: Text(
                  widget.branch['address'] != null && widget.branch['address'].toString().isNotEmpty
                      ? widget.branch['address']
                      : _formatAddress(widget.branch['location']),
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description: ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: Text(
                  widget.branch['description'] ?? 'No description available',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Take Me There button
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Handle navigation
                print('BranchDetailsPage: Take Me There button pressed');
                print('BranchDetailsPage: Branch data: ${widget.branch}');
                print('BranchDetailsPage: Branch location: ${widget.branch['location']}');
                
                // Try to get location data from different possible fields
                dynamic locationData = widget.branch['location'];
                
                // If no location field, try to construct it from latitude/longitude
                if (locationData == null) {
                  final lat = widget.branch['latitude'];
                  final lng = widget.branch['longitude'];
                  if (lat != null && lng != null) {
                    locationData = {
                      'lat': lat,
                      'lng': lng,
                      'street': widget.branch['address'] ?? '',
                      'city': widget.branch['city'] ?? '',
                      'country': widget.branch['country'] ?? '',
                    };
                    print('BranchDetailsPage: Constructed location from lat/lng: $locationData');
                  }
                }
                
                _openMap(locationData);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Take Me There!'),
            ),
          ),

          // Contact icons
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildContactIcon(Icons.phone, Colors.green, () => _makePhoneCall()),
              SizedBox(width: 16),
              _buildContactIcon(Icons.message, Colors.green, () => _sendMessage()),
              SizedBox(width: 16),
              _buildInstagramIcon(() => _openInstagram()),
              SizedBox(width: 16),
              _buildContactIcon(Icons.facebook, Colors.blue, () => _openFacebook()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildInstagramIcon(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.pink,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Image.asset(
          'assets/icons/instagram.png',
          width: 20,
          height: 20,
          color: Colors.white,
          errorBuilder: (context, error, stackTrace) {
            print('BranchDetailsPage: Error loading Instagram icon: $error');
            return Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 20,
            );
          },
        ),
      ),
    );
  }

  // Phone call functionality
  void _makePhoneCall() async {
    final phoneNumber = widget.branch['phone'] ?? widget.branch['phoneNumber'];
    if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
      final Uri phoneUri = Uri.parse('tel:${phoneNumber.toString()}');
      print('BranchDetailsPage: Making phone call to: $phoneNumber');
      
      try {
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
          print('BranchDetailsPage: Successfully launched phone call');
        } else {
          print('BranchDetailsPage: Cannot launch phone call');
          _showErrorSnackBar('Cannot make phone call. Please check your device settings.');
        }
      } catch (e) {
        print('BranchDetailsPage: Error making phone call: $e');
        _showErrorSnackBar('Error making phone call: ${e.toString()}');
      }
    } else {
      print('BranchDetailsPage: No phone number available');
      _showErrorSnackBar('No phone number available for this branch.');
    }
  }

  // Send message functionality
  void _sendMessage() async {
    final phoneNumber = widget.branch['phone'] ?? widget.branch['phoneNumber'];
    if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
      final Uri messageUri = Uri.parse('sms:${phoneNumber.toString()}');
      print('BranchDetailsPage: Sending message to: $phoneNumber');
      
      try {
        if (await canLaunchUrl(messageUri)) {
          await launchUrl(messageUri);
          print('BranchDetailsPage: Successfully launched message app');
        } else {
          print('BranchDetailsPage: Cannot launch message app');
          _showErrorSnackBar('Cannot send message. Please check your device settings.');
        }
      } catch (e) {
        print('BranchDetailsPage: Error sending message: $e');
        _showErrorSnackBar('Error sending message: ${e.toString()}');
      }
    } else {
      print('BranchDetailsPage: No phone number available for messaging');
      _showErrorSnackBar('No phone number available for messaging.');
    }
  }

  // Open Instagram functionality
  void _openInstagram() async {
    final instagramUrl = widget.branch['instagram'] ?? 
                        widget.branch['socialMedia']?['instagram'] ?? 
                        widget.branch['company']?['instagram'];
    
    if (instagramUrl != null && instagramUrl.toString().isNotEmpty) {
      String url = instagramUrl.toString();
      
      // Ensure the URL has proper protocol
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      
      final Uri instagramUri = Uri.parse(url);
      print('BranchDetailsPage: Opening Instagram: $url');
      
      try {
        if (await canLaunchUrl(instagramUri)) {
          await launchUrl(instagramUri, mode: LaunchMode.externalApplication);
          print('BranchDetailsPage: Successfully launched Instagram');
        } else {
          print('BranchDetailsPage: Cannot launch Instagram');
          _showErrorSnackBar('Cannot open Instagram. Please check your device settings.');
        }
      } catch (e) {
        print('BranchDetailsPage: Error opening Instagram: $e');
        _showErrorSnackBar('Error opening Instagram: ${e.toString()}');
      }
    } else {
      print('BranchDetailsPage: No Instagram URL available');
      _showErrorSnackBar('No Instagram page available for this branch.');
    }
  }

  // Open Facebook functionality
  void _openFacebook() async {
    final facebookUrl = widget.branch['facebook'] ?? 
                       widget.branch['socialMedia']?['facebook'] ?? 
                       widget.branch['company']?['facebook'];
    
    if (facebookUrl != null && facebookUrl.toString().isNotEmpty) {
      String url = facebookUrl.toString();
      
      // Ensure the URL has proper protocol
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      
      final Uri facebookUri = Uri.parse(url);
      print('BranchDetailsPage: Opening Facebook: $url');
      
      try {
        if (await canLaunchUrl(facebookUri)) {
          await launchUrl(facebookUri, mode: LaunchMode.externalApplication);
          print('BranchDetailsPage: Successfully launched Facebook');
        } else {
          print('BranchDetailsPage: Cannot launch Facebook');
          _showErrorSnackBar('Cannot open Facebook. Please check your device settings.');
        }
      } catch (e) {
        print('BranchDetailsPage: Error opening Facebook: $e');
        _showErrorSnackBar('Error opening Facebook: ${e.toString()}');
      }
    } else {
      print('BranchDetailsPage: No Facebook URL available');
      _showErrorSnackBar('No Facebook page available for this branch.');
    }
  }

  // Helper method to show error messages
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Helper method to show info messages
  void _showInfoSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openMap(dynamic location) async {
    print('BranchDetailsPage: Opening map for location: $location');
    print('BranchDetailsPage: Location type: ${location.runtimeType}');
    
    double? lat;
    double? lng;

    // If location is a Map, check for coordinates, lat/lng keys
    if (location is Map) {
      print('BranchDetailsPage: Location is a Map with keys: ${location.keys.toList()}');
      
      if (location.containsKey('coordinates')) {
        var coords = location['coordinates'];
        print('BranchDetailsPage: Found coordinates: $coords');
        if (coords is List && coords.length >= 2) {
          lng = coords[0] is num ? (coords[0] as num).toDouble() : null;
          lat = coords[1] is num ? (coords[1] as num).toDouble() : null;
        }
      } else if (location.containsKey('lat') && location.containsKey('lng')) {
        lat = location['lat'] is num ? (location['lat'] as num).toDouble() : null;
        lng = location['lng'] is num ? (location['lng'] as num).toDouble() : null;
        print('BranchDetailsPage: Found lat/lng: lat=$lat, lng=$lng');
      }
    } else {
      // Try to access as Address object
      try {
        lat = location.lat?.toDouble();
        lng = location.lng?.toDouble();
        print('BranchDetailsPage: Address object - lat=$lat, lng=$lng');
      } catch (e) {
        print('BranchDetailsPage: Error accessing Address object: $e');
      }
    }

    print('BranchDetailsPage: Final coordinates - lat=$lat, lng=$lng');

    if (lat != null && lng != null && lat != 0 && lng != 0) {
      final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      print('BranchDetailsPage: Opening map with coordinates: $mapUri');
      
      try {
        if (await canLaunchUrl(mapUri)) {
          await launchUrl(mapUri, mode: LaunchMode.externalApplication);
          print('BranchDetailsPage: Successfully opened map with coordinates');
          return;
        } else {
          print('BranchDetailsPage: Cannot launch URL with coordinates');
          // Try alternative approach
          await _launchMapAlternative(lat, lng);
        }
      } catch (e) {
        print('BranchDetailsPage: Error launching map with coordinates: $e');
        // Try alternative approach
        await _launchMapAlternative(lat, lng);
      }
    }

    // Fallback to address string
    String address = _formatAddress(location);
    print('BranchDetailsPage: Fallback to address: $address');
    
    if (address.isNotEmpty) {
      final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
      print('BranchDetailsPage: Opening map with address: $mapUri');
      
      try {
        if (await canLaunchUrl(mapUri)) {
          await launchUrl(mapUri, mode: LaunchMode.externalApplication);
          print('BranchDetailsPage: Successfully opened map with address');
        } else {
          print('BranchDetailsPage: Cannot launch URL with address');
          // Try alternative approach
          await _launchMapAlternative(null, null, address);
        }
      } catch (e) {
        print('BranchDetailsPage: Error launching map with address: $e');
        // Try alternative approach
        await _launchMapAlternative(null, null, address);
      }
    } else {
      print('BranchDetailsPage: No address available for fallback');
    }
  }

  // Alternative method to launch maps
  Future<void> _launchMapAlternative(double? lat, double? lng, [String? address]) async {
    try {
      String query;
      if (lat != null && lng != null) {
        query = '$lat,$lng';
      } else if (address != null && address.isNotEmpty) {
        query = Uri.encodeComponent(address);
      } else {
        print('BranchDetailsPage: No valid location data for alternative launch');
        return;
      }

      // Try different map URLs
      final List<String> mapUrls = [
        'https://maps.google.com/maps?q=$query',
        'https://www.google.com/maps/search/?api=1&query=$query',
        'geo:$query',
        'comgooglemaps://?q=$query',
        'maps://?q=$query',
      ];

      for (String url in mapUrls) {
        try {
          final Uri uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            print('BranchDetailsPage: Successfully opened map with alternative URL: $url');
            return;
          }
        } catch (e) {
          print('BranchDetailsPage: Failed to launch alternative URL $url: $e');
          continue;
        }
      }
      
      print('BranchDetailsPage: All alternative map URLs failed');
      
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open map. Please try again or check your device settings.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('BranchDetailsPage: Error in alternative map launch: $e');
      
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening map: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatAddress(dynamic location) {
    if (location == null) return '';
    if (location is Map) {
      final street = location['street'] ?? '';
      final city = location['city'] ?? '';
      final country = location['country'] ?? '';
      return [street, city, country].where((part) => part.isNotEmpty).join(', ');
    } else if (location.runtimeType.toString() == 'Address' || location is Object) {
      // Try to access as Address object (defensive, since we can't import model here)
      try {
        final street = location.street ?? '';
        final city = location.city ?? '';
        final country = location.country ?? '';
        return [street, city, country].where((part) => part.isNotEmpty).join(', ');
      } catch (e) {
        return '';
      }
    }
    return '';
  }
}