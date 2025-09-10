import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart' as latlong;
import 'google_maps_wrapper.dart';
import 'animated_location_marker.dart';
import '../services/google_maps_service.dart';

class MapComponent extends StatefulWidget {
  final GoogleMapsWrapper mapController;
  final latlong.LatLng? currentLocation;
  final latlong.LatLng? destinationLocation;
  final List<latlong.LatLng> primaryRouteCoordinates;
  final List<latlong.LatLng> alternativeRouteCoordinates;
  final bool usingPrimaryRoute;
  final List<dynamic> wayPointMarkers; // Keep as dynamic to work with existing code
  final Function(latlong.LatLng) onMapTap;

  const MapComponent({
    Key? key,
    required this.mapController,
    required this.currentLocation,
    required this.destinationLocation,
    required this.primaryRouteCoordinates,
    required this.alternativeRouteCoordinates,
    required this.usingPrimaryRoute,
    required this.wayPointMarkers,
    required this.onMapTap,
  }) : super(key: key);

  @override
  State<MapComponent> createState() => _MapComponentState();
}

class _MapComponentState extends State<MapComponent> {
  google_maps.GoogleMapController? _googleMapController;
  bool _isMapReady = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ensureMapReady();
  }

  Future<void> _ensureMapReady() async {
    try {
      // Wait for Google Maps services to be ready
      final isReady = await GoogleMapsService.waitForServices(timeoutSeconds: 15);
      
      if (mounted) {
        setState(() {
          _isMapReady = isReady;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error ensuring map readiness: $e');
      if (mounted) {
        setState(() {
          _isMapReady = false;
          _isLoading = false;
        });
      }
    }
  }

  void _onMapCreated(google_maps.GoogleMapController controller) {
    try {
      _googleMapController = controller;
      
      // Set the controller in our wrapper
      widget.mapController.setController(controller);
      
      // Apply custom map style to hide all places
      _applyCustomMapStyle(controller);
      
      // Move to current location if available
      if (widget.currentLocation != null) {
        controller.animateCamera(
          google_maps.CameraUpdate.newLatLngZoom(
            google_maps.LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude),
            15.0,
          ),
        );
      }
    } catch (e) {
      print('Error in _onMapCreated: $e');
    }
  }

  Set<google_maps.Marker> _buildGoogleMarkers() {
    final Set<google_maps.Marker> markers = {};
    
    print('MapComponent: Building markers, total waypoint markers: ${widget.wayPointMarkers.length}');
    print('MapComponent: Waypoint marker types: ${widget.wayPointMarkers.map((m) => m.runtimeType).toList()}');

    // Note: Current location marker removed - using AnimatedLocationMarker overlay instead

    // Add destination marker
    if (widget.destinationLocation != null) {
      markers.add(
        google_maps.Marker(
          markerId: google_maps.MarkerId('destination'),
          position: google_maps.LatLng(widget.destinationLocation!.latitude, widget.destinationLocation!.longitude),
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed),
          infoWindow: google_maps.InfoWindow(title: 'Destination'),
          visible: true, // Ensure destination marker is always visible
        ),
      );
    }

    // Add waypoint markers - handle both Map<String, dynamic> and google_maps.Marker objects
    for (int i = 0; i < widget.wayPointMarkers.length; i++) {
      final marker = widget.wayPointMarkers[i];
      print('MapComponent: Processing marker $i: ${marker.runtimeType}');
      
      if (marker is google_maps.Marker) {
        print('MapComponent: Found google_maps.Marker with ID: ${marker.markerId.value}');
        print('MapComponent: Marker position: ${marker.position}');
        print('MapComponent: Marker visible: ${marker.visible}');
        // If it's already a google_maps.Marker, use it directly
        // Create a new marker with the same properties but ensure visibility
        markers.add(
          google_maps.Marker(
            markerId: marker.markerId,
            position: marker.position,
            icon: marker.icon,
            infoWindow: marker.infoWindow,
            visible: true, // Ensure marker is always visible
            onTap: marker.onTap,
            consumeTapEvents: marker.consumeTapEvents,
            anchor: marker.anchor,
            draggable: marker.draggable,
            flat: marker.flat,
            rotation: marker.rotation,
            zIndex: marker.zIndex,
          ),
        );
        print('MapComponent: Added google_maps.Marker to markers set');
      } else if (marker is Map<String, dynamic> && marker['position'] != null) {
        // Legacy support for Map format
        final position = marker['position'] as latlong.LatLng;
        final category = marker['category'] as String?;
        
        // Get marker color based on category
        google_maps.BitmapDescriptor markerIcon;
        if (category != null && _categoryColors.containsKey(category)) {
          markerIcon = google_maps.BitmapDescriptor.defaultMarkerWithHue(_categoryColors[category]!);
        } else {
          markerIcon = google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueBlue);
        }
        
        markers.add(
          google_maps.Marker(
            markerId: google_maps.MarkerId('waypoint_$i'),
            position: google_maps.LatLng(position.latitude, position.longitude),
            icon: markerIcon,
            infoWindow: google_maps.InfoWindow(
              title: marker['title'] ?? 'Waypoint $i',
              snippet: category ?? 'Unknown category',
            ),
            visible: true, // Ensure marker is always visible
          ),
        );
      }
    }

    print('MapComponent: Final markers count: ${markers.length}');
    print('MapComponent: Final marker IDs: ${markers.map((m) => m.markerId.value).toList()}');
    return markers;
  }

  // Category colors for markers
  static const Map<String, double> _categoryColors = {
    'restaurant': google_maps.BitmapDescriptor.hueRed,
    'cafe': google_maps.BitmapDescriptor.hueOrange,
    'shopping': google_maps.BitmapDescriptor.hueYellow,
    'entertainment': google_maps.BitmapDescriptor.hueGreen,
    'health': google_maps.BitmapDescriptor.hueBlue,
    'transport': google_maps.BitmapDescriptor.hueViolet,
    'other': google_maps.BitmapDescriptor.hueAzure,
  };

  Set<google_maps.Polyline> _buildGooglePolylines() {
    final Set<google_maps.Polyline> polylines = {};

    // Primary route
    if (widget.primaryRouteCoordinates.isNotEmpty) {
      final googleCoordinates = widget.primaryRouteCoordinates.map((coord) {
        return google_maps.LatLng(coord.latitude, coord.longitude);
      }).toList();

      polylines.add(
        google_maps.Polyline(
          polylineId: const google_maps.PolylineId('primary_route'),
          points: googleCoordinates,
          color: widget.usingPrimaryRoute ? Colors.blue : Colors.grey,
          width: 5,
        ),
      );
    }

    // Alternative route
    if (widget.alternativeRouteCoordinates.isNotEmpty) {
      final googleCoordinates = widget.alternativeRouteCoordinates.map((coord) {
        return google_maps.LatLng(coord.latitude, coord.longitude);
      }).toList();

      polylines.add(
        google_maps.Polyline(
          polylineId: const google_maps.PolylineId('alternative_route'),
          points: googleCoordinates,
          color: widget.usingPrimaryRoute ? Colors.grey : Colors.purple,
          width: 5,
        ),
      );
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking map readiness
    if (_isLoading) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading map...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Check if Google Maps services are available
    if (!_isMapReady || !GoogleMapsService.isInitialized) {
      return GoogleMapsService.getFallbackWidget(
        message: 'Google Maps are not available.\nPlease try again later.',
        backgroundColor: Colors.grey[100]!,
        textColor: Colors.grey[600]!,
      );
    }

    return Stack(
      children: [
        // Try to create the map safely
        GoogleMapsService.createSafeGoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: google_maps.CameraPosition(
            target: widget.currentLocation != null 
                ? google_maps.LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude)
                : const google_maps.LatLng(33.8938, 35.5018), // Beirut, Lebanon center
            zoom: 12.0, // Slightly zoomed out to show more of Lebanon
          ),
          markers: _buildGoogleMarkers(),
          polylines: _buildGooglePolylines(),
          onTap: (google_maps.LatLng position) {
            // Convert Google Maps LatLng to our LatLng format
            final latLng = latlong.LatLng(position.latitude, position.longitude);
            widget.onMapTap(latLng);
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // We'll use our custom button
          zoomControlsEnabled: false, // We'll use our custom controls
          mapType: google_maps.MapType.normal,
          // mapType: google_maps.MapType.satellite,
          compassEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          // Custom styling to show only streets and hide business data
          mapToolbarEnabled: false, // Disable map toolbar
          trafficEnabled: false, // Disable traffic data
          buildingsEnabled: false, // Disable 3D buildings
          indoorViewEnabled: false, // Disable indoor maps
        ) ?? GoogleMapsService.getFallbackWidget(
          message: 'Failed to load map.\nPlease try again.',
          backgroundColor: Colors.red[50]!,
          textColor: Colors.red[700]!,
        ),
      ],
    );
  }

  void _applyCustomMapStyle(google_maps.GoogleMapController controller) {
    // Custom map styling to hide ALL places and business data
    const String customMapStyle = '''
    [
      {
        "featureType": "poi",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.attraction",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.government",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.medical",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.place_of_worship",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.school",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.sports_complex",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit.line",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit.station",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      }
    ]
    ''';

    controller.setMapStyle(customMapStyle);
  }
}