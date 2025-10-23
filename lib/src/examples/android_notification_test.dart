import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidNotificationTest extends StatefulWidget {
  const AndroidNotificationTest({Key? key}) : super(key: key);

  @override
  State<AndroidNotificationTest> createState() => _AndroidNotificationTestState();
}

class _AndroidNotificationTestState extends State<AndroidNotificationTest> {
  String _fcmToken = 'Not available';
  String _permissionStatus = 'Unknown';
  bool _isLoading = false;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _checkPermissions();
    _getFCMToken();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(initializationSettings);
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.notification.status;
    setState(() {
      _permissionStatus = status.toString();
    });
  }

  Future<void> _getFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = token ?? 'No token available';
      });
    } catch (e) {
      setState(() {
        _fcmToken = 'Error: $e';
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request notification permissions
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      setState(() {
        _permissionStatus = settings.authorizationStatus.toString();
      });

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permissions granted!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permissions denied'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting permissions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLocalNotification() async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'barrim_fcm_channel',
        'Barrim FCM Notifications',
        channelDescription: 'Notifications from Firebase Cloud Messaging',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        0,
        'Test Notification',
        'This is a test notification from Android',
        platformDetails,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending test notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testBookingNotification() async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'booking_notifications',
        'Booking Notifications',
        channelDescription: 'Notifications about booking requests and updates',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.message,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        1,
        'New Booking Request',
        'John Doe wants to book your plumbing service for tomorrow at 2:00 PM',
        platformDetails,
        payload: 'booking_request_123',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking notification sent!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending booking notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android Notification Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Android Push Notification Configuration Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Token:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _fcmToken,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _getFCMToken,
                      child: const Text('Refresh Token'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permission Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_permissionStatus),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _requestPermissions,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Request Permissions'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Notifications:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _testLocalNotification,
                            child: const Text('Test General'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _testBookingNotification,
                            child: const Text('Test Booking'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Card(
              color: Colors.green,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Android Configuration Checklist:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '✅ Firebase dependencies added\n'
                      '✅ Google Services plugin configured\n'
                      '✅ google-services.json added\n'
                      '✅ POST_NOTIFICATIONS permission\n'
                      '✅ Firebase Messaging Service\n'
                      '✅ Notification channels configured\n'
                      '✅ MainActivity notification handling\n'
                      '⚠️  Test on physical device\n'
                      '⚠️  Check notification channels',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
