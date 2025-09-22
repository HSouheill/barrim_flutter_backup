import 'package:barrim/src/services/gcp_google_auth_service.dart';
import 'package:barrim/src/services/notification_service.dart';
import 'package:barrim/src/services/notification_provider.dart';
import 'package:barrim/src/services/user_provider.dart';
import 'package:barrim/src/services/google_maps_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barrim/src/features/authentication/screens/login_page.dart';
import 'package:barrim/src/features/authentication/screens/signup.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../src/models/auth_provider.dart';
import '../src/utils/subscription_provider.dart';
import '../src/utils/edge_to_edge_helper.dart';
// Removed Firebase imports - using GCP OAuth instead
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

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

    // Firebase initialization removed - using GCP OAuth instead
    print("Using GCP OAuth for Google Sign-In - no Firebase initialization needed");

    // Initialize notification service with timeout
    final notificationService = NotificationService();
    await notificationService.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print("Warning: Notification service initialization timeout");
      },
    );

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    
    if (userProvider.isLoggedIn && userProvider.token != null && userProvider.user != null) {
      if (kDebugMode) {
        print('App resumed - validating session and reconnecting WebSocket');
      }
      
      // Use the new comprehensive session check
      final sessionValid = await userProvider.checkAndHandleSession();
      
      if (sessionValid) {
        notificationProvider.initWebSocket(
          userProvider.token!,
          userProvider.user!.id,
        );
        if (kDebugMode) {
          print('Session validated and WebSocket reconnected');
        }
      } else {
        if (kDebugMode) {
          print('Session expired or refresh failed, user will need to login again');
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
    create: (context) => GCPGoogleSignInProvider(),
    child: MaterialApp(
      title: 'Barrim',
      home: const MyHomePage(),
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
        return child!;
      },
    ),
  );
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
          );
          _websocketInitialized = true;
          if (kDebugMode) {
            print('WebSocket initialized successfully');
          }
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

  @override
  void dispose() {
    // Clean up WebSocket connection when leaving this page
    if (_notificationProvider != null) {
      _notificationProvider!.closeConnection();
    }
    super.dispose();
  }
}

// Add this class at the end of the file to disable swipe back on iOS
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
    // CupertinoPageTransition is not public API, so use FadeTransition as a safe fallback
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

// Add this class at the end of the file to disable swipe back on Android
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
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}