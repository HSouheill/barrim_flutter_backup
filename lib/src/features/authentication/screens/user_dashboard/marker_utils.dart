import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:async';

class MarkerUtils {
  // Cache for marker bitmaps to avoid recreating them
  static final Map<String, Future<google_maps.BitmapDescriptor>> _markerCache = {};

  // Create a custom marker with icon and background color
  static Future<google_maps.BitmapDescriptor> createCustomMarker({
    required String iconAssetPath,
    required Color backgroundColor,
    String? label,
    Color labelColor = Colors.white,
    double iconSize = 24.0,
    double markerSize = 48.0,
  }) async {
    final cacheKey = '$iconAssetPath-${backgroundColor.value}-$label';
    
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    final completer = Completer<google_maps.BitmapDescriptor>();
    _markerCache[cacheKey] = completer.future;

    try {
      // Load the icon image
      final ByteData iconData = await rootBundle.load(iconAssetPath);
      final ui.Codec iconCodec = await ui.instantiateImageCodec(
        iconData.buffer.asUint8List(),
        targetWidth: iconSize.toInt(),
      );
      final ui.FrameInfo iconFrame = await iconCodec.getNextFrame();
      final ui.Image iconImage = iconFrame.image;

      // Create a picture recorder
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Draw the marker background (circle)
      final Paint backgroundPaint = Paint()..color = backgroundColor;
      final double center = markerSize / 2;
      final double radius = markerSize / 2;

      // Draw the circle background
      canvas.drawCircle(Offset(center, center), radius, backgroundPaint);

      // Draw the icon in the center
      final double iconX = center - (iconSize / 2);
      final double iconY = center - (iconSize / 2);
      canvas.drawImage(iconImage, Offset(iconX, iconY), Paint());

      // Draw label if provided
      if (label != null && label.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final double textX = center - (textPainter.width / 2);
        final double textY = center + (iconSize / 2) + 2;
        textPainter.paint(canvas, Offset(textX, textY));
      }

      // Convert to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image markerImage = await picture.toImage(
        markerSize.toInt(),
        markerSize.toInt(),
      );

      // Convert to byte data
      final ByteData? byteData = await markerImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final Uint8List bytes = byteData.buffer.asUint8List();
        final bitmapDescriptor = google_maps.BitmapDescriptor.fromBytes(bytes);
        completer.complete(bitmapDescriptor);
        return bitmapDescriptor;
      } else {
        throw Exception('Failed to create marker image');
      }
    } catch (e) {
      completer.completeError(e);
      _markerCache.remove(cacheKey);
      // Fallback to default marker
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(
        google_maps.BitmapDescriptor.hueBlue,
      );
    }
  }

  // Create a colored marker with text (for categories)
  static Future<google_maps.BitmapDescriptor> createCategoryMarker({
    required Color color,
    required String text,
    Color textColor = Colors.white,
    double size = 40.0,
  }) async {
    final cacheKey = 'category-$text-${color.value}';
    
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    final completer = Completer<google_maps.BitmapDescriptor>();
    _markerCache[cacheKey] = completer.future;

    try {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Draw background circle
      final Paint backgroundPaint = Paint()..color = color;
      final double center = size / 2;
      final double radius = size / 2;

      canvas.drawCircle(Offset(center, center), radius, backgroundPaint);

      // Draw white border
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawCircle(Offset(center, center), radius - 1, borderPaint);

      // Draw text
      final textPainter = TextPainter(
        text: TextSpan(
          text: text.length > 2 ? text.substring(0, 2) : text,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final double textX = center - (textPainter.width / 2);
      final double textY = center - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(textX, textY));

      // Convert to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image markerImage = await picture.toImage(
        size.toInt(),
        size.toInt(),
      );

      final ByteData? byteData = await markerImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final Uint8List bytes = byteData.buffer.asUint8List();
        final bitmapDescriptor = google_maps.BitmapDescriptor.fromBytes(bytes);
        completer.complete(bitmapDescriptor);
        return bitmapDescriptor;
      } else {
        throw Exception('Failed to create category marker');
      }
    } catch (e) {
      completer.completeError(e);
      _markerCache.remove(cacheKey);
      return google_maps.BitmapDescriptor.defaultMarkerWithHue(
        google_maps.BitmapDescriptor.hueBlue,
      );
    }
  }

  // Clear cache (useful when memory is low)
  static void clearCache() {
    _markerCache.clear();
  }
}