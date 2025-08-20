import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';
import 'dart:async';
import 'notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService;
  WebSocketChannel? _channel;
  String? _userId;
  String? _currentToken;
  List<Map<String, dynamic>> _notifications = [];
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  NotificationProvider(this._notificationService);

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isConnected => _isConnected;

  void initWebSocket(String token, String userId) {
    // Prevent multiple connections with the same credentials
    if (_isConnected && _currentToken == token && _userId == userId) {
      // print('WebSocket already connected with same credentials');
      return;
    }

    // Close existing connection if different credentials
    if (_channel != null) {
      // print('Closing existing WebSocket connection');
      _channel!.sink.close();
      _channel = null;
      _isConnected = false;
    }

    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    _userId = userId;
    _currentToken = token;

    _establishConnection();
  }

  void _establishConnection() {
    try {
      // print('Establishing new WebSocket connection for user: $_userId');
      _channel = IOWebSocketChannel.connect(
        'wss://barrim.online/api/ws',
        headers: {'Authorization': 'Bearer $_currentToken'},
      );

      _channel!.stream.listen(
        (message) {
          _handleNotification(message);
        },
        onError: (error) {
          // print('WebSocket error: $error');
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          // print('WebSocket connection closed');
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0; // Reset reconnect attempts on successful connection
      notifyListeners();
      // print('WebSocket connection established successfully');
    } catch (e) {
      // print('Failed to establish WebSocket connection: $e');
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts && _currentToken != null && _userId != null) {
      _reconnectAttempts++;
      // print('Scheduling WebSocket reconnect attempt $_reconnectAttempts in ${_reconnectDelay.inSeconds} seconds');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        // print('Attempting WebSocket reconnect...');
        _establishConnection();
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      // print('Max WebSocket reconnect attempts reached. Stopping reconnection.');
    }
  }

  void _handleNotification(dynamic message) {
    try {
      // print('Raw WebSocket message: $message');
      final notification = Map<String, dynamic>.from(json.decode(message));

      // print('Parsed Notification:');
      // print('Type: ${notification['type']}');
      // print('Message: ${notification['message']}');
      // print('Data: ${notification['data']}');

      // Check if this notification is already in the list to prevent duplicates
      bool isDuplicate = _notifications.any((existing) => 
        existing['type'] == notification['type'] && 
        existing['message'] == notification['message'] &&
        existing['data'] == notification['data']
      );

      if (!isDuplicate) {
        _notifications.add(notification);
        notifyListeners();

        _notificationService.showNotification(
          title: notification['type'] == 'booking_request'
              ? 'New Booking Request'
              : 'Booking Update',
          body: notification['message'],
          payload: json.encode(notification['data']),
        );
      } else {
        // print('Duplicate notification ignored');
      }
    } catch (e) {
      // print('Detailed Notification Error: $e');
      // print('Failed Message: $message');
    }
  }

  void closeConnection() {
    if (_channel != null) {
      // print('Closing WebSocket connection');
      _channel!.sink.close();
      _channel = null;
      _isConnected = false;
      _currentToken = null;
      _userId = null;
      notifyListeners();
    }
    
    // Cancel any pending reconnect attempts
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    closeConnection();
    super.dispose();
  }
} 