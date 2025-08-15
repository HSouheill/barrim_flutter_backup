import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart' as latlong;

/// A wrapper class that provides the same interface as flutter_map's MapController
/// but uses Google Maps underneath. This makes migration easier.
class GoogleMapsWrapper {
  google_maps.GoogleMapController? _controller;
  final StreamController<MapEvent> _mapEventController = StreamController<MapEvent>.broadcast();
  
  // Current zoom level
  double _currentZoom = 15.0;
  
  // Current center position
  latlong.LatLng _currentCenter = const latlong.LatLng(33.8938, 35.5018); // Beirut default

  /// Stream of map events
  Stream<MapEvent> get mapEventStream => _mapEventController.stream;

  /// Current zoom level
  double get zoom => _currentZoom;

  /// Current center position
  latlong.LatLng get center => _currentCenter;

  /// Set the Google Maps controller
  void setController(google_maps.GoogleMapController controller) {
    _controller = controller;
  }

  /// Move the map to a specific location
  void move(dynamic position, double zoom) {
    if (_controller == null) return;
    
    google_maps.LatLng targetPosition;
    
    // Handle both Google Maps LatLng and latlong2 LatLng
    if (position is google_maps.LatLng) {
      targetPosition = position;
    } else if (position is latlong.LatLng) {
      targetPosition = google_maps.LatLng(position.latitude, position.longitude);
    } else {
      print('Invalid position type: ${position.runtimeType}');
      return;
    }
    
    _controller!.animateCamera(
      google_maps.CameraUpdate.newLatLngZoom(targetPosition, zoom),
    );
    
    _currentCenter = latlong.LatLng(targetPosition.latitude, targetPosition.longitude);
    _currentZoom = zoom;
    
    // Emit move event
    _mapEventController.add(MapEventMove(_currentCenter, _currentZoom));
  }

  /// Fit bounds with padding
  void fitBounds(google_maps.LatLngBounds bounds, {EdgeInsets? padding}) {
    if (_controller == null) return;
    
    _controller!.animateCamera(
      google_maps.CameraUpdate.newLatLngBounds(bounds, padding?.left ?? 50.0),
    );
    
    // Calculate center from bounds
    final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    _currentCenter = latlong.LatLng(centerLat, centerLng);
    
    // Emit move event
    _mapEventController.add(MapEventMove(_currentCenter, _currentZoom));
  }

  /// Dispose resources
  void dispose() {
    _controller = null;
    _mapEventController.close();
  }
}

/// Base class for map events
abstract class MapEvent {}

/// Map move event
class MapEventMove extends MapEvent {
  final latlong.LatLng center;
  final double zoom;
  
  MapEventMove(this.center, this.zoom);
}

/// Map move end event
class MapEventMoveEnd extends MapEvent {
  final latlong.LatLng center;
  final double zoom;
  
  MapEventMoveEnd(this.center, this.zoom);
}
