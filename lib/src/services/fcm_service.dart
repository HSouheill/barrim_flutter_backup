import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();
  
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');
  }
  
  // Store the notification for later processing
  await _storeBackgroundNotification(message);
}

/// Store background notification for later processing
Future<void> _storeBackgroundNotification(RemoteMessage message) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final notifications = prefs.getStringList('background_notifications') ?? [];
    
    final notificationData = {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? 'Notification',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    notifications.add(json.encode(notificationData));
    
    // Keep only the last 50 notifications
    if (notifications.length > 50) {
      notifications.removeRange(0, notifications.length - 50);
    }
    
    await prefs.setStringList('background_notifications', notifications);
  } catch (e) {
    if (kDebugMode) {
      print('Error storing background notification: $e');
    }
  }
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _isInitialized = false;
  
  // Getters
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Initialize FCM service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Request permission for notifications
      await _requestPermission();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Set up message handlers
      _setupMessageHandlers();
      
      // Get FCM token
      await _getFCMToken();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('FCM Service initialized successfully');
        print('FCM Token: $_fcmToken');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing FCM Service: $e');
      }
      rethrow;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'barrim_fcm_channel',
        'Barrim FCM Notifications',
        description: 'Notifications from Firebase Cloud Messaging',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle notification tap when app is terminated
    _handleInitialMessage();
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode) {
          print('FCM Token refreshed: $newToken');
        }
        // You can send the new token to your server here
        _onTokenRefresh(newToken);
      });
      
      if (kDebugMode) {
        print('FCM Token obtained: $_fcmToken');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
    }

    // Show local notification for foreground messages
    await _showLocalNotification(message);
  }

  /// Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    if (kDebugMode) {
      print('Notification tapped: ${message.messageId}');
      print('Data: ${message.data}');
    }
    
    // Handle navigation based on notification data
    _handleNotificationNavigation(message.data);
  }

  /// Handle initial message (when app is opened from terminated state)
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('App opened from terminated state via notification');
      }
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'barrim_fcm_channel',
      'Barrim FCM Notifications',
      channelDescription: 'Notifications from Firebase Cloud Messaging',
      importance: Importance.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: json.encode(message.data),
    );
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('Local notification tapped: ${response.payload}');
    }
    
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        _handleNotificationNavigation(Map<String, dynamic>.from(data));
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Implement navigation logic based on notification data
    // This will depend on your app's navigation structure
    if (kDebugMode) {
      print('Handling notification navigation with data: $data');
    }
    
    // Example navigation logic:
    // - Check data['type'] for notification type
    // - Navigate to appropriate screen
    // - Pass relevant data to the screen
  }

  /// Handle token refresh
  void _onTokenRefresh(String newToken) {
    // Send new token to your server
    // This is where you'd typically make an API call to update the token
    if (kDebugMode) {
      print('FCM Token refreshed, should send to server: $newToken');
    }
    
    // Trigger token update callback if registered
    if (_onTokenRefreshCallback != null) {
      _onTokenRefreshCallback!(newToken);
    }
  }
  
  // Callback for token refresh
  Function(String)? _onTokenRefreshCallback;
  
  /// Register callback for token refresh
  void onTokenRefresh(Function(String) callback) {
    _onTokenRefreshCallback = callback;
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic $topic: $e');
      }
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic $topic: $e');
      }
    }
  }

  /// Get background notifications
  Future<List<Map<String, dynamic>>> getBackgroundNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = prefs.getStringList('background_notifications') ?? [];
      
      return notifications.map((notificationJson) {
        return Map<String, dynamic>.from(json.decode(notificationJson));
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting background notifications: $e');
      }
      return [];
    }
  }

  /// Clear background notifications
  Future<void> clearBackgroundNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('background_notifications');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing background notifications: $e');
      }
    }
  }

  /// Send token to server
  Future<void> sendTokenToServer(String token, String userId) async {
    // Implement API call to send FCM token to your server
    // This should be called when user logs in or token refreshes
    if (kDebugMode) {
      print('Should send FCM token to server: $token for user: $userId');
    }
    
    // Example implementation:
    // try {
    //   await ApiService.sendFCMToken(token, userId);
    // } catch (e) {
    //   print('Error sending FCM token to server: $e');
    // }
  }

  /// Dispose resources
  void dispose() {
    // Clean up any resources if needed
  }
}
