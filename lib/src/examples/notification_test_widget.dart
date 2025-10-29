import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barrim/src/services/notification_service.dart';
import 'package:barrim/src/services/notification_provider.dart';
import 'package:barrim/src/services/booking_service.dart';
import 'package:barrim/src/models/booking.dart';
import 'package:barrim/src/utils/auth_manager.dart';

class NotificationTestWidget extends StatefulWidget {
  const NotificationTestWidget({Key? key}) : super(key: key);

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  final NotificationService _notificationService = NotificationService();
  BookingService? _bookingService;
  bool _isLoading = false;
  String _fcmToken = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final token = await AuthManager.getToken();
      if (token != null) {
        setState(() {
          _bookingService = BookingService(token: token);
        });
      }
      
      // Get FCM token
      final fcmToken = _notificationService.fcmToken;
      if (fcmToken != null) {
        setState(() {
          _fcmToken = fcmToken;
        });
      }
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  Future<void> _testLocalNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.showNotification(
        title: 'Test Local Notification',
        body: 'This is a test local notification from Flutter!',
        payload: 'test_local_notification',
      );
      
      _showSnackBar('Local notification sent!', Colors.green);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testFCMToken() async {
    try {
      final token = _notificationService.fcmToken;
      if (token != null) {
        _showSnackBar('FCM Token: $token', Colors.blue);
        print('FCM Token: $token');
      } else {
        _showSnackBar('FCM Token not available', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _testBookingNotification() async {
    if (_bookingService == null) {
      _showSnackBar('Please log in to test booking notifications', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Test with a dummy service provider ID
      final success = await _notificationService.sendBookingNotification(
        serviceProviderId: 'test-service-provider-id',
        customerName: 'Test Customer',
        serviceType: 'Test Service',
        bookingDate: 'Monday, Jan 15, 2024',
        timeSlot: '10:00 AM',
        bookingId: 'test-booking-123',
        isEmergency: false,
      );

      if (success) {
        _showSnackBar('Booking notification sent!', Colors.green);
      } else {
        _showSnackBar('Failed to send booking notification', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testTopicSubscription() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.subscribeToTopic('test_topic');
      _showSnackBar('Subscribed to test_topic', Colors.green);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testBackgroundNotifications() async {
    try {
      final notifications = await _notificationService.getBackgroundNotifications();
      _showSnackBar('Found ${notifications.length} background notifications', Colors.blue);
      
      if (notifications.isNotEmpty) {
        print('Background notifications: $notifications');
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _clearBackgroundNotifications() async {
    try {
      await _notificationService.clearBackgroundNotifications();
      _showSnackBar('Background notifications cleared', Colors.green);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FCM Token Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Token',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fcmToken.isEmpty ? 'Not available' : _fcmToken,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _testFCMToken,
                      child: const Text('Get FCM Token'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Buttons
            _buildTestButton(
              'Test Local Notification',
              'Send a local notification',
              Icons.notifications,
              _testLocalNotification,
            ),
            
            const SizedBox(height: 12),
            
            _buildTestButton(
              'Test Booking Notification',
              'Send a booking notification to service provider',
              Icons.calendar_today,
              _testBookingNotification,
            ),
            
            const SizedBox(height: 12),
            
            _buildTestButton(
              'Subscribe to Test Topic',
              'Subscribe to FCM topic for testing',
              Icons.topic,
              _testTopicSubscription,
            ),
            
            const SizedBox(height: 12),
            
            _buildTestButton(
              'Check Background Notifications',
              'View stored background notifications',
              Icons.history,
              _testBackgroundNotifications,
            ),
            
            const SizedBox(height: 12),
            
            _buildTestButton(
              'Clear Background Notifications',
              'Clear stored background notifications',
              Icons.clear_all,
              _clearBackgroundNotifications,
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Testing Instructions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Test local notifications work immediately\n'
                      '2. FCM notifications require backend setup\n'
                      '3. Check console logs for debugging\n'
                      '4. Test on both foreground and background\n'
                      '5. Verify notification permissions are granted',
                      style: TextStyle(fontSize: 14),
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

  Widget _buildTestButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios),
        onTap: _isLoading ? null : onPressed,
      ),
    );
  }
}
