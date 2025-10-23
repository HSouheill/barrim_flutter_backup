import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_provider.dart';
import '../services/notification_service.dart';

/// Example widget demonstrating how to use FCM in your app
class FCMUsageExample extends StatefulWidget {
  const FCMUsageExample({super.key});

  @override
  State<FCMUsageExample> createState() => _FCMUsageExampleState();
}

class _FCMUsageExampleState extends State<FCMUsageExample> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _backgroundNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadBackgroundNotifications();
  }

  Future<void> _loadBackgroundNotifications() async {
    final notifications = await _notificationService.getBackgroundNotifications();
    setState(() {
      _backgroundNotifications = notifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Usage Example'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      _notificationService.fcmToken ?? 'Token not available',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'FCM Token: ${_notificationService.fcmToken ?? 'Not available'}',
                            ),
                          ),
                        );
                      },
                      child: const Text('Copy Token'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Topic Subscription
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Topic Subscription',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Topic Name',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(text: 'general'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await _notificationService.subscribeToTopic('general');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Subscribed to topic: general'),
                              ),
                            );
                          },
                          child: const Text('Subscribe'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Topic Name',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(text: 'general'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await _notificationService.unsubscribeFromTopic('general');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unsubscribed from topic: general'),
                              ),
                            );
                          },
                          child: const Text('Unsubscribe'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Background Notifications
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Background Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _loadBackgroundNotifications();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Background notifications refreshed'),
                              ),
                            );
                          },
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await _notificationService.clearBackgroundNotifications();
                        await _loadBackgroundNotifications();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Background notifications cleared'),
                          ),
                        );
                      },
                      child: const Text('Clear All'),
                    ),
                    const SizedBox(height: 16),
                    if (_backgroundNotifications.isEmpty)
                      const Text('No background notifications')
                    else
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _backgroundNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = _backgroundNotifications[index];
                            return ListTile(
                              title: Text(notification['title'] ?? 'No Title'),
                              subtitle: Text(notification['body'] ?? 'No Body'),
                              trailing: Text(
                                notification['timestamp'] != null
                                    ? DateTime.parse(notification['timestamp'])
                                        .toString()
                                        .substring(0, 19)
                                    : 'Unknown time',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Local Notification
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Local Notification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _notificationService.showNotification(
                          title: 'Test Notification',
                          body: 'This is a test notification from FCM example',
                          payload: '{"type": "test", "data": "example"}',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test notification sent'),
                          ),
                        );
                      },
                      child: const Text('Send Test Notification'),
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

/// Example of how to integrate FCM with your existing user authentication
class FCMIntegrationExample {
  final NotificationProvider _notificationProvider;
  final NotificationService _notificationService;

  FCMIntegrationExample(this._notificationProvider, this._notificationService);

  /// Call this when user logs in
  Future<void> onUserLogin(String userId, String token) async {
    // Initialize WebSocket (which will also send FCM token)
    _notificationProvider.initWebSocket(token, userId);
    
    // Subscribe to user-specific topics
    await _notificationService.subscribeToTopic('user_$userId');
    await _notificationService.subscribeToTopic('general');
    
    // Send FCM token to server
    await _notificationService.sendTokenToServer(userId);
  }

  /// Call this when user logs out
  Future<void> onUserLogout() async {
    // Close WebSocket connection
    _notificationProvider.closeConnection();
    
    // Unsubscribe from all topics
    // Note: You might want to track subscribed topics to unsubscribe properly
    await _notificationService.unsubscribeFromTopic('general');
    
    // Clear background notifications
    await _notificationService.clearBackgroundNotifications();
  }

  /// Call this when user changes their notification preferences
  Future<void> updateNotificationPreferences(
    String userId,
    List<String> topics,
  ) async {
    // Unsubscribe from all current topics first
    // (You'd need to track current topics)
    
    // Subscribe to new topics
    for (final topic in topics) {
      await _notificationService.subscribeToTopic(topic);
    }
  }
}

/// Example of how to handle different types of notifications
class NotificationHandler {
  static void handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'booking_request':
        // Navigate to booking details
        print('Navigate to booking request: ${data['booking_id']}');
        break;
      case 'booking_update':
        // Navigate to booking status
        print('Navigate to booking update: ${data['booking_id']}');
        break;
      case 'promotion':
        // Navigate to promotion details
        print('Navigate to promotion: ${data['promotion_id']}');
        break;
      default:
        // Navigate to general notifications screen
        print('Navigate to notifications screen');
        break;
    }
  }
}
