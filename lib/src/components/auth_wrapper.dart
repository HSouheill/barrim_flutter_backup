import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import '../models/user.dart';
import '../features/authentication/screens/user_dashboard/home.dart';
import '../features/authentication/screens/login_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Show loading while initializing
        if (!userProvider.isInitialized || userProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check if user is logged in
        if (userProvider.isLoggedIn && userProvider.user != null) {
          // User is authenticated, navigate to appropriate dashboard
          return _getDashboardForUserType(userProvider.user!);
        } else {
          // User is not authenticated, show login page
          return LoginPage();
        }
      },
    );
  }

  Widget _getDashboardForUserType(User user) {
    // Navigate to appropriate dashboard based on user type
    switch (user.userType) {
      case 'user':
        return Home(userData: user.toJson());
      case 'company':
        // Import and return company dashboard
        return Home(userData: user.toJson()); // Placeholder - replace with actual company dashboard
      case 'wholesaler':
        // Import and return wholesaler dashboard
        return Home(userData: user.toJson()); // Placeholder - replace with actual wholesaler dashboard
      case 'serviceProvider':
        // Import and return service provider dashboard
        return Home(userData: user.toJson()); // Placeholder - replace with actual service provider dashboard
      default:
        return Home(userData: user.toJson());
    }
  }
} 