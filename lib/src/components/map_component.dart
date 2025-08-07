import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import 'animated_location_marker.dart';

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
        minZoom: 1.0, // Allow zooming out to see the whole world
        maxZoom: 20.0, // Allow higher zoom levels
        onTap: (tapPosition, point) => widget.onMapTap(point),
        // Remove bounds and zoom restrictions
        onMapEvent: (MapEvent event) {
          // No restrictions - allow free movement and zooming
        },
      ),
      children: [
        // High-res MapTiler tiles with optimized configuration
        TileLayer(
          urlTemplate: 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}@2x.png?key=V58lOsvs7pjgLPfRlEB3',
          userAgentPackageName: 'com.BarrimApp.Barirm',
          maxZoom: 20, // Allow higher zoom levels
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
                width: 40, // Reduced from 60 to 40
                height: 40, // Reduced from 60 to 40
                builder: (ctx) => AnimatedLocationMarker(
                  size: 40, // Reduced from 60 to 40
                  color: Colors.blue,
                  isLive: true,
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
      ],
    );
  }


}