import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/user_provider.dart';
import '../../../services/extended_session_service.dart';
import 'user_dashboard/home.dart';
import 'company_dashboard/company_dashboard.dart';
import 'serviceProvider_dashboard/serviceProvider_dashboard.dart';
import 'wholesaler_dashboard/wholesaler_dashboard.dart';
import 'company_dashboard/branches.dart';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));
    
    // Start animation
    _animationController.forward();
    
    // Navigate after splash duration
    _navigateAfterSplash();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterSplash() async {
    // Wait for splash screen duration (3 seconds)
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    // Get user provider
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Wait for user provider to initialize
    int attempts = 0;
    const maxAttempts = 50; // 5 seconds max wait time
    
    while (!userProvider.isInitialized && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (!mounted) return;
    
    // Check if user is logged in and has a valid saved route
    print('Splash screen - checking session status:');
    print('  isLoggedIn: ${userProvider.isLoggedIn}');
    print('  user: ${userProvider.user != null ? 'exists' : 'null'}');
    print('  token: ${userProvider.token != null ? 'exists' : 'null'}');
    print('  lastVisitedPage: ${userProvider.lastVisitedPage}');
    print('  isSavedRouteValid: ${userProvider.isSavedRouteValid()}');
    
    // Check for extended session first
    bool hasValidExtendedSession = false;
    Map<String, dynamic>? extendedRouteInfo;
    
    try {
      final isExtendedValid = await ExtendedSessionService.isSessionValid();
      final isExtendedRouteValid = await ExtendedSessionService.isSavedRouteValid();
      
      if (isExtendedValid && isExtendedRouteValid) {
        extendedRouteInfo = await ExtendedSessionService.getCurrentRouteInfo();
        hasValidExtendedSession = extendedRouteInfo != null;
        print('Extended session found and valid: $hasValidExtendedSession');
      }
    } catch (e) {
      print('Error checking extended session: $e');
    }
    
    // Check regular session
    bool hasValidRegularSession = userProvider.isLoggedIn && 
        userProvider.isSavedRouteValid() && 
        userProvider.user != null;
    
    if (hasValidExtendedSession && extendedRouteInfo != null) {
      // Use extended session route
      final pageName = extendedRouteInfo['pageName'] as String;
      final pageData = extendedRouteInfo['pageData'] as Map<String, dynamic>? ?? {};
      final routeArguments = extendedRouteInfo['routeArguments'] as Map<String, dynamic>? ?? {};
      
      print('Navigating from splash to extended session last visited page: $pageName');
      print('  pageData keys: ${pageData.keys.toList()}');
      
      // Navigate to the last visited page
      _navigateToPage(context, pageName, pageData, routeArguments, userProvider);
      return;
    } else if (hasValidRegularSession) {
      // Use regular session route
      final routeInfo = userProvider.getCurrentRouteInfo();
      if (routeInfo != null) {
        final pageName = routeInfo['pageName'] as String;
        final pageData = routeInfo['pageData'] as Map<String, dynamic>? ?? {};
        final routeArguments = routeInfo['routeArguments'] as Map<String, dynamic>? ?? {};
        
        print('Navigating from splash to regular session last visited page: $pageName');
        print('  pageData keys: ${pageData.keys.toList()}');
        
        // Navigate to the last visited page
        _navigateToPage(context, pageName, pageData, routeArguments, userProvider);
        return;
      } else {
        print('No route info found despite valid regular session');
      }
    } else {
      print('No valid session found for auto-navigation');
    }
    
    // If no valid route or not logged in, navigate to login
    print('No valid route found, navigating to login');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  // Navigate to specific page based on page name
  void _navigateToPage(
    BuildContext context,
    String pageName,
    Map<String, dynamic> pageData,
    Map<String, dynamic> routeArguments,
    UserProvider userProvider,
  ) {
    switch (pageName) {
      case 'UserDashboard':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => UserDashboard(userData: pageData),
          ),
        );
        break;
      case 'CompanyDashboard':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CompanyDashboard(userData: pageData),
          ),
        );
        break;
      case 'BranchesPage':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BranchesPage(
              token: userProvider.token ?? '',
              initialBranches: routeArguments['initialBranches'] ?? [],
              userData: pageData,
            ),
          ),
        );
        break;
      case 'ServiceproviderDashboard':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ServiceproviderDashboard(userData: pageData),
          ),
        );
        break;
      case 'WholesalerDashboard':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WholesalerDashboard(userData: pageData),
          ),
        );
        break;
      // Add more page cases as needed
      default:
        print('Unknown page: $pageName, navigating to appropriate dashboard');
        _navigateToDefaultDashboard(context, userProvider);
    }
  }

  // Navigate to default dashboard based on user type
  void _navigateToDefaultDashboard(BuildContext context, UserProvider userProvider) {
    final userType = userProvider.user?.userType ?? 'user';
    final pageData = userProvider.userData ?? {};

    switch (userType) {
      case 'user':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => UserDashboard(userData: pageData),
          ),
        );
        break;
      case 'company':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CompanyDashboard(userData: pageData),
          ),
        );
        break;
      case 'serviceProvider':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ServiceproviderDashboard(userData: pageData),
          ),
        );
        break;
      case 'wholesaler':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WholesalerDashboard(userData: pageData),
          ),
        );
        break;
      default:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => UserDashboard(userData: pageData),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: screenSize.width * 0.4,
                  height: screenSize.width * 0.4,
                  child: Image.asset(
                    'assets/logo/app_logo.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if logo not found
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.business,
                          size: screenSize.width * 0.2,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
