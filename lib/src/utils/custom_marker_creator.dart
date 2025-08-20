import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;

/// Different marker shapes available
enum MarkerShape {
  teardrop,    // Classic teardrop/pin shape
  circle,      // Perfect circle
  square,      // Square with rounded corners
  diamond,     // Diamond/rhombus shape
  hexagon,     // Hexagonal shape
  star,        // Star shape
  triangle,    // Triangle pointing down
  rounded,     // Rounded rectangle
}

class CustomMarkerCreator {
  // Cache for created markers to avoid recreating them
  static final Map<String, google_maps.BitmapDescriptor> _markerCache = {};
  
  /// Creates a custom marker with background color and icon overlay
  /// 
  /// [backgroundColor] - The background color of the marker (e.g., Colors.blue)
  /// [iconPath] - Path to the icon asset (e.g., 'assets/icons/restaurant.png')
  /// [iconColor] - Color to tint the icon (optional)
  /// [size] - Size of the marker (default: 80x80)
  /// [borderColor] - Border color of the marker (optional)
  /// [borderWidth] - Border width (default: 2.0)
  /// [shape] - Shape of the marker (default: MarkerShape.teardrop)
  static Future<google_maps.BitmapDescriptor> createCustomMarker({
    required Color backgroundColor,
    String? iconPath,
    Color? iconColor,
    double size = 80.0,
    Color? borderColor,
    double borderWidth = 2.0,
    MarkerShape shape = MarkerShape.teardrop,
  }) async {
    // Create cache key
    final cacheKey = '${backgroundColor.value}_${iconPath ?? "no_icon"}_${iconColor?.value ?? "no_tint"}_${size}_${borderColor?.value ?? "no_border"}_${borderWidth}_${shape.name}';
    
    // Return cached marker if available
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }
    
    try {
      // Create the marker image
      final Uint8List markerBytes = await _createMarkerImage(
        backgroundColor: backgroundColor,
        iconPath: iconPath,
        iconColor: iconColor,
        size: size,
        borderColor: borderColor,
        borderWidth: borderWidth,
        shape: shape,
      );
      
      // Create BitmapDescriptor
      final marker = google_maps.BitmapDescriptor.fromBytes(markerBytes);
      
      // Cache the marker
      _markerCache[cacheKey] = marker;
      
      return marker;
    } catch (e) {
      print('Error creating custom marker: $e');
      // Fallback to default marker with background color
      return _createFallbackMarker(backgroundColor);
    }
  }
  
  /// Creates a category-based marker with dynamic colors and icons
  static Future<google_maps.BitmapDescriptor> createCategoryMarker({
    required String categoryName,
    required Color categoryColor,
    String? categoryIconPath,
    double size = 80.0,
    bool useGradient = true,
  }) async {
    return createCustomMarker(
      backgroundColor: categoryColor,
      iconPath: categoryIconPath,
      iconColor: Colors.white,
      size: size,
      borderColor: Colors.white,
      borderWidth: 2.0,
    );
  }
  
  /// Creates a business marker with company logo and brand colors
  static Future<google_maps.BitmapDescriptor> createBusinessMarker({
    required Color brandColor,
    String? logoPath,
    double size = 80.0,
  }) async {
    return createCustomMarker(
      backgroundColor: brandColor,
      iconPath: logoPath,
      iconColor: Colors.white,
      size: size,
      borderColor: Colors.white,
      borderWidth: 2.0,
    );
  }
  
  /// Creates a location marker with custom styling
  static Future<google_maps.BitmapDescriptor> createLocationMarker({
    required Color markerColor,
    IconData? icon,
    Color? iconColor,
    double size = 80.0,
  }) async {
    // Convert IconData to custom path if needed
    String? iconPath;
    if (icon != null) {
      iconPath = _getIconPathFromIconData(icon);
    }
    
    return createCustomMarker(
      backgroundColor: markerColor,
      iconPath: iconPath,
      iconColor: iconColor ?? Colors.white,
      size: size,
      borderColor: Colors.white,
      borderWidth: 2.0,
    );
  }
  
  /// Creates the actual marker image using Flutter's Canvas
  static Future<Uint8List> _createMarkerImage({
    required Color backgroundColor,
    String? iconPath,
    Color? iconColor,
    required double size,
    Color? borderColor,
    required double borderWidth,
    required MarkerShape shape,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    
    // Calculate dimensions based on shape
    final double markerWidth = size;
    final double markerHeight = _getMarkerHeight(size, shape);
    
    // Create marker path based on selected shape
    final markerPath = _createShapePath(markerWidth, markerHeight, borderWidth, shape);
    
    // Draw background
    paint.color = backgroundColor;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(markerPath, paint);
    
    // Draw border if specified
    if (borderColor != null && borderWidth > 0) {
      paint.color = borderColor;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = borderWidth;
      canvas.drawPath(markerPath, paint);
    }
    
    // Draw icon if provided
    if (iconPath != null) {
      try {
        final iconData = await _loadIconData(iconPath);
        if (iconData != null) {
          final iconSize = markerWidth * 0.4; // Icon takes 40% of marker width
          final iconX = (markerWidth - iconSize) / 2;
          final iconY = (markerHeight - iconSize) / 2;
          
          // Create icon paint
          final iconPaint = Paint();
          if (iconColor != null) {
            iconPaint.colorFilter = ColorFilter.mode(iconColor, BlendMode.srcIn);
          }
          
          // Draw icon
          canvas.drawImageRect(
            iconData,
            Rect.fromLTWH(0, 0, iconData.width.toDouble(), iconData.height.toDouble()),
            Rect.fromLTWH(iconX, iconY, iconSize, iconSize),
            iconPaint,
          );
        }
      } catch (e) {
        print('Error drawing icon: $e');
      }
    }
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  /// Get marker height based on shape
  static double _getMarkerHeight(double size, MarkerShape shape) {
    switch (shape) {
      case MarkerShape.teardrop:
        return size * 1.2; // Teardrop is taller
      case MarkerShape.circle:
        return size; // Circle is square
      case MarkerShape.square:
        return size; // Square is square
      case MarkerShape.diamond:
        return size; // Diamond is square
      case MarkerShape.hexagon:
        return size; // Hexagon is square
      case MarkerShape.star:
        return size; // Star is square
      case MarkerShape.triangle:
        return size * 1.2; // Triangle is taller
      case MarkerShape.rounded:
        return size; // Rounded rectangle is square
    }
  }

  /// Create shape path based on selected shape
  static Path _createShapePath(double width, double height, double borderWidth, MarkerShape shape) {
    final path = Path();
    
    switch (shape) {
      case MarkerShape.teardrop:
        return _createTeardropPath(width, height, borderWidth);
      case MarkerShape.circle:
        return _createCirclePath(width, height, borderWidth);
      case MarkerShape.square:
        return _createSquarePath(width, height, borderWidth);
      case MarkerShape.diamond:
        return _createDiamondPath(width, height, borderWidth);
      case MarkerShape.hexagon:
        return _createHexagonPath(width, height, borderWidth);
      case MarkerShape.star:
        return _createStarPath(width, height, borderWidth);
      case MarkerShape.triangle:
        return _createTrianglePath(width, height, borderWidth);
      case MarkerShape.rounded:
        return _createRoundedPath(width, height, borderWidth);
    }
  }

  /// Create teardrop/pin shape path
  static Path _createTeardropPath(double width, double height, double borderWidth) {
    final path = Path();
    
    // Top circle
    path.addOval(Rect.fromCircle(
      center: Offset(width / 2, width / 2),
      radius: (width - borderWidth * 2) / 2,
    ));
    
    // Bottom triangle
    final triangleHeight = height - width;
    path.moveTo(borderWidth, width / 2);
    path.lineTo(width / 2, height - borderWidth);
    path.lineTo(width - borderWidth, width / 2);
    path.close();
    
    return path;
  }

  /// Create circle shape path
  static Path _createCirclePath(double width, double height, double borderWidth) {
    final path = Path();
    path.addOval(Rect.fromCircle(
      center: Offset(width / 2, height / 2),
      radius: (width - borderWidth * 2) / 2,
    ));
    return path;
  }

  /// Create square shape path
  static Path _createSquarePath(double width, double height, double borderWidth) {
    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(borderWidth, borderWidth, width - borderWidth * 2, height - borderWidth * 2),
      Radius.circular(8.0),
    ));
    return path;
  }

  /// Create diamond shape path
  static Path _createDiamondPath(double width, double height, double borderWidth) {
    final path = Path();
    final centerX = width / 2;
    final centerY = height / 2;
    final halfSize = (width - borderWidth * 2) / 2;
    
    path.moveTo(centerX, centerY - halfSize);
    path.lineTo(centerX + halfSize, centerY);
    path.lineTo(centerX, centerY + halfSize);
    path.lineTo(centerX - halfSize, centerY);
    path.close();
    
    return path;
  }

  /// Create hexagon shape path
  static Path _createHexagonPath(double width, double height, double borderWidth) {
    final path = Path();
    final centerX = width / 2;
    final centerY = height / 2;
    final radius = (width - borderWidth * 2) / 2;
    
    for (int i = 0; i < 6; i++) {
      final angle = i * 60 * pi / 180;
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    return path;
  }

  /// Create star shape path
  static Path _createStarPath(double width, double height, double borderWidth) {
    final path = Path();
    final centerX = width / 2;
    final centerY = height / 2;
    final outerRadius = (width - borderWidth * 2) / 2;
    final innerRadius = outerRadius * 0.4;
    
    for (int i = 0; i < 10; i++) {
      final angle = i * 36 * pi / 180;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    return path;
  }

  /// Create triangle shape path
  static Path _createTrianglePath(double width, double height, double borderWidth) {
    final path = Path();
    final centerX = width / 2;
    final halfWidth = (width - borderWidth * 2) / 2;
    
    path.moveTo(centerX, borderWidth);
    path.lineTo(centerX + halfWidth, height - borderWidth);
    path.lineTo(centerX - halfWidth, height - borderWidth);
    path.close();
    
    return path;
  }

  /// Create rounded rectangle path
  static Path _createRoundedPath(double width, double height, double borderWidth) {
    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(borderWidth, borderWidth, width - borderWidth * 2, height - borderWidth * 2),
      Radius.circular(16.0),
    ));
    return path;
  }
  
  /// Loads icon data from asset path
  static Future<ui.Image?> _loadIconData(String iconPath) async {
    try {
      if (iconPath.startsWith('http')) {
        // Handle network images - you might want to implement caching here
        print('Network images not supported for custom markers yet');
        return null;
      } else {
        // Load from assets
        final ByteData data = await rootBundle.load(iconPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        return frame.image;
      }
    } catch (e) {
      print('Error loading icon: $e');
      return null;
    }
  }
  
  /// Converts IconData to asset path (you can extend this for common icons)
  static String? _getIconPathFromIconData(IconData icon) {
    // Map common icons to asset paths
    final iconMap = {
      Icons.restaurant: 'assets/icons/restaurant.png',
      Icons.hotel: 'assets/icons/hotel.png',
      Icons.local_gas_station: 'assets/icons/gas_station.png',
      Icons.shopping_cart: 'assets/icons/shop.png',
      Icons.local_hospital: 'assets/icons/hospital.png',
      Icons.school: 'assets/icons/school.png',
      Icons.church: 'assets/icons/church.png',
      Icons.local_parking: 'assets/icons/parking.png',
      Icons.local_pharmacy: 'assets/icons/pharmacy.png',
      Icons.account_balance: 'assets/icons/bank.png',
    };
    
    return iconMap[icon];
  }
  
  /// Creates a fallback marker when custom creation fails
  static google_maps.BitmapDescriptor _createFallbackMarker(Color color) {
    // Convert color to hue for Google's default markers
    final hue = _colorToHue(color);
    return google_maps.BitmapDescriptor.defaultMarkerWithHue(hue);
  }
  
  /// Converts Color to Google Maps hue value
  static double _colorToHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }
  
  /// Clears the marker cache (useful for memory management)
  static void clearCache() {
    _markerCache.clear();
  }
  
  /// Gets cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedMarkers': _markerCache.length,
      'cacheKeys': _markerCache.keys.toList(),
    };
  }
}
