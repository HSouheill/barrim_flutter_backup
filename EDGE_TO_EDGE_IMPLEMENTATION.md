# Android 15 Edge-to-Edge Implementation

This document outlines the implementation of edge-to-edge display support for Android 15+ (SDK 35+) in the Barrim Flutter app.

## Overview

Starting with Android 15 (API level 35), applications targeting this version will display content edge-to-edge by default. This means the app's UI extends behind system bars like the status and navigation bars, requiring proper inset handling to ensure critical UI elements remain accessible.

## Implementation Details

### 1. Android Native Configuration

#### MainActivity.kt
- **Location**: `android/app/src/main/kotlin/com/barrim/barrim/MainActivity.kt`
- **Key Changes**:
  - Added `enableEdgeToEdge()` call for Android 15+ compatibility
  - Configured `WindowCompat.setDecorFitsSystemWindows(window, false)`
  - Implemented proper inset handling with `ViewCompat.setOnApplyWindowInsetsListener`

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    // Enable edge-to-edge display for Android 15+ compatibility
    enableEdgeToEdge()
    
    super.onCreate(savedInstanceState)
    
    // Additional edge-to-edge configuration for Flutter
    WindowCompat.setDecorFitsSystemWindows(window, false)
    
    // Handle system insets
    ViewCompat.setOnApplyWindowInsetsListener(findViewById(android.R.id.content)) { view, insets ->
        val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
        view.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
        insets
    }
}
```

#### Theme Configuration
- **Light Theme**: `android/app/src/main/res/values/styles.xml`
- **Dark Theme**: `android/app/src/main/res/values-night/styles.xml`

Both themes are configured with:
- Transparent status and navigation bars
- Proper light/dark icon brightness settings
- Edge-to-edge enforcement opt-out set to `false` (temporary measure)

### 2. Flutter Implementation

#### EdgeToEdgeHelper Utility Class
- **Location**: `lib/src/utils/edge_to_edge_helper.dart`
- **Purpose**: Provides consistent edge-to-edge support across the app
- **Features**:
  - System UI overlay configuration
  - Safe area padding calculations
  - Responsive layout builders
  - Theme-specific configurations

#### Main App Configuration
- **Location**: `lib/main.dart`
- **Changes**:
  - Added `EdgeToEdgeHelper.configureSystemUIOverlayForLightTheme()` in MaterialApp builder
  - Updated MyHomePage to use proper inset handling
  - Implemented responsive layout with system bar awareness

### 3. Key Features

#### System UI Overlay Management
```dart
EdgeToEdgeHelper.configureSystemUIOverlayForLightTheme();
EdgeToEdgeHelper.configureSystemUIOverlayForDarkTheme();
```

#### Safe Area Handling
```dart
final topPadding = EdgeToEdgeHelper.getTopPadding(context);
final bottomPadding = EdgeToEdgeHelper.getBottomPadding(context);
```

#### Responsive Layout
```dart
EdgeToEdgeHelper.buildResponsiveLayout(
  context: context,
  child: yourWidget,
  respectSystemBars: true,
);
```

## Testing Requirements

### 1. Device Testing
- Test on Android 15+ devices
- Verify content doesn't overlap with system bars
- Check both light and dark themes
- Test on different screen sizes and orientations

### 2. Key Areas to Test
- **Status Bar**: Ensure content doesn't overlap with status bar
- **Navigation Bar**: Verify bottom content respects navigation bar
- **Notch/Dynamic Island**: Test on devices with notches
- **Gesture Navigation**: Ensure gesture areas are properly handled

### 3. Edge Cases
- **Keyboard Appearance**: Test with soft keyboard
- **Screen Rotation**: Verify layout adapts correctly
- **Multi-window Mode**: Test in split-screen scenarios

## Migration Guide for Other Screens

### 1. Using SafeArea Widget
```dart
SafeArea(
  top: true,    // Respect status bar
  bottom: true, // Respect navigation bar
  child: yourContent,
)
```

### 2. Using EdgeToEdgeHelper
```dart
EdgeToEdgeHelper.buildSafeAreaWrapper(
  child: yourContent,
  top: true,
  bottom: true,
)
```

### 3. Manual Inset Handling
```dart
final padding = EdgeToEdgeHelper.getContentPadding(context);
Padding(
  padding: padding,
  child: yourContent,
)
```

## Backward Compatibility

The implementation includes backward compatibility for devices running Android versions prior to 15:
- `enableEdgeToEdge()` provides consistent experience across Android versions
- SafeArea widgets work on all platforms
- EdgeToEdgeHelper gracefully handles older Android versions

## Temporary Opt-Out

Currently, the app has `android:windowOptOutEdgeToEdgeEnforcement` set to `false` in themes. This attribute:
- **Purpose**: Temporary measure for apps not ready for edge-to-edge
- **Status**: Will be deprecated in future SDK levels
- **Action Required**: Remove this attribute once full edge-to-edge support is confirmed

## Best Practices

### 1. Content Layout
- Use SafeArea widgets for interactive elements
- Allow backgrounds to extend edge-to-edge
- Ensure text remains readable against system bars

### 2. Performance
- Avoid excessive inset calculations
- Use EdgeToEdgeHelper for consistent behavior
- Test on low-end devices

### 3. User Experience
- Maintain consistent spacing
- Ensure touch targets remain accessible
- Provide visual feedback for edge-to-edge areas

## Troubleshooting

### Common Issues
1. **Content Overlapping System Bars**
   - Solution: Use SafeArea or EdgeToEdgeHelper.getContentPadding()

2. **Inconsistent Behavior Across Devices**
   - Solution: Use EdgeToEdgeHelper for consistent implementation

3. **Theme-Specific Issues**
   - Solution: Configure system UI overlay per theme

### Debug Tools
- Use Flutter Inspector to visualize SafeArea boundaries
- Test with different system UI configurations
- Use Android Studio's Layout Inspector for native debugging

## Future Considerations

1. **Remove Opt-Out**: Once fully tested, remove `windowOptOutEdgeToEdgeEnforcement`
2. **Enhanced Theming**: Implement dynamic theme switching with proper edge-to-edge support
3. **Accessibility**: Ensure edge-to-edge implementation doesn't impact accessibility features
4. **Performance**: Monitor performance impact of inset calculations

## References

- [Android 15 Edge-to-Edge Documentation](https://developer.android.com/develop/ui/views/layout/edge-to-edge)
- [Flutter SafeArea Widget](https://api.flutter.dev/flutter/widgets/SafeArea-class.html)
- [Android Window Insets](https://developer.android.com/develop/ui/views/layout/edge-to-edge#handle-insets)
