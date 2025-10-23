import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import '../custom_header.dart';
import '../../../../services/api_service.dart';
import '../verification_code.dart';
import '../white_headr.dart';
import '../../../../services/google_auth_service.dart';
import '../../../../services/user_provider.dart';
import 'package:provider/provider.dart';
import '../user_dashboard/home.dart';
import '../company_dashboard/company_dashboard.dart';
import '../serviceProvider_dashboard/serviceprovider_dashboard.dart';
import '../wholesaler_dashboard/wholesaler_dashboard.dart';

class SignupUserPage5 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupUserPage5({super.key, required this.userData});

  @override
  State<SignupUserPage5> createState() => _SignupUserPage5State();
}

class _SignupUserPage5State extends State<SignupUserPage5> {
  GoogleMapController? mapController;
  final LatLng _center = const LatLng(33.8, 35.8); // Center of Lebanon
  Set<Marker> markers = {};
  LatLng? selectedLocation;
  bool isLoading = false;

  // Address-related variables
  String? country;
  String? governorate;
  String? district;
  String? city;
  String? fullAddress;

  Future<void> _completeGoogleSignup(BuildContext context) async {
    try {
      // Get the Google user data
      final googleUserData = widget.userData['googleUserData'] as Map<String, dynamic>;
      
      // Now authenticate with Google to get the proper tokens
      final provider = Provider.of<GoogleSignInProvider>(context, listen: false);
      final result = await provider.googleLogin();
      
      if (result != null && result['needsSignup'] != true) {
        // Google authentication successful
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(result['user']);
        userProvider.setToken(result['token']);
        
        final userData = result['user'] ?? {};
        final userType = userData['userType'] ?? 'user';
        
        // Save the last visited page for session restoration
        final dashboardPageName = _getDashboardPageName(userType);
        userProvider.saveLastVisitedPage(
          dashboardPageName,
          pageData: userData,
          routePath: dashboardPageName,
        );
        
        // Navigate to appropriate dashboard
        _navigateAfterSignup(userType, result);
      } else {
        // Fallback: navigate to OTP verification
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              phoneNumber: widget.userData['phone'],
            ),
          ),
        );
      }
    } catch (e) {
      print("Error completing Google signup: $e");
      // Fallback: navigate to OTP verification
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            phoneNumber: widget.userData['phone'],
          ),
        ),
      );
    }
  }

  // Helper method to get dashboard page name for session restoration
  String _getDashboardPageName(String userType) {
    switch (userType) {
      case 'user':
        return 'UserDashboard';
      case 'company':
        return 'CompanyDashboard';
      case 'serviceProvider':
        return 'ServiceproviderDashboard';
      case 'wholesaler':
        return 'WholesalerDashboard';
      default:
        return 'UserDashboard';
    }
  }

  void _navigateAfterSignup(String userType, Map<String, dynamic> userData) {
    switch (userType) {
      case 'user':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserDashboard(userData: userData),
          ),
        );
        break;
      case 'company':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompanyDashboard(userData: userData),
          ),
        );
        break;
      case 'serviceProvider':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceproviderDashboard(userData: userData),
          ),
        );
        break;
      case 'wholesaler':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WholesalerDashboard(userData: userData),
          ),
        );
        break;
      default:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserDashboard(userData: userData),
          ),
        );
    }
  }

  // Enhanced signup method with retry logic for real devices
  Future<Map<String, dynamic>> _signupWithRetry(Map<String, dynamic> userData, {int maxRetries = 3}) async {
    int attempt = 0;
    Exception? lastException;
    
    while (attempt < maxRetries) {
      try {
        attempt++;
        print('Signup attempt $attempt of $maxRetries');
        
        // Increase timeout for real devices (60 seconds)
        final response = await ApiService.signupUser(userData).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Request timed out after 60 seconds');
          },
        );
        
        print('Signup successful on attempt $attempt');
        return response;
        
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('Signup attempt $attempt failed: $e');
        
        // If this is the last attempt, don't wait
        if (attempt < maxRetries) {
          // Wait before retrying (exponential backoff)
          final waitTime = Duration(seconds: attempt * 2);
          print('Waiting ${waitTime.inSeconds} seconds before retry...');
          await Future.delayed(waitTime);
        }
      }
    }
    
    // All attempts failed
    throw lastException ?? Exception('Signup failed after $maxRetries attempts');
  }

  void _submitSignup(BuildContext context) async {
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location first'),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Get address data from SignupUserPage4 as fallback
      final addressData = widget.userData['address'] as Map<String, dynamic>?;
      
      // Add location data to the existing user data
      // The API service expects location data to be flattened at the top level
      final Map<String, dynamic> updatedUserData = {
        ...widget.userData,
        'location': {
          'lat': selectedLocation!.latitude,
          'lng': selectedLocation!.longitude,
          'address': {
            'country': (country?.isNotEmpty == true) ? country : addressData?['country'],
            'governorate': (governorate?.isNotEmpty == true) ? governorate : addressData?['governorate'],
            'district': (district?.isNotEmpty == true) ? district : addressData?['district'],
            'city': (city?.isNotEmpty == true) ? city : addressData?['city'],
            'fullAddress': fullAddress,
          }
        }
      };
      
      // Debug print to verify final location data
      print('=== SIGNUP USER PAGE 5 FINAL LOCATION DEBUG ===');
      print('Selected location lat: ${selectedLocation!.latitude}');
      print('Selected location lng: ${selectedLocation!.longitude}');
      print('Geocoded country: $country');
      print('Geocoded governorate: $governorate');
      print('Geocoded district: $district');
      print('Geocoded city: $city');
      print('Fallback country: ${addressData?['country']}');
      print('Fallback governorate: ${addressData?['governorate']}');
      print('Fallback district: ${addressData?['district']}');
      print('Fallback city: ${addressData?['city']}');
      print('Final country: ${(country?.isNotEmpty == true) ? country : addressData?['country']}');
      print('Final governorate: ${(governorate?.isNotEmpty == true) ? governorate : addressData?['governorate']}');
      print('Final district: ${(district?.isNotEmpty == true) ? district : addressData?['district']}');
      print('Final city: ${(city?.isNotEmpty == true) ? city : addressData?['city']}');
      print('Updated userData: $updatedUserData');
      print('===============================================');

      // Add longer timeout for real devices and retry logic
      final response = await _signupWithRetry(updatedUserData);

      if (mounted) {
        // Check response body for success indication, regardless of error
        if (response.containsKey('message') &&
            response['message']?.toString().contains('OTP sent successfully') == true) {
          // Navigate to OTP verification screen even if there was a connection issue
          // but the server confirmed OTP was sent
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                phoneNumber: widget.userData['phone'],
              ),
            ),
          );
        } else if (response['status'] == 201 || response['status'] == 200) {
          // Check if this is a Google signup flow
          if (widget.userData.containsKey('googleUserData')) {
            print("Google signup completed, proceeding with Google authentication");
            await _completeGoogleSignup(context);
          } else {
            // Standard success case
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OtpVerificationScreen(
                  phoneNumber: widget.userData['phone'],
                ),
              ),
            );
          }
        } else {
          // Actual error case
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? "Signup Failed")),
          );
        }
      }
    } catch (e) {
      print('Error in _submitSignup: $e');
      
      // Special handling for connection errors that might contain partial success
      if (e.toString().contains('OTP sent successfully')) {
        if (mounted) {
          // The server likely processed the request but connection dropped during response
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                phoneNumber: widget.userData['phone'],
              ),
            ),
          );
        }
      } else if (mounted) {
        // Enhanced error handling for real devices
        String errorMessage = "Signup Failed";
        
        if (e.toString().contains('timeout') || e.toString().contains('timed out')) {
          errorMessage = "Connection timeout. Please check your internet connection and try again.";
        } else if (e.toString().contains('Failed host lookup') || e.toString().contains('No address associated')) {
          errorMessage = "Cannot connect to server. Please check your internet connection.";
        } else if (e.toString().contains('SSL') || e.toString().contains('certificate')) {
          errorMessage = "Connection security error. Please try again.";
        } else if (e.toString().contains('Connection error')) {
          errorMessage = "Network connection error. Please check your internet and try again.";
        } else {
          errorMessage = "Signup failed: ${e.toString()}";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                // Retry the signup
                _submitSignup(context);
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      loc.Location location = loc.Location();

      // Check if location services are enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location services are disabled.'),
              ),
            );
          }
          return;
        }
      }

      // Check if permission is granted
      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied.'),
              ),
            );
          }
          return;
        }
      }

      // Get location with timeout
      loc.LocationData locationData = await location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );

      // Move to user's current location and add a marker
      if (locationData.latitude != null && locationData.longitude != null) {
        LatLng userLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!
        );

        // Check if mapController is initialized before using it
        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: userLocation,
                zoom: 15,
              ),
            ),
          );
        }

        _addMarker(userLocation);

        // Debug print to verify current location capture
        print('=== CURRENT LOCATION DEBUG ===');
        print('Current location lat: ${userLocation.latitude}');
        print('Current location lng: ${userLocation.longitude}');
        print('==============================');

        // Call submit signup after marker is set
        _submitSignup(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location coordinates.'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Check for permissions on startup
    _checkLocationPermission();
    
    // Debug print to verify address data from SignupUserPage4
    print('=== SIGNUP USER PAGE 5 DEBUG ===');
    print('Received userData: ${widget.userData}');
    print('Address data: ${widget.userData['address']}');
    print('=====================================');
  }

  Future<void> _checkLocationPermission() async {
    loc.Location location = loc.Location();
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    // Check if location services are enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    // Check if permission is granted
    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        return;
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Apply dark map style
    controller.setMapStyle('''
      [
        {
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#212121"
            }
          ]
        },
        {
          "elementType": "labels.icon",
          "stylers": [
            {
              "visibility": "off"
            }
          ]
        },
        {
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#757575"
            }
          ]
        },
        {
          "elementType": "labels.text.stroke",
          "stylers": [
            {
              "color": "#212121"
            }
          ]
        },
        {
          "featureType": "administrative",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#757575"
            }
          ]
        },
        {
          "featureType": "administrative.country",
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#9e9e9e"
            }
          ]
        },
        {
          "featureType": "administrative.locality",
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#bdbdbd"
            }
          ]
        },
        {
          "featureType": "poi",
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#757575"
            }
          ]
        },
        {
          "featureType": "poi.park",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#181818"
            }
          ]
        },
        {
          "featureType": "poi.park",
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#616161"
            }
          ]
        },
        {
          "featureType": "poi.park",
          "elementType": "labels.text.stroke",
          "stylers": [
            {
              "color": "#1b1b1b"
            }
          ]
        },
        {
          "featureType": "road",
          "elementType": "geometry.fill",
          "stylers": [
            {
              "color": "#2c2c2c"
            }
          ]
        },
        {
          "featureType": "road",
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#8a8a8a"
            }
          ]
        },
        {
          "featureType": "road.arterial",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#373737"
            }
          ]
        },
        {
          "featureType": "road.highway",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#3c3c3c"
            }
          ]
        },
        {
          "featureType": "road.highway.controlled_access",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#4e4e4e"
            }
          ]
        },
        {
          "featureType": "road.local",
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#616161"
            }
          ]
        },
        {
          "featureType": "transit",
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#757575"
            }
          ]
        },
        {
          "featureType": "water",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#000000"
            }
          ]
        },
        {
          "featureType": "water",
          "elementType": "labels.text.fill",
          "stylers": [
            {
              "color": "#3d3d3d"
            }
          ]
        }
      ]
    ''');
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Get address data from SignupUserPage4 as fallback
      final addressData = widget.userData['address'] as Map<String, dynamic>?;
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        setState(() {
          // Use geocoded values if available and not empty, otherwise fallback to SignupUserPage4 data
          country = (place.country?.isNotEmpty == true) ? place.country : addressData?['country'];
          governorate = (place.administrativeArea?.isNotEmpty == true) ? place.administrativeArea : addressData?['governorate'];
          district = (place.subAdministrativeArea?.isNotEmpty == true) ? place.subAdministrativeArea : addressData?['district'];
          city = (place.locality?.isNotEmpty == true) ? place.locality : addressData?['city'];
          
          // Debug print to verify address data
          print('=== GEOCODING DEBUG ===');
          print('Geocoded country: ${place.country}');
          print('Geocoded governorate: ${place.administrativeArea}');
          print('Geocoded district: ${place.subAdministrativeArea}');
          print('Geocoded city: ${place.locality}');
          print('Fallback country: ${addressData?['country']}');
          print('Fallback governorate: ${addressData?['governorate']}');
          print('Fallback district: ${addressData?['district']}');
          print('Fallback city: ${addressData?['city']}');
          print('Final country: $country');
          print('Final governorate: $governorate');
          print('Final district: $district');
          print('Final city: $city');
          print('======================');
          
          // Build full address with available data
          final cityPart = city ?? '';
          final districtPart = district ?? '';
          final governoratePart = governorate ?? '';
          final countryPart = country ?? '';
          
          final addressParts = [cityPart, districtPart, governoratePart, countryPart]
              .where((part) => part.isNotEmpty)
              .toList();
          
          fullAddress = addressParts.join(', ');
        });
      } else {
        // If no placemarks found, use data from SignupUserPage4
        if (addressData != null) {
          setState(() {
            country = addressData['country'];
            governorate = addressData['governorate'];
            district = addressData['district'];
            city = addressData['city'];
            
            // Build full address with available data
            final cityPart = city ?? '';
            final districtPart = district ?? '';
            final governoratePart = governorate ?? '';
            final countryPart = country ?? '';
            
            final addressParts = [cityPart, districtPart, governoratePart, countryPart]
                .where((part) => part.isNotEmpty)
                .toList();
            
            fullAddress = addressParts.join(', ');
          });
        }
      }
    } catch (e) {
      print('Error getting address: $e');
      
      // If geocoding fails completely, use data from SignupUserPage4
      final addressData = widget.userData['address'] as Map<String, dynamic>?;
      if (addressData != null) {
        setState(() {
          country = addressData['country'];
          governorate = addressData['governorate'];
          district = addressData['district'];
          city = addressData['city'];
          
          // Build full address with available data
          final cityPart = city ?? '';
          final districtPart = district ?? '';
          final governoratePart = governorate ?? '';
          final countryPart = country ?? '';
          
          final addressParts = [cityPart, districtPart, governoratePart, countryPart]
              .where((part) => part.isNotEmpty)
              .toList();
          
          fullAddress = addressParts.join(', ');
        });
      }
    }
  }

  void _addMarker(LatLng position) {
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      selectedLocation = position;
      _getAddressFromLatLng(position);
    });
    
    // Debug print to verify marker placement
    print('=== MAP MARKER DEBUG ===');
    print('Marker placed at lat: ${position.latitude}');
    print('Marker placed at lng: ${position.longitude}');
    print('Selected location: $selectedLocation');
    print('========================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/background.png',
                  fit: BoxFit.cover,
                ),
              ),

              // Overlay Color (semi-transparent) over Background Image
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
                ),
              ),

              // White Top Area with Sign Up header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 180,
                  child: WhiteHeader(
                    title: 'Sign Up',
                    onBackPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // Custom Header with Progress Bar
              Positioned(
                top: 180 + 16,
                left: 0,
                right: 0,
                child: CustomHeader(
                  currentPageIndex: 4, // Same page index as manual entry
                  totalPages: 4,
                  subtitle: 'User',
                  onBackPressed: () => Navigator.of(context).pop(),
                ),
              ),

              // Map Container (with adjusted size to match the image)
              Positioned(
                top: 180 + 16 + 100, // 50 is an estimated height for CustomHeader, adjust if needed
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).size.height * 0.35, // Adjusted to make room for address display
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 7,
                    ),
                    markers: markers,
                    onTap: _addMarker,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                  ),
                ),
              ),

              // Address Information Display
              if (selectedLocation != null)
                Positioned(
                  top: 180 + 16 + 50 + (MediaQuery.of(context).size.height * 0.35),
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Location Details:',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF05054F),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (city != null)
                              _buildAddressRow('City', city!),
                            if (district != null)
                              _buildAddressRow('District', district!),
                            if (governorate != null)
                              _buildAddressRow('Governorate', governorate!),
                            if (country != null)
                              _buildAddressRow('Country', country!),
                          ],
                        ),
                      ),
                      SizedBox(height: 24), // Add fixed gap between address info and location buttons
                    ],
                  ),
                ),

              // My Location Button
              Positioned(
                top: 180 + 16 + 50 + (MediaQuery.of(context).size.height * 0.35) + 20,
                right: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location, color: Color(0xFF05054F)),
                    onPressed: isLoading ? null : _getCurrentLocation,
                  ),
                ),
              ),

              // Location Buttons
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    // Use Live Location Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0094FF),
                            Color(0xFF05055A),
                            Color(0xFF0094FF),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _getCurrentLocation,
                        icon: isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.location_on, color: Colors.white),
                        label: Text(
                          isLoading ? 'Getting location...' : 'Use live location',
                          style: GoogleFonts.nunito(
                            fontSize: MediaQuery.of(context).size.width < 360 ? 16 : MediaQuery.of(context).size.width < 600 ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),

                    // Use Pinned Location Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0094FF),
                            Color(0xFF05055A),
                            Color(0xFF0094FF),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: selectedLocation == null || isLoading
                            ? null
                            : () => _submitSignup(context),
                        icon: const Icon(Icons.place, color: Colors.white),
                        label: Text(
                          'Use pinned location',
                          style: GoogleFonts.nunito(
                            fontSize: MediaQuery.of(context).size.width < 360 ? 16 : MediaQuery.of(context).size.width < 600 ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32), // Add space under use pinned location button
                  ],
                ),
              ),
              // Loading Indicator (full-screen overlay when loading)
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF05054F),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Make sure to dispose the mapController to prevent memory leaks
    if (mounted && mapController != null) {
      mapController!.dispose();
    }
    super.dispose();
  }
}