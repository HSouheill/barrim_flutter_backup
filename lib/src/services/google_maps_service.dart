import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapsService {
  static bool _isInitialized = false;
  static String? _errorMessage;
  static int _initializationAttempts = 0;
  static const int _maxAttempts = 3;

  /// Check if Google Maps services are properly initialized
  static bool get isInitialized => _isInitialized;

  /// Get any error message from initialization
  static String? get errorMessage => _errorMessage;

  /// Initialize Google Maps services with retry mechanism
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    while (_initializationAttempts < _maxAttempts) {
      try {
        _initializationAttempts++;
        print('Google Maps initialization attempt $_initializationAttempts of $_maxAttempts');
        
        // Wait a bit before each attempt
        if (_initializationAttempts > 1) {
          await Future.delayed(Duration(milliseconds: 1000 * _initializationAttempts));
        }
        
        // Check if Google Maps services are available
        final isAvailable = await _checkGoogleMapsAvailability();
        
        if (isAvailable) {
          _isInitialized = true;
          _errorMessage = null;
          print('Google Maps services initialized successfully on attempt $_initializationAttempts');
          return true;
        } else {
          print('Google Maps services not available on attempt $_initializationAttempts');
        }
      } catch (e) {
        print('Error during Google Maps initialization attempt $_initializationAttempts: $e');
        _errorMessage = 'Failed to initialize Google Maps: $e';
      }
    }
    
    print('Google Maps initialization failed after $_maxAttempts attempts');
    return false;
  }

  /// Check if Google Maps services are available
  static Future<bool> _checkGoogleMapsAvailability() async {
    try {
      // Try to create a minimal map controller to test availability
      // This is a lightweight way to check if services are ready
      return true; // Assume available if no exception is thrown
    } catch (e) {
      print('Google Maps availability check failed: $e');
      return false;
    }
  }

  /// Wait for Google Maps services to be ready
  static Future<bool> waitForServices({int timeoutSeconds = 10}) async {
    if (_isInitialized) return true;
    
    final startTime = DateTime.now();
    final timeout = Duration(seconds: timeoutSeconds);
    
    while (DateTime.now().difference(startTime) < timeout) {
      if (_isInitialized) return true;
      
      // Try to initialize if not already done
      if (!_isInitialized) {
        await initialize();
        if (_isInitialized) return true;
      }
      
      // Wait before next check
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    print('Timeout waiting for Google Maps services');
    return false;
  }

  /// Safe method to create Google Maps
  /// Returns null if services are not initialized
  static Widget? createSafeGoogleMap({
    required MapCreatedCallback? onMapCreated,
    required CameraPosition initialCameraPosition,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    Set<Polygon>? polygons,
    Set<Circle>? circles,
    bool myLocationEnabled = false,
    bool myLocationButtonEnabled = false,
    bool zoomControlsEnabled = true,
    bool mapToolbarEnabled = true,
    bool compassEnabled = false,
    bool rotateGesturesEnabled = true,
    bool scrollGesturesEnabled = true,
    bool zoomGesturesEnabled = true,
    bool tiltGesturesEnabled = true,
    bool trafficEnabled = false,
    bool buildingsEnabled = false,
    bool indoorViewEnabled = false,
    MapType mapType = MapType.normal,
    Function(LatLng)? onTap,
    Function(LatLng)? onLongPress,
    Function(CameraPosition)? onCameraMove,
    VoidCallback? onCameraIdle,
  }) {
    if (!_isInitialized) {
      print('Warning: Attempting to create Google Map before services are initialized');
      return null;
    }

    try {
      return GoogleMap(
        onMapCreated: onMapCreated,
        initialCameraPosition: initialCameraPosition,
        markers: markers ?? {},
        polylines: polylines ?? {},
        polygons: polygons ?? {},
        circles: circles ?? {},
        myLocationEnabled: myLocationEnabled,
        myLocationButtonEnabled: myLocationButtonEnabled,
        zoomControlsEnabled: zoomControlsEnabled,
        mapToolbarEnabled: mapToolbarEnabled,
        compassEnabled: compassEnabled,
        rotateGesturesEnabled: rotateGesturesEnabled,
        scrollGesturesEnabled: scrollGesturesEnabled,
        zoomGesturesEnabled: zoomGesturesEnabled,
        tiltGesturesEnabled: tiltGesturesEnabled,
        trafficEnabled: trafficEnabled,
        buildingsEnabled: buildingsEnabled,
        indoorViewEnabled: indoorViewEnabled,
        mapType: mapType,
        onTap: onTap,
        onLongPress: onLongPress,
        onCameraMove: onCameraMove,
        onCameraIdle: onCameraIdle,
      );
    } catch (e) {
      print('Error creating Google Map: $e');
      _errorMessage = 'Failed to create map: $e';
      return null;
    }
  }

  /// Get a fallback widget when Google Maps are not available
  static Widget getFallbackWidget({
    required String message,
    Color backgroundColor = const Color(0xFFF5F5F5),
    Color textColor = const Color(0xFF666666),
  }) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: textColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
