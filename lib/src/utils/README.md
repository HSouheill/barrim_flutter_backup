# Custom Marker Creator

The `CustomMarkerCreator` utility class provides a powerful way to create custom map markers with both colors and icons for Google Maps in Flutter.

## Features

- **Custom Background Colors**: Set any color for your marker background
- **Icon Support**: Add custom icons to your markers
- **Icon Tinting**: Apply color filters to your icons
- **Border Customization**: Add borders with custom colors and widths
- **Size Control**: Adjust marker size as needed
- **Caching**: Built-in caching to improve performance
- **Fallback Support**: Graceful fallback to Google's default markers if custom creation fails

## Basic Usage

### 1. Simple Colored Marker

```dart
import 'package:your_app/src/utils/custom_marker_creator.dart';

// Create a simple red marker
final marker = await CustomMarkerCreator.createCustomMarker(
  backgroundColor: Colors.red,
  size: 80.0,
);

// Use it in a Google Maps marker
google_maps.Marker(
  markerId: google_maps.MarkerId('my_marker'),
  position: google_maps.LatLng(lat, lng),
  icon: marker,
);
```

### 2. Marker with Icon

```dart
// Create a marker with background color and icon
final marker = await CustomMarkerCreator.createCustomMarker(
  backgroundColor: Colors.blue,
  iconPath: 'assets/icons/restaurant.png',
  iconColor: Colors.white,
  size: 80.0,
  borderColor: Colors.white,
  borderWidth: 2.0,
);
```

### 3. Category-Based Marker

```dart
// Create a marker for a specific category
final marker = await CustomMarkerCreator.createCategoryMarker(
  categoryName: 'Restaurant',
  categoryColor: Colors.red,
  categoryIconPath: 'assets/icons/restaurant.png',
  size: 80.0,
);
```

### 4. Business Marker

```dart
// Create a marker with brand colors and logo
final marker = await CustomMarkerCreator.createBusinessMarker(
  brandColor: Colors.green,
  logoPath: 'assets/icons/company_logo.png',
  size: 80.0,
);
```

### 5. Location Marker with IconData

```dart
// Create a marker using Flutter's built-in icons
final marker = await CustomMarkerCreator.createLocationMarker(
  markerColor: Colors.orange,
  icon: Icons.local_gas_station,
  iconColor: Colors.white,
  size: 80.0,
);
```

## Advanced Usage

### Custom Border Styling

```dart
final marker = await CustomMarkerCreator.createCustomMarker(
  backgroundColor: Colors.purple,
  iconPath: 'assets/icons/custom_icon.png',
  iconColor: Colors.white,
  size: 100.0,
  borderColor: Colors.gold,
  borderWidth: 4.0,
);
```

### Different Sizes

```dart
// Small marker
final smallMarker = await CustomMarkerCreator.createCustomMarker(
  backgroundColor: Colors.blue,
  size: 40.0,
);

// Large marker
final largeMarker = await CustomMarkerCreator.createCustomMarker(
  backgroundColor: Colors.red,
  size: 120.0,
);
```

## Integration with Existing Code

### Update Your Marker Creation Methods

Replace your existing marker creation methods with calls to `CustomMarkerCreator`:

```dart
// Before (old way)
Future<google_maps.BitmapDescriptor> _createCategoryMarkerIcon(String categoryName) async {
  // ... complex logic with manual image loading
}

// After (new way)
Future<google_maps.BitmapDescriptor> _createCategoryMarkerIcon(String categoryName) async {
  try {
    final categoryInfo = _categoryData[categoryName]!;
    final String hexColor = categoryInfo['color'] ?? '#2079C2';
    final Color categoryColor = _hexToColor(hexColor);
    
    return await CustomMarkerCreator.createCustomMarker(
      backgroundColor: categoryColor,
      iconPath: categoryInfo['logo'],
      iconColor: Colors.white,
      size: 80.0,
      borderColor: Colors.white,
      borderWidth: 2.0,
    );
  } catch (e) {
    // Fallback to default marker
    return google_maps.BitmapDescriptor.defaultMarkerWithHue(
      google_maps.BitmapDescriptor.hueBlue
    );
  }
}
```

## Helper Methods

### Convert Hex Colors to Flutter Colors

```dart
Color _hexToColor(String hexColor) {
  try {
    String color = hexColor.startsWith('#') ? hexColor.substring(1) : hexColor;
    int r = int.parse(color.substring(0, 2), radix: 16);
    int g = int.parse(color.substring(2, 4), radix: 16);
    int b = int.parse(color.substring(4, 6), radix: 16);
    return Color.fromARGB(255, r, g, b);
  } catch (e) {
    return Colors.blue; // Default fallback
  }
}
```

## Performance Features

### Caching

The `CustomMarkerCreator` automatically caches created markers to avoid recreating them:

```dart
// Check cache statistics
final stats = CustomMarkerCreator.getCacheStats();
print('Cached markers: ${stats['cachedMarkers']}');

// Clear cache if needed
CustomMarkerCreator.clearCache();
```

### Cache Keys

Cache keys are automatically generated based on:
- Background color
- Icon path
- Icon color
- Size
- Border color
- Border width

## Asset Requirements

### Icon Assets

Place your icon assets in the `assets/icons/` directory and declare them in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/icons/
```

### Supported Icon Formats

- PNG (recommended)
- JPG/JPEG
- WebP

### Icon Sizing

Icons are automatically scaled to fit within the marker:
- Icons take up 40% of the marker width
- Icons are centered within the marker
- Icons maintain their aspect ratio

## Error Handling

The `CustomMarkerCreator` includes comprehensive error handling:

```dart
try {
  final marker = await CustomMarkerCreator.createCustomMarker(
    backgroundColor: Colors.red,
    iconPath: 'assets/icons/icon.png',
  );
} catch (e) {
  print('Error creating marker: $e');
  // Use fallback marker
  final fallbackMarker = google_maps.BitmapDescriptor.defaultMarkerWithHue(
    google_maps.BitmapDescriptor.hueRed
  );
}
```

## Fallback Behavior

If custom marker creation fails, the system automatically falls back to Google's default markers with appropriate colors based on your background color.

## Best Practices

1. **Cache Management**: Let the system handle caching automatically
2. **Asset Optimization**: Use appropriately sized icons (recommended: 64x64 to 128x128)
3. **Error Handling**: Always wrap marker creation in try-catch blocks
4. **Performance**: Reuse markers when possible instead of creating new ones
5. **Testing**: Test with different icon formats and sizes

## Troubleshooting

### Common Issues

1. **Icons not showing**: Check asset paths and pubspec.yaml declarations
2. **Performance issues**: Monitor cache usage and clear if needed
3. **Memory leaks**: Ensure proper disposal of markers when not needed

### Debug Information

Enable debug logging to see detailed information about marker creation:

```dart
// Check cache statistics
print('Cache stats: ${CustomMarkerCreator.getCacheStats()}');
```

## Example Implementation

See `lib/src/components/custom_marker_example.dart` for a complete working example of how to use the `CustomMarkerCreator`.
