import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart' as latlong;
import 'google_maps_wrapper.dart';
import 'animated_location_marker.dart';

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

  void _onMapCreated(google_maps.GoogleMapController controller) {
    _googleMapController = controller;
    
    // Set the controller in our wrapper
    widget.mapController.setController(controller);
    
    // Move to current location if available
    if (widget.currentLocation != null) {
      controller.animateCamera(
        google_maps.CameraUpdate.newLatLngZoom(
          google_maps.LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude),
          15.0,
        ),
      );
    }
  }

  Set<google_maps.Marker> _buildGoogleMarkers() {
    final Set<google_maps.Marker> markers = {};

    // Note: Current location marker removed - using AnimatedLocationMarker overlay instead

    // Add destination marker
    if (widget.destinationLocation != null) {
      markers.add(
        google_maps.Marker(
          markerId: google_maps.MarkerId('destination'),
          position: google_maps.LatLng(widget.destinationLocation!.latitude, widget.destinationLocation!.longitude),
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueRed),
          infoWindow: google_maps.InfoWindow(title: 'Destination'),
        ),
      );
    }

    // Add waypoint markers - handle both flutter_map and Google Maps marker types
    for (int i = 0; i < widget.wayPointMarkers.length; i++) {
      final marker = widget.wayPointMarkers[i];
      
      // Extract position from different marker types
      latlong.LatLng? position;
      if (marker is google_maps.Marker) {
        // Google Maps marker
        position = latlong.LatLng(marker.position.latitude, marker.position.longitude);
      } else {
        // flutter_map marker - try to extract point property
        try {
          // Use reflection or dynamic access to get the point property
          if (marker is Map) {
            final point = marker['point'];
            if (point != null) {
              position = latlong.LatLng(point['latitude'], point['longitude']);
            }
          } else {
            // Try to access point property dynamically
            final point = (marker as dynamic).point;
            if (point != null) {
              position = latlong.LatLng(point.latitude, point.longitude);
            }
          }
        } catch (e) {
          print('Error extracting position from marker: $e');
          continue;
        }
      }
      
      if (position != null) {
        markers.add(
          google_maps.Marker(
            markerId: google_maps.MarkerId('waypoint_$i'),
            position: google_maps.LatLng(position.latitude, position.longitude),
            icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(google_maps.BitmapDescriptor.hueGreen),
            onTap: () {
              // Handle marker tap if needed
            },
          ),
        );
      }
    }

    return markers;
  }

  Set<google_maps.Polyline> _buildGooglePolylines() {
    final Set<google_maps.Polyline> polylines = {};

    // Add primary route
    if (widget.primaryRouteCoordinates.isNotEmpty) {
      polylines.add(
        google_maps.Polyline(
          polylineId: google_maps.PolylineId('primary_route'),
          points: widget.primaryRouteCoordinates
              .map((point) => google_maps.LatLng(point.latitude, point.longitude))
              .toList(),
          color: widget.usingPrimaryRoute ? Colors.blue : Colors.blue.withOpacity(0.5),
          width: widget.usingPrimaryRoute ? 4 : 2,
        ),
      );
    }

    // Add alternative route
    if (widget.alternativeRouteCoordinates.isNotEmpty) {
      polylines.add(
        google_maps.Polyline(
          polylineId: google_maps.PolylineId('alternative_route'),
          points: widget.alternativeRouteCoordinates
              .map((point) => google_maps.LatLng(point.latitude, point.longitude))
              .toList(),
          color: widget.usingPrimaryRoute ? Colors.purple.withOpacity(0.5) : Colors.purple,
          width: widget.usingPrimaryRoute ? 2 : 4,
        ),
      );
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        google_maps.GoogleMap(
          onMapCreated: (google_maps.GoogleMapController controller) {
            _onMapCreated(controller);
            // Apply custom styling to hide Google's business data
            _applyCustomMapStyle(controller);
          },
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
        ),
        

      ],
    );
  }



  void _applyCustomMapStyle(google_maps.GoogleMapController controller) {
    // Soft custom map style with decreased contrast and white streets
    const String customMapStyle = '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.attraction",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.government",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.medical",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.place_of_worship",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.school",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.sports_complex",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit.line",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit.station",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road.local",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "road.local",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#f8f9fa"
          }
        ]
      },
      {
        "featureType": "landscape.natural",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#e8f5e8"
          }
        ]
      },
      {
        "featureType": "landscape.man_made",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#f5f5f5"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#b3d9ff"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#d4edda"
          }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#fff8e1"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffeaa7"
          }
        ]
      }
    ]
    ''';

    try {
      controller.setMapStyle(customMapStyle);
      print('Soft map style applied successfully - Decreased contrast with white streets');
    } catch (e) {
      print('Error applying soft map style: $e');
    }
  }
}