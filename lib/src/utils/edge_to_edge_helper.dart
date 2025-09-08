import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for handling edge-to-edge display on Android 15+
/// This class provides consistent edge-to-edge support across the app
class EdgeToEdgeHelper {
  /// Configure system UI overlay for edge-to-edge support
  /// Call this method in your app's main MaterialApp builder
  /// Note: This uses modern approach without deprecated APIs
  static void configureSystemUIOverlay({
    Brightness statusBarIconBrightness = Brightness.dark,
    Brightness statusBarBrightness = Brightness.light,
    Brightness systemNavigationBarIconBrightness = Brightness.dark,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        // Removed deprecated statusBarColor and systemNavigationBarColor
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarBrightness,
        systemNavigationBarIconBrightness: systemNavigationBarIconBrightness,
      ),
    );
  }

  /// Configure system UI overlay for dark theme
  static void configureSystemUIOverlayForDarkTheme() {
    configureSystemUIOverlay(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
    );
  }

  /// Configure system UI overlay for light theme
  static void configureSystemUIOverlayForLightTheme() {
    configureSystemUIOverlay(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
  }

  /// Get safe area padding for the current context
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  /// Get only top padding (status bar)
  static double getTopPadding(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Get only bottom padding (navigation bar)
  static double getBottomPadding(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  /// Create a widget that handles edge-to-edge display with proper insets
  static Widget buildEdgeToEdgeScaffold({
    required BuildContext context,
    required Widget body,
    PreferredSizeWidget? appBar,
    Widget? bottomNavigationBar,
    Widget? floatingActionButton,
    FloatingActionButtonLocation? floatingActionButtonLocation,
    Color? backgroundColor,
    bool extendBody = false,
    bool extendBodyBehindAppBar = false,
  }) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }

  /// Create a safe area wrapper that respects edge-to-edge design
  static Widget buildSafeAreaWrapper({
    required Widget child,
    bool top = true,
    bool bottom = true,
    bool left = true,
    bool right = true,
    EdgeInsets? minimum,
  }) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      minimum: minimum ?? EdgeInsets.zero,
      child: child,
    );
  }

  /// Create a container that extends edge-to-edge with proper content padding
  static Widget buildEdgeToEdgeContainer({
    required Widget child,
    Color? color,
    Decoration? decoration,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? width,
    double? height,
    Alignment? alignment,
  }) {
    return Container(
      width: width,
      height: height,
      color: color,
      decoration: decoration,
      padding: padding,
      margin: margin,
      alignment: alignment,
      child: child,
    );
  }

  /// Check if the device supports edge-to-edge display
  static bool supportsEdgeToEdge(BuildContext context) {
    // Edge-to-edge is supported on Android 15+ (API level 35+)
    // For Flutter, we can check if we're on Android and assume support
    // In a real implementation, you might want to check the actual Android version
    return Theme.of(context).platform == TargetPlatform.android;
  }

  /// Get the recommended padding for content that should not overlap with system bars
  static EdgeInsets getContentPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  /// Create a responsive layout that adapts to edge-to-edge display
  static Widget buildResponsiveLayout({
    required BuildContext context,
    required Widget child,
    EdgeInsets? additionalPadding,
    bool respectSystemBars = true,
  }) {
    if (!respectSystemBars) {
      return child;
    }

    final contentPadding = getContentPadding(context);
    final totalPadding = additionalPadding != null
        ? EdgeInsets.only(
            top: contentPadding.top + additionalPadding.top,
            bottom: contentPadding.bottom + additionalPadding.bottom,
            left: contentPadding.left + additionalPadding.left,
            right: contentPadding.right + additionalPadding.right,
          )
        : contentPadding;

    return Padding(
      padding: totalPadding,
      child: child,
    );
  }
}
