# Route Tracking Implementation Guide

This guide explains how to implement global route tracking for any page in the app so users return to their last visited page when reopening the app.

## Quick Implementation

### For Any Page Widget

Add this to your page's `initState()` method:

```dart
import 'package:barrim/src/services/route_tracking_service.dart';

class YourPage extends StatefulWidget {
  final Map<String, dynamic> userData; // or any other data you need
  
  @override
  void initState() {
    super.initState();
    
    // Track this route - replace 'YourPageName' with your actual page name
    RouteTrackingService.trackCurrentRoute(
      context,
      'YourPageName',
      pageData: widget.userData, // pass any data you need
    );
  }
}
```

### For Common Page Types

Use these pre-built methods for common page types:

```dart
// For dashboard pages
RouteTrackingService.trackDashboardRoute(context, 'user', pageData: userData);
RouteTrackingService.trackDashboardRoute(context, 'company', pageData: userData);
RouteTrackingService.trackDashboardRoute(context, 'serviceProvider', pageData: userData);
RouteTrackingService.trackDashboardRoute(context, 'wholesaler', pageData: userData);

// For specific pages
RouteTrackingService.trackSettingsRoute(context, pageData: userData);
RouteTrackingService.trackProfileRoute(context, pageData: userData);
RouteTrackingService.trackNotificationsRoute(context, pageData: userData);
RouteTrackingService.trackBookingsRoute(context, pageData: userData);
RouteTrackingService.trackReferralsRoute(context, pageData: userData);
RouteTrackingService.trackSubscriptionRoute(context, pageData: userData);
RouteTrackingService.trackBranchesRoute(context, pageData: userData);
```

### For Navigation Actions

When navigating to a new page, track the route:

```dart
// Before navigating
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => YourPage(userData: userData),
  ),
);

// Track the route after navigation
RouteTrackingService.trackRoute(
  context,
  'YourPageName',
  pageData: userData,
);
```

## Adding New Page Types

To add support for new page types in the restoration logic, update `main.dart`:

1. Add the import for your page:
```dart
import 'package:barrim/src/features/your_feature/your_page.dart';
```

2. Add a case in the `_navigateToPage` method:
```dart
case 'YourPageName':
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (context) => YourPage(userData: pageData),
    ),
  );
  break;
```

## Page Naming Convention

Use descriptive, consistent names for pages:
- `UserDashboard`
- `CompanyDashboard` 
- `ServiceproviderDashboard`
- `WholesalerDashboard`
- `SettingsPage`
- `ProfilePage`
- `NotificationsPage`
- `BookingsPage`
- `ReferralsPage`
- `SubscriptionPage`
- `BranchesPage`

## Data Passing

The `pageData` parameter should contain any data needed to restore the page state:
- User data
- Authentication tokens
- Page-specific state
- Navigation arguments

## Route Expiration

Routes automatically expire after 24 hours to prevent stale navigation. Users will be redirected to their default dashboard if the saved route is too old.

## Examples

### Settings Page
```dart
class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  @override
  void initState() {
    super.initState();
    RouteTrackingService.trackSettingsRoute(context, pageData: widget.userData);
  }
}
```

### Profile Page
```dart
class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  @override
  void initState() {
    super.initState();
    RouteTrackingService.trackProfileRoute(context, pageData: widget.userData);
  }
}
```

### Custom Page
```dart
class CustomPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String customData;
  
  @override
  void initState() {
    super.initState();
    RouteTrackingService.trackCurrentRoute(
      context,
      'CustomPage',
      pageData: {
        'userData': widget.userData,
        'customData': widget.customData,
      },
    );
  }
}
```

## Benefits

- ✅ **Universal**: Works with any page in the app
- ✅ **Automatic**: No manual route management needed
- ✅ **Persistent**: Survives app restarts and device reboots
- ✅ **Smart**: Expires old routes automatically
- ✅ **Flexible**: Supports any page data structure
- ✅ **Easy**: Simple one-line implementation
