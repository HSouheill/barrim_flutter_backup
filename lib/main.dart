import 'package:barrim/src/services/google_auth_service.dart';
import 'package:barrim/src/services/notification_service.dart';
import 'package:barrim/src/services/notification_provider.dart';
import 'package:barrim/src/services/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barrim/src/features/authentication/screens/login_page.dart';
import 'package:barrim/src/features/authentication/screens/signup.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '../src/models/auth_provider.dart';
import '../src/utils/subscription_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();

  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization error: $e");
  }

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
      theme: ThemeData.light(),
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
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
            ),
          ),
          Positioned(
            left: (MediaQuery.of(context).size.width - 374) / 2,
            top: 362,
            child: SizedBox(
              width: 374,
              child: Text(
                'Discover the best of your neighborhood with Barrim!',
                textAlign: TextAlign.start,
                style: GoogleFonts.nunito(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  height: 1.375,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: 234,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(63),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 315,
                    height: 66,
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
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 220,
                    height: 55,
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
                          fontSize: 26,
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up WebSocket connection when leaving this page
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.closeConnection();
    super.dispose();
  }
}