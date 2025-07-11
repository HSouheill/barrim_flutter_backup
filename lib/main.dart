import 'package:barrim/src/services/google_auth_service.dart';
import 'package:barrim/src/services/notification_service.dart';
import 'package:barrim/src/services/notification_provider.dart';
import 'package:barrim/src/services/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barrim/src/features/authentication/screens/login_page.dart';
import 'package:barrim/src/features/authentication/screens/signup.dart';
import 'package:provider/provider.dart';
import '../src/models/auth_provider.dart';
import '../src/utils/subscription_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization removed to avoid Apple sign-in conflicts
  print("Firebase Core not initialized - using native Apple sign-in");

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize(); // Make sure this method exists in NotificationService

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
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Get the notification provider to manage WebSocket connection
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      // App is going to background or being terminated
        print('App going to background - closing WebSocket connection');
        notificationProvider.closeConnection();
        break;
      case AppLifecycleState.resumed:
      // App is coming to foreground
        if (userProvider.isLoggedIn && userProvider.token != null && userProvider.user != null) {
          print('App resumed - reconnecting WebSocket');
          notificationProvider.initWebSocket(
            userProvider.token!,
            userProvider.user!.id,
          );
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => GoogleSignInProvider(),
    child: MaterialApp(
      title: 'Barrim App',
      theme: ThemeData.light().copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoSwipeMaterialPageTransitionsBuilder(),
            TargetPlatform.iOS: NoSwipeCupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const MyHomePage(),
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

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebSocket();
    });
  }

  void _initializeWebSocket() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (userProvider.isLoggedIn &&
        userProvider.token != null &&
        userProvider.user != null &&
        !_websocketInitialized) {
      print('Initializing WebSocket for user: ${userProvider.user!.id}');
      notificationProvider.initWebSocket(
        userProvider.token!,
        userProvider.user!.id,
      );
      _websocketInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          // Background overlay
          Positioned.fill(
            child: Container(
              color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
            ),
          ),
          // Main content with responsive layout
          Column(
            children: [
              // Top spacer - takes up the space above the text
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
              // Bottom section with buttons
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
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.closeConnection();
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