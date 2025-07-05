import 'package:flutter/material.dart';
import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/models/user.dart';
import 'package:provider/provider.dart';
import 'notification_provider.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _error;
  User? _user;
  String? _token;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _user != null && _token != null;

  // Set user data
  void setUser(Map<String, dynamic> userData) {
    _userData = userData;
    _user = User.fromJson(userData);
    notifyListeners();
  }

  // Set token
  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  // Call this method when the app starts or after login
  Future<void> fetchUserData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Using your existing API service
      final userData = await ApiService.getUserData();
      _userData = userData;
      _user = User.fromJson(userData);
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error fetching user data: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user data (e.g., after profile edit)
  void updateUserData(Map<String, dynamic> userData) {
    _userData = userData;
    _user = User.fromJson(userData);
    notifyListeners();
  }

  // Set user and token after login
  void setUserAndToken(User user, String token) {
    _user = user;
    _token = token;
    notifyListeners();
  }

  // Clear user data (e.g., on logout)
  void clearUserData(BuildContext? context) {
    _userData = null;
    _user = null;
    _token = null;
    
    // Close WebSocket connection if context is provided
    if (context != null) {
      try {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.closeConnection();
        print('WebSocket connection closed during logout');
      } catch (e) {
        print('Error closing WebSocket during logout: $e');
      }
    }
    
    notifyListeners();
  }
}