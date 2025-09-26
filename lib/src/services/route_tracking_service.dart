import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';

class RouteTrackingService {
  static final RouteTrackingService _instance = RouteTrackingService._internal();
  factory RouteTrackingService() => _instance;
  RouteTrackingService._internal();

  // Track route when navigating
  static void trackRoute(
    BuildContext context,
    String pageName, {
    Map<String, dynamic>? pageData,
    String? routePath,
    Map<String, dynamic>? routeArguments,
  }) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.saveLastVisitedPage(
        pageName,
        pageData: pageData,
        routePath: routePath,
        routeArguments: routeArguments,
      );
    } catch (e) {
      print('Error tracking route: $e');
    }
  }

  // Track route from a widget's initState
  static void trackCurrentRoute(
    BuildContext context,
    String pageName, {
    Map<String, dynamic>? pageData,
    String? routePath,
    Map<String, dynamic>? routeArguments,
  }) {
    // Use post frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      trackRoute(
        context,
        pageName,
        pageData: pageData,
        routePath: routePath,
        routeArguments: routeArguments,
      );
    });
  }

  // Get route name from a route path
  static String getRouteNameFromPath(String routePath) {
    // Extract meaningful name from route path
    final segments = routePath.split('/');
    if (segments.isEmpty) return routePath;
    
    // Get the last segment as the route name
    String routeName = segments.last;
    
    // Convert common patterns to readable names
    switch (routeName) {
      case 'home':
        return 'UserDashboard';
      case 'company':
        return 'CompanyDashboard';
      case 'branches':
        return 'BranchesPage';
      case 'serviceprovider':
        return 'ServiceproviderDashboard';
      case 'wholesaler':
        return 'WholesalerDashboard';
      case 'settings':
        return 'SettingsPage';
      case 'profile':
        return 'ProfilePage';
      case 'notifications':
        return 'NotificationsPage';
      case 'bookings':
        return 'BookingsPage';
      case 'referrals':
        return 'ReferralsPage';
      case 'subscription':
        return 'SubscriptionPage';
      default:
        // Convert camelCase to readable format
        return routeName.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        ).trim();
    }
  }

  // Common route tracking patterns
  static void trackDashboardRoute(BuildContext context, String userType, {
    Map<String, dynamic>? pageData,
  }) {
    String routeName;
    switch (userType.toLowerCase()) {
      case 'user':
        routeName = 'UserDashboard';
        break;
      case 'company':
        routeName = 'CompanyDashboard';
        break;
      case 'serviceprovider':
        routeName = 'ServiceproviderDashboard';
        break;
      case 'wholesaler':
        routeName = 'WholesalerDashboard';
        break;
      default:
        routeName = 'UserDashboard';
    }
    
    trackCurrentRoute(context, routeName, pageData: pageData);
  }

  static void trackSettingsRoute(BuildContext context, {
    Map<String, dynamic>? pageData,
  }) {
    trackCurrentRoute(context, 'SettingsPage', pageData: pageData);
  }

  static void trackProfileRoute(BuildContext context, {
    Map<String, dynamic>? pageData,
  }) {
    trackCurrentRoute(context, 'ProfilePage', pageData: pageData);
  }

  static void trackNotificationsRoute(BuildContext context, {
    Map<String, dynamic>? pageData,
  }) {
    trackCurrentRoute(context, 'NotificationsPage', pageData: pageData);
  }

  static void trackBookingsRoute(BuildContext context, {
    Map<String, dynamic>? pageData,
  }) {
    trackCurrentRoute(context, 'BookingsPage', pageData: pageData);
  }

  static void trackReferralsRoute(BuildContext context, {
    Map<String, dynamic>? pageData,
  }) {
    trackCurrentRoute(context, 'ReferralsPage', pageData: pageData);
  }

  static void trackSubscriptionRoute(BuildContext context, {
    Map<String, dynamic>? pageData,
  }) {
    trackCurrentRoute(context, 'SubscriptionPage', pageData: pageData);
  }

  static void trackBranchesRoute(BuildContext context, {
    Map<String, dynamic>? pageData,
  }) {
    trackCurrentRoute(context, 'BranchesPage', pageData: pageData);
  }
}
