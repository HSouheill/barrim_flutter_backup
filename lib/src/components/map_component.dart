import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';

class MapComponent extends StatefulWidget {
  final MapController mapController;
  final LatLng? currentLocation;
  final LatLng? destinationLocation;
  final List<LatLng> primaryRouteCoordinates;
  final List<LatLng> alternativeRouteCoordinates;
  final bool usingPrimaryRoute;
  final List<Marker> wayPointMarkers;
  final Function(LatLng) onMapTap;

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

class _MapComponentState extends State<MapComponent> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isAtMaxZoom = false;

  // Lebanon bounds (approximate coordinates)
  static final LatLngBounds _lebanonBounds = LatLngBounds(
    LatLng(33.0, 34.8), // Southwest corner
    LatLng(34.7, 36.6), // Northeast corner
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Add zoom change listener to prevent exceeding safe limits
    widget.mapController.mapEventStream.listen((event) {
      if (event is MapEventMove) {
        _constrainZoom();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        center: widget.currentLocation ?? const LatLng(33.8938, 35.5018), // Beirut center
        zoom: 14.0, // Balanced zoom for MapTiler high resolution
        minZoom: 8.0, // Keep minimum zoom to prevent zooming out too far
        maxZoom: 18.0, // Safe max zoom for MapTiler tiles - prevents white tiles
        onTap: (tapPosition, point) => widget.onMapTap(point),
        // Add bounds restriction to keep map within Lebanon
        onMapEvent: (MapEvent event) {
          if (event is MapEventMoveEnd) {
            final currentBounds = widget.mapController.bounds;
            if (currentBounds != null) {
              // Check if the current view is within Lebanon bounds
              if (!_isWithinLebanonBounds(currentBounds)) {
                // If outside Lebanon bounds, move back to a valid position
                _constrainToLebanonBounds();
              }
            }
          }
          
          // Lock zoom to prevent white tiles
          if (event is MapEventMove) {
            _constrainZoom();
          }
        },
      ),
      children: [
        // High-res MapTiler tiles with optimized configuration
        TileLayer(
          urlTemplate: 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}@2x.png?key=V58lOsvs7pjgLPfRlEB3',
          userAgentPackageName: 'com.BarrimApp.Barirm',
          maxZoom: 18, // Limit max zoom to prevent white tiles
          tileProvider: NetworkTileProvider(),
          retinaMode: true, // Request high-res tiles on HiDPI screens
        ),
        if (widget.alternativeRouteCoordinates.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.alternativeRouteCoordinates,
                strokeWidth: widget.usingPrimaryRoute ? 2.0 : 4.0,
                color: widget.usingPrimaryRoute
                    ? Colors.purple.withOpacity(0.5)
                    : Colors.purple,
              ),
            ],
          ),
        if (widget.primaryRouteCoordinates.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.primaryRouteCoordinates,
                strokeWidth: widget.usingPrimaryRoute ? 4.0 : 2.0,
                color: widget.usingPrimaryRoute
                    ? Colors.blue
                    : Colors.blue.withOpacity(0.5),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.currentLocation != null)
              Marker(
                point: widget.currentLocation!,
                width: 60,
                height: 60,
                builder: (ctx) => SvgPicture.asset(
                  'assets/icons/your_icon.svg',
                  width: 36,
                  height: 36,
                ),
              ),
            if (widget.destinationLocation != null)
              Marker(
                point: widget.destinationLocation!,
                width: 40,
                height: 40,
                builder: (ctx) => const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            if (widget.usingPrimaryRoute)
              ...widget.wayPointMarkers,
          ],
        ),
      ],
        ),
        // Max zoom indicator
        if (_isAtMaxZoom)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Max Zoom',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Check if the current map bounds are within Lebanon
  bool _isWithinLebanonBounds(LatLngBounds currentBounds) {
    return currentBounds.southWest.latitude >= _lebanonBounds.southWest.latitude &&
           currentBounds.southWest.longitude >= _lebanonBounds.southWest.longitude &&
           currentBounds.northEast.latitude <= _lebanonBounds.northEast.latitude &&
           currentBounds.northEast.longitude <= _lebanonBounds.northEast.longitude;
  }

  // Constrain the map view to Lebanon bounds
  void _constrainToLebanonBounds() {
    final currentCenter = widget.mapController.center;
    final currentZoom = widget.mapController.zoom;
    
    // Calculate constrained center
    double constrainedLat = currentCenter.latitude.clamp(
      _lebanonBounds.southWest.latitude,
      _lebanonBounds.northEast.latitude,
    );
    double constrainedLng = currentCenter.longitude.clamp(
      _lebanonBounds.southWest.longitude,
      _lebanonBounds.northEast.longitude,
    );
    
    // Move to constrained position
    widget.mapController.move(
      LatLng(constrainedLat, constrainedLng),
      currentZoom,
    );
  }
  
  // Constrain zoom to safe limits
  void _constrainZoom() {
    final currentZoom = widget.mapController.zoom;
    if (currentZoom > 18.0) {
      widget.mapController.move(widget.mapController.center, 18.0);
      setState(() {
        _isAtMaxZoom = true;
      });
      
      // Show a brief message to inform user about zoom limit
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum zoom level reached for optimal map quality'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      setState(() {
        _isAtMaxZoom = false;
      });
    }
  }
}