import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapComponent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        center: currentLocation ?? const LatLng(33.8938, 35.5018),
        zoom: 14.0,
        onTap: (tapPosition, point) => onMapTap(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.app',
        ),
        if (alternativeRouteCoordinates.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: alternativeRouteCoordinates,
                strokeWidth: usingPrimaryRoute ? 2.0 : 4.0,
                color: usingPrimaryRoute
                    ? Colors.purple.withOpacity(0.5)
                    : Colors.purple,
              ),
            ],
          ),
        if (primaryRouteCoordinates.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: primaryRouteCoordinates,
                strokeWidth: usingPrimaryRoute ? 4.0 : 2.0,
                color: usingPrimaryRoute
                    ? Colors.blue
                    : Colors.blue.withOpacity(0.5),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (currentLocation != null)
              Marker(
                point: currentLocation!,
                width: 40,
                height: 40,
                builder: (ctx) => Container(
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.blue,
                    size: 30,
                  ),
                ),
              ),
            if (destinationLocation != null)
              Marker(
                point: destinationLocation!,
                width: 40,
                height: 40,
                builder: (ctx) => const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            if (usingPrimaryRoute)
              ...wayPointMarkers,
          ],
        ),
      ],
    );
  }
}