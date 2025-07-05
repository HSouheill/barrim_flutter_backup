import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';

import '../../../../services/api_service.dart';
import '../../headers/dashboard_headers.dart';
import '../../../../models/auth_provider.dart';
import '../workers/worker_profile_view.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<dynamic> _favoriteBranches = [];
  List<dynamic> _favoriteLocations = [];
  List<dynamic> _favoriteEvents = [];
  List<dynamic> _favoriteWorkers = [];
  List<dynamic> _favoriteServiceProviders = []; // Added for service providers
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  ApiService apiService = ApiService(); // Instance of ApiService for new methods
  String? _profileImagePath; // Add this line

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to ensure the context is available
    Future.microtask(() async {
      await _loadUserProfileImage();
      await _loadFavorites();
    });
  }

  Future<void> _loadUserProfileImage() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData['profilePic'] != null && userData['profilePic'].toString().isNotEmpty) {
        String profilePic = userData['profilePic'];
        // Construct the full URL
        if (profilePic.startsWith('http')) {
          _profileImagePath = profilePic;
        } else {
          if (ApiService.baseUrl.endsWith('/') && profilePic.startsWith('/')) {
            _profileImagePath = '${ApiService.baseUrl}${profilePic.substring(1)}';
          } else if (!ApiService.baseUrl.endsWith('/') && !profilePic.startsWith('/')) {
            _profileImagePath = '${ApiService.baseUrl}/$profilePic';
          } else {
            _profileImagePath = '${ApiService.baseUrl}$profilePic';
          }
        }
      }
    } catch (e) {
      print('Error loading user profile image: $e');
    }
    setState(() {});
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token != null) {
        // Call API services to get both types of favorites
        final branchResponse = await ApiService.getFavoriteBranches(token);
        final serviceProvidersResponse = await apiService.getFavoriteServiceProviders();

        // Debug: Print responses
        print('API Branch Response: $branchResponse');
        print('API Service Providers Response: $serviceProvidersResponse');

        // Handle service providers response
        List<dynamic> serviceProviders = [];
        if (serviceProvidersResponse is Map && serviceProvidersResponse['data'] != null) {
          serviceProviders = List<dynamic>.from(serviceProvidersResponse['data']);
        } else if (serviceProvidersResponse is List) {
          serviceProviders = serviceProvidersResponse;
        }

        // Categorize branch favorites by type
        List<dynamic> locations = [];
        List<dynamic> events = [];
        List<dynamic> workers = [];

        if (branchResponse is List) {
          for (var branch in branchResponse) {
            if (branch['branch'] != null) {
              String? category = branch['branch']['category']?.toString();
              if (category == "Event") {
                events.add(branch);
              } else if (category == "Worker") {
                workers.add(branch);
              } else {
                locations.add(branch);
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _favoriteServiceProviders = serviceProviders;
            _favoriteBranches = branchResponse is List ? branchResponse : [];
            _favoriteLocations = locations;
            _favoriteEvents = events;
            _favoriteWorkers = workers;
            _isLoading = false;
          });
        }
      } else {
        print('Error: No token available');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMessage = 'Not logged in. Please log in to view favorites';
          });
        }
      }
    } catch (e) {
      print('Error loading favorites: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Failed to load favorites: $e';
        });
      }
    }
  }


  // Helper function to get a proper image URL
  String _getImageUrl(dynamic item, String fallbackAsset) {
    if (item['branch'] != null && item['branch']['images'] != null && item['branch']['images'].isNotEmpty) {
      final imagePath = item['branch']['images'][0];

      // Handle both formats: with or without the base URL
      if (imagePath.startsWith('http')) {
        return imagePath;
      } else {
        // Remove 'uploads/' prefix if it exists in the path
        // to avoid duplication when we prepend the base URL
        final cleanPath = imagePath.startsWith('uploads/')
            ? imagePath.substring(8) // Remove 'uploads/' prefix
            : imagePath;

        // Format according to server's URL structure
        return '${ApiService.baseUrl}/uploads/$cleanPath';
      }
    }
    return fallbackAsset; // Fallback to asset
  }

  // Helper function to get service provider image URL
  // Improved helper function to get service provider image URL
  String _getServiceProviderImageUrl(dynamic provider, String fallbackAsset) {
    try {
      // Debug the provider object to see what's available
      print('Provider data for image: ${jsonEncode(provider)}');

      // First check for the logo path
      if (provider['logoPath'] != null && provider['logoPath'].toString().isNotEmpty) {
        String logoPath = provider['logoPath'].toString();
        print('Found logoPath: $logoPath');

        // Handle path formats
        if (logoPath.startsWith('http')) {
          return logoPath;
        } else {
          // Remove starting slash if present
          if (logoPath.startsWith('/')) {
            logoPath = logoPath.substring(1);
          }
          return '${ApiService.baseUrl}/$logoPath';
        }
      }

      // Check profile photo in service provider info
      if (provider['serviceProviderInfo'] != null &&
          provider['serviceProviderInfo']['profilePhoto'] != null &&
          provider['serviceProviderInfo']['profilePhoto'].toString().isNotEmpty) {

        String imagePath = provider['serviceProviderInfo']['profilePhoto'].toString();
        print('Found profilePhoto: $imagePath');

        // Handle path formats
        if (imagePath.startsWith('http')) {
          return imagePath;
        } else {
          // Remove starting slash if present
          if (imagePath.startsWith('/')) {
            imagePath = imagePath.substring(1);
          }
          return '${ApiService.baseUrl}/$imagePath';
        }
      }

      // If we reach here, no valid image path was found
      print('No valid image path found, using fallback');
      return fallbackAsset;
    } catch (e) {
      print('Error getting service provider image URL: $e');
      return fallbackAsset;
    }
  }

  Future<void> _removeFromFavorites(String branchId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token != null) {
        final result = await ApiService.removeFromFavorites(branchId, token);
        if (result['success']) {
          // Reload favorites after removing
          _loadFavorites();
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text(result['message'])),
          // );
        } else {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text(result['message'])),
          // );
        }
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('You need to be logged in')),
        // );
      }
    } catch (e) {
      print('Error removing from favorites: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Failed to remove from favorites')),
      // );
    }
  }

  // New method to remove service provider from favorites
  Future<void> _removeServiceProviderFromFavorites(String providerId) async {
    try {
      print('Attempting to remove service provider with ID: $providerId');
      if (providerId.isEmpty) {
        print('Error: providerId is empty');
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Invalid provider ID')),
        // );
        return;
      }

      final result = await apiService.removeServiceProviderFromFavorites(providerId);
      if (result) {
        // Reload favorites after removing
        _loadFavorites();
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Service provider removed from favorites')),
        // );
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Failed to remove service provider from favorites')),
        // );
      }
    } catch (e) {
      print('Error removing service provider from favorites: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if provider is available in the current context
    final bool hasProvider = Provider.of<AuthProvider>(context, listen: false) != null;
    final bool isAuthenticated = hasProvider ?
    Provider.of<AuthProvider>(context).isAuthenticated : false;

    return Scaffold(
      body: Column(
        children: [
          // Import the AppHeader from dashboard_headers.dart
          AppHeader(
            profileImagePath: _profileImagePath ?? '',
            onMenuTap: () {
              // Implement menu tap functionality
              Scaffold.of(context).openEndDrawer();
            },
          ),

          // Back button and Favorites title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.blue),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const Text(
                  'Favorites',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: _buildContent(isAuthenticated),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isAuthenticated) {

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Events Section
              if (_favoriteEvents.isNotEmpty) ...[
                const Text(
                  'Events',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child:
                  ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _favoriteEvents.length,
                    itemBuilder: (context, index) {
                      final event = _favoriteEvents[index];
                      return _buildEventCard(
                        event['branch']['name'] ?? 'Event',
                        event['branch']['location']['address'] ?? 'Unknown location',
                        _getImageUrl(event, 'assets/images/concert.jpg'),
                        event['branch']['_id'],
                      );
                    },
                    itemExtent: 192, // 180 + 12 spacing
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Locations Section
              if (_favoriteLocations.isNotEmpty) ...[
                const Text(
                  'Locations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _favoriteLocations.length,
                    itemBuilder: (context, index) {
                      final location = _favoriteLocations[index];
                      // Calculate distance (would come from API or compute based on current location)
                      String distanceText = "Unknown distance";
                      if (location['branch']['location'] != null &&
                          location['branch']['location']['lat'] != null) {
                        distanceText = "${(index + 1) * 50} meters away";
                      }

                      return _buildLocationCard(
                        location['branch']['name'] ?? 'Location',
                        distanceText,
                        _getImageUrl(location, 'assets/images/jeita.jpg'),
                        location['branch']['_id'],
                      );
                    },
                    itemExtent: 192, // 180 + 12 spacing
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Service Providers Section - new section
              if (_favoriteServiceProviders.isNotEmpty) ...[
                const Text(
                  'Workers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                // const SizedBox(height: 12),

                // Service Providers List
                // In the service provider section of your _buildContent method
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _favoriteServiceProviders.length,
                  itemBuilder: (context, index) {
                    final provider = _favoriteServiceProviders[index];

                    // Debug the provider data
                    print('Provider at index $index: ${jsonEncode(provider)}');

                    String id = '';
                    if (provider['_id'] != null) {
                      id = provider['_id'].toString();
                    } else if (provider['id'] != null) { // This is the key part - try 'id' if '_id' is null
                      id = provider['id'].toString();
                    }

                    // Extract name
                    String name = '';
                    if (provider['fullName'] != null && provider['fullName'].toString().isNotEmpty) {
                      name = provider['fullName'];
                    } else if (provider['firstName'] != null && provider['lastName'] != null) {
                      final firstName = provider['firstName']?.toString() ?? '';
                      final lastName = provider['lastName']?.toString() ?? '';
                      name = "$firstName $lastName".trim();
                    } else if (provider['companyName'] != null) {
                      name = provider['companyName'].toString();
                    } else {
                      name = 'Service Provider';
                    }

                    // Get the image URL with the improved helper function
                    String imageUrl = _getServiceProviderImageUrl(provider, 'assets/images/worker1.jpg');

                    // Debug the image URL
                    print('Image URL for $name: $imageUrl');

                    // Extract other fields with null safety
                    final bool isVerified = provider['isVerified'] == true;
                    final int rating = provider['rating'] != null
                        ? (provider['rating'] is int ? provider['rating'] : (provider['rating'] as num?)?.round() ?? 0)
                        : 0;

                    // Get service description
                    String description = 'Professional service provider';
                    if (provider['serviceProviderInfo'] != null) {
                      if (provider['serviceProviderInfo']['serviceType'] != null) {
                        description = provider['serviceProviderInfo']['serviceType'].toString();
                      } else if (provider['serviceProviderInfo']['services'] != null &&
                          provider['serviceProviderInfo']['services'] is List &&
                          (provider['serviceProviderInfo']['services'] as List).isNotEmpty) {
                        description = (provider['serviceProviderInfo']['services'] as List).join(', ');
                      }
                    }

                    print('Service provider ID for removal: $id'); // Add this debug line

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildWorkerCard(
                        name,
                        isVerified,
                        rating,
                        description,
                        imageUrl,
                        id,
                        isBranch: false,
                        provider: provider,
                      ),
                    );
                  },
                )
              ],

              // If no favorites
              if (_favoriteBranches.isEmpty && _favoriteServiceProviders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'You have no favorites yet. Add some by tapping the heart icon on places, events or workers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget for Event Cards
  Widget _buildEventCard(String title, String location, String imagePath, String id) {
    return Stack(
      children: [
        Container(
          width: 180,
          margin: const EdgeInsets.only(right: 12),
          decoration: imagePath.startsWith('assets/') ? BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: AssetImage(imagePath) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ) : BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: imagePath.startsWith('assets/') ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  location,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ) : Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SecureNetworkImage(
                  imageUrl: imagePath,
                  width: 180,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    width: 180,
                    height: 120,
                    color: Colors.grey[300],
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 180,
                    height: 120,
                    color: Colors.grey[300],
                    child: Center(child: Icon(Icons.error_outline, color: Colors.grey[600])),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      location,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 20,
          child: GestureDetector(
            onTap: () => _removeFromFavorites(id),
            child: const Icon(
              Icons.favorite,
              color: Colors.red,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  // Widget for Location Cards
  Widget _buildLocationCard(String title, String distance, String imagePath, String id) {
    return Stack(
      children: [
        Container(
          width: 180,
          margin: const EdgeInsets.only(right: 12),
          decoration: imagePath.startsWith('assets/') ? BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: AssetImage(imagePath) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ) : BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: imagePath.startsWith('assets/') ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  distance,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ) : Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SecureNetworkImage(
                  imageUrl: imagePath,
                  width: 180,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    width: 180,
                    height: 120,
                    color: Colors.grey[300],
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 180,
                    height: 120,
                    color: Colors.grey[300],
                    child: Center(child: Icon(Icons.error_outline, color: Colors.grey[600])),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      distance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 20,
          child: GestureDetector(
            onTap: () => _removeFromFavorites(id),
            child: const Icon(
              Icons.favorite,
              color: Colors.red,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  // Widget for Worker Cards and Service Provider Cards (with isBranch parameter)
  Widget _buildWorkerCard(String name, bool isVerified, int rating, String experience,
      String imagePath, String id, {required bool isBranch, dynamic provider}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Worker/Provider Profile Image
          CircleAvatar(
            radius: 30,
            backgroundImage: imagePath.startsWith('assets/') ?
            AssetImage(imagePath) :
            null,
            onBackgroundImageError: (exception, stackTrace) {
              print('Error loading profile image: $exception');
            },
            child: imagePath.startsWith('assets/') ? null : (imagePath.isNotEmpty ? ClipOval(
              child: SecureNetworkImage(
                imageUrl: imagePath,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: Icon(Icons.person, size: 30),
                errorWidget: (context, url, error) => Icon(Icons.person, size: 30),
              ),
            ) : Icon(Icons.person, size: 30)),
          ),
          const SizedBox(width: 12),

          // Worker/Provider Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    for (int i = 0; i < 5; i++)
                      Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      ),
                  ],
                ),
                Text(
                  experience,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Buttons
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  // Navigate to ServiceProviderProfile on Emergency
                  if (!isBranch && id.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ServiceProviderProfile(
                          provider: provider,
                          providerId: id,
                          logoUrl: provider['logoPath']?.toString(),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  minimumSize: const Size(100, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Emergency'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Navigate to ServiceProviderProfile on View
                  if (!isBranch && id.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ServiceProviderProfile(
                          provider: provider,
                          providerId: id,
                          logoUrl: provider['logoPath']?.toString(),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  minimumSize: const Size(100, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('View'),
              ),
            ],
          ),

          // Favorite Icon - uses appropriate removal method based on item type
          // In your GestureDetector onTap in _buildWorkerCard
          GestureDetector(
            onTap: () {
              print('Tapped favorite icon for ID: "$id"'); // Add this debug line
              if (id.isNotEmpty) {
                isBranch ? _removeFromFavorites(id) : _removeServiceProviderFromFavorites(id);
              } else {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('Cannot remove favorite: Missing ID')),
                // );
              }
            },
            child: const Icon(
              Icons.favorite,
              color: Colors.red,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}