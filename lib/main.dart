import 'package:barrim/src/services/google_auth_service.dart';
import 'package:barrim/src/services/notification_service.dart';
import 'package:barrim/src/services/notification_provider.dart';
import 'package:barrim/src/services/user_provider.dart';
import 'package:barrim/src/services/google_maps_service.dart';
import 'package:barrim/src/services/extended_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:barrim/src/features/authentication/screens/login_page.dart';
import 'package:barrim/src/features/authentication/screens/signup.dart';
import 'package:barrim/src/features/authentication/screens/splash_screen.dart';
import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/serviceprovider_subscriptions/serviceprovider_subscription.dart';
import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/subscription/wholesaler_subscription.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../src/models/auth_provider.dart';
import '../src/utils/subscription_provider.dart';
import '../src/utils/edge_to_edge_helper.dart';
import '../src/utils/centralized_token_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables with timeout
    try {
      await dotenv.load(fileName: ".env").timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print("Warning: Environment variables loading timeout");
        },
      );
      print("Environment variables loaded successfully");
    } catch (e) {
      print("Warning: Could not load .env file: $e");
      print("Continuing with default environment configuration...");
    }

    // Initialize Firebase only if not already initialized
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("Firebase initialized successfully");
    } catch (e) {
      print("Firebase initialization error: $e");
      // Continue without Firebase if initialization fails
    }

    // Initialize centralized token manager
    await CentralizedTokenManager.initialize();
    print("Centralized token manager initialized");
    
    // Initialize extended session service
    await ExtendedSessionService.initialize();
    print("Extended session service initialized");

    // Initialize notification service with timeout
    final notificationService = NotificationService();
    await notificationService.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print("Warning: Notification service initialization timeout");
      },
    );
    
    // Print FCM token after initialization
    final fcmToken = notificationService.fcmToken;
    if (fcmToken != null) {
      print("🔥 FCM Token: $fcmToken");
    } else {
      print("❌ FCM Token not available");
    }

    // Start the app immediately - don't wait for Google Maps
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider(notificationService)),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
          // Other providers...
        ],
        child: MyApp(),
      ),
    );

    // Initialize Google Maps services in the background (non-blocking)
    _initializeGoogleMapsInBackground();
  } catch (e) {
    print("Critical error during app initialization: $e");
    // Still try to run the app even if some services fail
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'App initialization error',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Error: ${e.toString()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Try to restart the app
                      main();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Initialize Google Maps services in the background without blocking the app
void _initializeGoogleMapsInBackground() async {
  print("Initializing Google Maps services in background...");
  try {
    final mapsInitialized = await GoogleMapsService.initialize();
    if (mapsInitialized) {
      print("Google Maps services initialized successfully");
    } else {
      print("Warning: Google Maps services failed to initialize");
    }
  } catch (e) {
    print("Error during Google Maps initialization: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Store provider references to avoid context access during lifecycle changes
  NotificationProvider? _notificationProvider;
  UserProvider? _userProvider;
  
  // Global navigation key for handling back button
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  // Deep linking
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize deep linking
    _appLinks = AppLinks();
    _initDeepLinking();
    
    // Hardware back button handling is done via WillPopScope in the builder
  }
  
  void _initDeepLinking() {
    // Handle initial link (if app was opened from a deep link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
    
    // Listen for deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        if (kDebugMode) {
          print('Deep link error: $err');
        }
      },
    );
  }
  
  void _handleDeepLink(Uri uri) {
    if (kDebugMode) {
      print('🔗 Deep link received: $uri');
    }
    
    // Handle payment redirects
    // Format: barrim://payment-success?requestId=xxx or barrim://payment-failed?requestId=xxx
    // Or: https://barrim.online/payment-success?requestId=xxx
    if (uri.scheme == 'barrim' || (uri.scheme == 'https' && uri.host == 'barrim.online')) {
      final path = uri.path;
      final queryParams = uri.queryParameters;
      
      if (kDebugMode) {
        print('Path: $path, Query params: $queryParams');
      }
      
      if (path.contains('payment-success') || path.contains('/payment-success')) {
        final requestId = queryParams['requestId'];
        if (kDebugMode) {
          print('✅ Payment success! RequestId: $requestId');
        }
        _navigateToPaymentSuccess(requestId);
      } else if (path.contains('payment-failed') || path.contains('/payment-failed')) {
        final requestId = queryParams['requestId'];
        if (kDebugMode) {
          print('❌ Payment failed! RequestId: $requestId');
        }
        _navigateToPaymentFailed(requestId);
      }
    }
  }
  
  void _navigateToPaymentSuccess(String? requestId) {
    // Wait for the app to be fully built before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;
      
      // Navigate to subscription page if user is logged in and has user data
      final userProvider = Provider.of<UserProvider>(navigator.context, listen: false);
      if (userProvider.isLoggedIn && userProvider.user != null) {
        if (kDebugMode) {
          print('Payment success detected via deep link. RequestId: $requestId');
        }
        
        // Show success message
        ScaffoldMessenger.of(navigator.context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Payment successful! Your payment has been processed.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        
        // Navigate to subscription page based on user type
        try {
          final userType = userProvider.user!.userType;
          if (userType != null && userType.isNotEmpty) {
            final userTypeLower = userType.toLowerCase();
            if (kDebugMode) {
              print('User type: $userTypeLower, Navigating to subscription page...');
            }
            
            // Wait a bit to ensure the app is fully resumed and context is ready
            await Future.delayed(const Duration(milliseconds: 800));
            
            // Refresh subscription provider data before navigating
            try {
              final subscriptionProvider = Provider.of<SubscriptionProvider>(navigator.context, listen: false);
              subscriptionProvider.refreshAllData();
              if (kDebugMode) {
                print('Subscription provider data refreshed');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error refreshing subscription provider: $e');
              }
            }
            
            // Navigate to subscription page based on user type
            if (userTypeLower == 'service_provider') {
              if (navigator.mounted) {
                // Navigate to service provider subscription page
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const ServiceproviderSubscription(),
                  ),
                  (route) => false, // Remove all previous routes
                );
                if (kDebugMode) {
                  print('✅ Navigated to Service Provider subscription page');
                }
              }
            } else if (userTypeLower == 'company') {
              // For company, we need branch ID which we don't have from deep link
              // Navigate to company dashboard instead - user can navigate to subscription from there
              if (kDebugMode) {
                print('Company user - payment success detected. User should navigate to subscription page manually.');
              }
              // Show a message that they should check their subscription status
              ScaffoldMessenger.of(navigator.context).showSnackBar(
                const SnackBar(
                  content: Text('Please check your subscription status in your branch dashboard.'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 5),
                ),
              );
            } else if (userTypeLower == 'wholesaler') {
              if (navigator.mounted) {
                // Navigate to wholesaler subscription page
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const WholesalerSubscription(),
                  ),
                  (route) => false, // Remove all previous routes
                );
                if (kDebugMode) {
                  print('✅ Navigated to Wholesaler subscription page');
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error navigating to subscription page: $e');
          }
          // If navigation fails, the polling on subscription page will still work
        }
      }
    });
  }
  
  void _navigateToPaymentFailed(String? requestId) {
    // Wait for the app to be fully built before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;
      
      // Show failure message
      ScaffoldMessenger.of(navigator.context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Payment failed. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider references when dependencies are available
    _notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Use stored provider references instead of accessing context
    if (_notificationProvider == null || _userProvider == null) {
      print('Providers not available during lifecycle change');
      return;
    }

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App is going to background or being terminated
        print('App going to background - closing WebSocket connection');
        _notificationProvider!.closeConnection();
        break;
      case AppLifecycleState.resumed:
        // App is coming to foreground
        _handleAppResume(_userProvider!, _notificationProvider!);
        break;
      default:
        break;
    }
  }

  // Handle app resume with session validation
  Future<void> _handleAppResume(UserProvider userProvider, NotificationProvider notificationProvider) async {
    if (kDebugMode) {
      print('App resumed - checking session status');
      print('UserProvider.isLoggedIn: ${userProvider.isLoggedIn}');
      print('UserProvider.token: ${userProvider.token != null ? 'Token exists' : 'No token'}');
      print('UserProvider.user: ${userProvider.user != null ? 'User exists' : 'No user'}');
    }
    
    // First check extended session
    try {
      final isExtendedValid = await ExtendedSessionService.isSessionValid();
      if (isExtendedValid) {
        if (kDebugMode) {
          print('Extended session found and valid - updating activity');
        }
        await ExtendedSessionService.updateLastActivity();
        
        // If user provider doesn't have session data, try to load from extended session
        if (!userProvider.isLoggedIn) {
          final extendedToken = await ExtendedSessionService.getToken();
          final extendedUserData = await ExtendedSessionService.getUserData();
          
          if (extendedToken != null && extendedUserData != null) {
            // Load user data from extended session
            userProvider.setUserAndTokenWithExtendedSession(
              json.decode(extendedUserData),
              extendedToken,
              rememberMe: true,
            );
            
            if (kDebugMode) {
              print('User data loaded from extended session');
            }
          }
        }
        
        // Reconnect WebSocket if user is logged in
        if (userProvider.isLoggedIn && userProvider.token != null && userProvider.user != null) {
          notificationProvider.initWebSocket(
            userProvider.token!,
            userProvider.user!.id,
            userType: userProvider.user!.userType,
          );
          if (kDebugMode) {
            print('WebSocket reconnected from extended session');
          }
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking extended session: $e');
      }
    }
    
    // Fall back to regular session handling
    if (userProvider.isLoggedIn && userProvider.token != null && userProvider.user != null) {
      if (kDebugMode) {
        print('App resumed - validating regular session and reconnecting WebSocket');
      }
      
      // Use the new comprehensive session check
      final sessionValid = await userProvider.checkAndHandleSession();
      
      if (sessionValid) {
        notificationProvider.initWebSocket(
          userProvider.token!,
          userProvider.user!.id,
          userType: userProvider.user!.userType,
        );
        if (kDebugMode) {
          print('Regular session validated and WebSocket reconnected');
        }
      } else {
        if (kDebugMode) {
          print('Regular session expired or refresh failed, user will need to login again');
        }
        // Optionally show a message to the user about session expiration
      }
    } else {
      if (kDebugMode) {
        print('No valid session found on app resume');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => GoogleSignInProvider(),
    child: MaterialApp(
      title: 'Barrim',
      navigatorKey: _navigatorKey,
      home: const SplashScreen(),
      theme: ThemeData.light().copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoSwipeMaterialPageTransitionsBuilder(),
            TargetPlatform.iOS: NoSwipeCupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      builder: (context, child) {
        // Configure system UI overlay for edge-to-edge support
        // Using modern approach without deprecated APIs
        EdgeToEdgeHelper.configureSystemUIOverlayForLightTheme();
        
        // Wrap with WillPopScope for Android back button handling
        if (Platform.isAndroid) {
          return WillPopScope(
            onWillPop: () async {
              _handleHardwareBackButton();
              return false; // Prevent default back behavior
            },
            child: child!,
          );
        }
        
        return child!;
      },
    ),
  );

  // Handle hardware back button press
  void _handleHardwareBackButton() {
    print('🔙 Hardware back button pressed!');
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      print('❌ Navigator is null');
      return;
    }
    
    // Check if we can pop normally
    if (navigator.canPop()) {
      print('✅ Can pop - navigating back');
      navigator.pop();
      return;
    }
    
    print('❌ Cannot pop - checking current route');
    
    // If we can't pop, check the current route
    final currentRoute = ModalRoute.of(navigator.context);
    if (currentRoute != null) {
      final routeName = currentRoute.settings.name ?? '';
      print('📍 Current route: $routeName');
      
      // Check if we're on a main app screen (not splash or login)
      if (routeName.contains('Dashboard') ||
          routeName.contains('Home') ||
          routeName.contains('Categories') ||
          routeName.contains('Settings') ||
          routeName.contains('UserDashboard') ||
          routeName.contains('CompanyDashboard') ||
          routeName.contains('ServiceproviderDashboard') ||
          routeName.contains('WholesalerDashboard')) {
        // Navigate to login page instead of exiting
        print('🏠 Navigating to login from dashboard screen');
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
        return;
      }
    }
    
    // If we're at the root or on login page, show exit confirmation
    print('🚪 Showing exit confirmation dialog');
    _handleAppExit(navigator.context);
  }

  // Handle app exit when at root screen
  void _handleAppExit(BuildContext context) {
    // Show a dialog with more options
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Exit App'),
          content: Text('What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Stay'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to login page
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                );
              },
              child: Text('Go to Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Exit the app
                SystemNavigator.pop();
              },
              child: Text('Exit App'),
            ),
          ],
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _websocketInitialized = false;
  NotificationProvider? _notificationProvider;

  @override
  void initState() {
    super.initState();
    // Initialize session and WebSocket after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider reference when dependencies are available
    _notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
  }

  Future<void> _initializeSession() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (kDebugMode) {
      print('Initializing session...');
      print('UserProvider.isInitialized: ${userProvider.isInitialized}');
    }

    // Wait for UserProvider to initialize with timeout
    int attempts = 0;
    const maxAttempts = 50; // 5 seconds max wait time
    
    while (!userProvider.isInitialized && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!userProvider.isInitialized) {
      if (kDebugMode) {
        print('UserProvider initialization timeout - continuing without session');
      }
      return;
    }

    if (kDebugMode) {
      print('UserProvider initialized');
      print('UserProvider.isLoggedIn: ${userProvider.isLoggedIn}');
      print('UserProvider.token: ${userProvider.token != null ? 'Token exists' : 'No token'}');
      print('UserProvider.user: ${userProvider.user != null ? 'User exists' : 'No user'}');
    }

    if (userProvider.isLoggedIn &&
        userProvider.token != null &&
        userProvider.user != null) {
      if (kDebugMode) {
        print('Session found - initializing WebSocket');
      }
      
      // Use the new comprehensive session check with timeout
      try {
        final sessionValid = await userProvider.checkAndHandleSession().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (kDebugMode) {
              print('Session check timeout - skipping WebSocket initialization');
            }
            return false;
          },
        );
        
        if (sessionValid && !_websocketInitialized) {
          notificationProvider.initWebSocket(
            userProvider.token!,
            userProvider.user!.id,
            userType: userProvider.user!.userType,
          );
          _websocketInitialized = true;
          if (kDebugMode) {
            print('WebSocket initialized successfully');
          }
          
          // Navigation is now handled by splash screen
          print('Session initialized successfully');
        } else if (!sessionValid) {
          if (kDebugMode) {
            print('Session expired or refresh failed during initialization');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error during session initialization: $e');
        }
      }
    } else {
      if (kDebugMode) {
        print('No valid session found - user needs to login');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Get system insets for edge-to-edge support using helper
    final topPadding = EdgeToEdgeHelper.getTopPadding(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background image - extends edge-to-edge
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          // Background overlay - extends edge-to-edge
          Positioned.fill(
            child: Container(
              color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
            ),
          ),
          // Main content with responsive layout and proper inset handling
          Column(
            children: [
              // Top spacer - accounts for status bar
              SizedBox(height: topPadding),
              Expanded(
                flex: 5, // Adjust this ratio to control text position
                child: Container(),
              ),
              // Main title text
              Expanded(
                flex: 8, // Adjust this ratio to control text space
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08, // 8% of screen width
                  ),
                  child: Center(
                    child: Text(
                      'Discover the best of your neighborhood with Barrim!',
                      textAlign: TextAlign.start,
                      style: GoogleFonts.nunito(
                        fontSize: _getResponsiveFontSize(screenWidth),
                        fontWeight: FontWeight.w700,
                        height: 1.375,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom section with buttons - uses SafeArea for navigation bar
              Container(
                width: screenWidth,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(63),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: true, // Ensure content doesn't overlap with navigation bar
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.08,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Log in button
                        SizedBox(
                          width: double.infinity,
                          height: _getResponsiveButtonHeight(screenHeight),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => LoginPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ).copyWith(
                              backgroundColor: WidgetStateProperty.all(Colors.transparent),
                              elevation: WidgetStateProperty.all(0),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFF0094FF),
                                    Color(0xFF05055A),
                                    Color(0xFF0094FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  'Log in',
                                  style: GoogleFonts.nunito(
                                    fontSize: _getResponsiveButtonTextSize(screenWidth),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02), // 2% of screen height
                        // Sign up button
                        SizedBox(
                          width: double.infinity,
                          height: _getResponsiveButtonHeight(screenHeight) * 0.8,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SignUp()),
                              );
                            },
                            child: Text(
                              'Sign up instead',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: _getResponsiveButtonTextSize(screenWidth),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF05055A),
                              ),
                            ),
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to get responsive font size for title
  double _getResponsiveFontSize(double screenWidth) {
    if (screenWidth < 350) {
      return 28; // Small phones
    } else if (screenWidth < 400) {
      return 32; // Medium phones
    } else if (screenWidth < 450) {
      return 36; // Large phones
    } else {
      return 38; // Extra large phones/tablets
    }
  }

  // Helper method to get responsive button height
  double _getResponsiveButtonHeight(double screenHeight) {
    return screenHeight * 0.08; // 8% of screen height
  }

  // Helper method to get responsive button text size
  double _getResponsiveButtonTextSize(double screenWidth) {
    if (screenWidth < 350) {
      return 22; // Small phones
    } else if (screenWidth < 400) {
      return 24; // Medium phones
    } else {
      return 26; // Large phones
    }
  }

  // Show FCM Token dialog
  void _showFCMTokenDialog(BuildContext context) {
    final notificationService = NotificationService();
    final fcmToken = notificationService.fcmToken;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('FCM Token'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fcmToken ?? 'FCM Token not available',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (fcmToken != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Copy this token to test notifications:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Copy to clipboard
                      Clipboard.setData(ClipboardData(text: fcmToken));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('FCM Token copied to clipboard!')),
                      );
                    },
                    child: const Text('Copy Token'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Clean up WebSocket connection when leaving this page
    if (_notificationProvider != null) {
      _notificationProvider!.closeConnection();
    }
    super.dispose();
  }
}

// Custom page transition builders that work with our back navigation handling
class NoSwipeCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoSwipeCupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Use SlideTransition for a smooth slide effect
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: child,
    );
  }
}

// Custom page transition builders that work with our back navigation handling
class NoSwipeMaterialPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoSwipeMaterialPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Use SlideTransition for a smooth slide effect
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: child,
    );
  }
}