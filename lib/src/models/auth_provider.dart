import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  bool _isLoading = false;

  // Getters
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  // Constructor to potentially load token from storage
  AuthProvider() {
    _loadTokenFromStorage();
  }

  // Load token from persistent storage
  Future<void> _loadTokenFromStorage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');

      if (storedToken != null && storedToken.isNotEmpty) {
        _token = storedToken;
      }
    } catch (e) {
      print('Failed to load token: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to set token when user logs in
  Future<void> setToken(String newToken) async {
    _token = newToken;

    // Save to persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', newToken);
    } catch (e) {
      print('Failed to save token: $e');
    }

    notifyListeners();
  }

  // Method to clear token when user logs out
  Future<void> logout() async {
    _token = null;

    // Remove from persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (e) {
      print('Failed to clear token: $e');
    }

    notifyListeners();
  }
}