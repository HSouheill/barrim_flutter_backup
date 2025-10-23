import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'fcm_service.dart';
import 'api_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FCMService _fcmService = FCMService();

  Future<void> initialize() async {
    // Initialize FCM service
    await _fcmService.initialize();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        if (!kReleaseMode) {
          print('Notification tapped: ${details.payload}');
        }
      },
    );

    // Request permissions for iOS
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Input validation
    if (title.trim().isEmpty) {
      throw Exception('Notification title is required');
    }
    if (body.trim().isEmpty) {
      throw Exception('Notification body is required');
    }
    
    // Sanitize inputs
    final sanitizedTitle = title.trim();
    final sanitizedBody = body.trim();
    final sanitizedPayload = payload?.trim();
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'barrim_channel',
      'Barrim Notifications',
      channelDescription: 'Notifications for Barrim app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      sanitizedTitle,
      sanitizedBody,
      notificationDetails,
      payload: sanitizedPayload,
    );
  }

  /// Get FCM token
  String? get fcmToken => _fcmService.fcmToken;

  /// Send FCM token to server for users
  Future<void> sendTokenToServer(String userId) async {
    if (_fcmService.fcmToken != null) {
      await ApiService.sendFCMTokenToServer(_fcmService.fcmToken!, userId);
    }
  }

  /// Send FCM token to server for service providers
  Future<void> sendServiceProviderTokenToServer() async {
    if (_fcmService.fcmToken != null) {
      await ApiService.sendServiceProviderFCMTokenToServer(_fcmService.fcmToken!);
    }
  }

  /// Subscribe to FCM topic
  Future<void> subscribeToTopic(String topic) async {
    await _fcmService.subscribeToTopic(topic);
  }

  /// Unsubscribe from FCM topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcmService.unsubscribeFromTopic(topic);
  }

  /// Get background notifications
  Future<List<Map<String, dynamic>>> getBackgroundNotifications() async {
    return await _fcmService.getBackgroundNotifications();
  }

  /// Clear background notifications
  Future<void> clearBackgroundNotifications() async {
    await _fcmService.clearBackgroundNotifications();
  }

  /// Send notification to service provider via API
  Future<bool> sendNotificationToServiceProvider({
    required String serviceProviderId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('Sending notification to service provider: $serviceProviderId');
      print('Title: $title');
      print('Message: $message');
      print('Data: $data');
      
      // Call the API to send notification
      final success = await ApiService.sendNotificationToServiceProvider(
        serviceProviderId: serviceProviderId,
        title: title,
        message: message,
        data: data,
      );
      
      if (success) {
        print('Notification sent successfully to service provider: $serviceProviderId');
      } else {
        print('Failed to send notification to service provider: $serviceProviderId');
      }
      
      return success;
    } catch (e) {
      print('Error sending notification to service provider: $e');
      return false;
    }
  }

  /// Send booking notification to service provider
  Future<bool> sendBookingNotification({
    required String serviceProviderId,
    required String customerName,
    required String serviceType,
    required String bookingDate,
    required String timeSlot,
    required String bookingId,
    required bool isEmergency,
  }) async {
    final title = isEmergency ? '🚨 Emergency Booking Request' : 'New Booking Request';
    final message = isEmergency 
        ? 'Emergency booking from $customerName for $serviceType on $bookingDate at $timeSlot'
        : 'New booking from $customerName for $serviceType on $bookingDate at $timeSlot';
    
    final data = {
      'type': 'booking_request',
      'bookingId': bookingId,
      'serviceProviderId': serviceProviderId,
      'customerName': customerName,
      'serviceType': serviceType,
      'bookingDate': bookingDate,
      'timeSlot': timeSlot,
      'isEmergency': isEmergency,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return await sendNotificationToServiceProvider(
      serviceProviderId: serviceProviderId,
      title: title,
      message: message,
      data: data,
    );
  }

  /// Dispose resources
  void dispose() {
    _fcmService.dispose();
  }
}