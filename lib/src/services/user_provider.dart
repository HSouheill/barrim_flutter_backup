import 'package:flutter/material.dart';
import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/models/user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/session_manager.dart';
import 'notification_provider.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _error;
  User? _user;
  String? _token;
  String? _rememberMeToken; // Add remember me token field
  bool _isInitialized = false;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
  String? get token => _token;
  String? get rememberMeToken => _rememberMeToken; // Getter for remember me token
  bool get isLoggedIn => _user != null && _token != null;
  bool get isInitialized => _isInitialized;

  // Constructor to initialize session on app startup
  UserProvider() {
    _initializeSession();
  }

  // Initialize session by loading stored data
  Future<void> _initializeSession() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      // Check if session is valid using SessionManager
      final isValid = await SessionManager.isSessionValid();
      
      if (isValid) {
        // Restore session
        final token = await SessionManager.getToken();
        final userData = await SessionManager.getUserData();
        
        if (token != null && userData != null) {
          _token = token;
          _user = User.fromJson(json.decode(userData));
          _userData = json.decode(userData);
          print('Session restored successfully for user: ${_user?.id}');
          
          // Update last activity
          await SessionManager.updateLastActivity();
        }
      } else {
        print('Session is invalid or expired, session cleared');
        await _clearStoredData();
      }

      // Load remember me token from storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedRememberMeToken = prefs.getString('remember_me_token');
        if (storedRememberMeToken != null) {
          _rememberMeToken = storedRememberMeToken;
          print('Remember me token loaded from storage');
        }
      } catch (e) {
        print('Error loading remember me token: $e');
      }
    } catch (e) {
      print('Error initializing session: $e');
      await _clearStoredData();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Clear stored data
  Future<void> _clearStoredData() async {
    await SessionManager.clearSession();
    _token = null;
    _user = null;
    _userData = null;
    _rememberMeToken = null; // Clear remember me token
    
    // Clear remember me token from storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_me_token');
    } catch (e) {
      print('Error clearing remember me token: $e');
    }
  }

  // Set user data
  void setUser(Map<String, dynamic> userData) {
    _userData = userData;
    _user = User.fromJson(userData);
    _saveUserData(userData);
    notifyListeners();
  }

  // Set token
  void setToken(String token) {
    _token = token;
    _saveToken(token);
    notifyListeners();
  }

  // Set remember me token
  void setRememberMeToken(String token) {
    _rememberMeToken = token;
    _saveRememberMeToken(token);
    notifyListeners();
  }

  // Save token to storage
  Future<void> _saveToken(String token) async {
    if (_userData != null) {
      await SessionManager.saveSession(
        token: token,
        userData: json.encode(_userData!),
      );
    }
  }

  // Save remember me token to storage
  Future<void> _saveRememberMeToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remember_me_token', token);
    } catch (e) {
      print('Error saving remember me token: $e');
    }
  }

  // Save user data to storage
  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    if (_token != null) {
      await SessionManager.saveSession(
        token: _token!,
        userData: json.encode(userData),
      );
    }
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
      _saveUserData(userData);
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
    _saveUserData(userData);
    notifyListeners();
  }

  // Set user and token after login
  void setUserAndToken(User user, String token) {
    _user = user;
    _token = token;
    SessionManager.saveSession(
      token: token,
      userData: json.encode(user.toJson()),
    );
    notifyListeners();
  }

  // Clear user data (e.g., on logout)
  Future<void> clearUserData(BuildContext? context) async {
    _userData = null;
    _user = null;
    _token = null;
    _rememberMeToken = null; // Clear remember me token
    
    // Clear stored data
    await _clearStoredData();
    
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

  // Refresh session - call this when app resumes
  Future<bool> refreshSession() async {
    if (!isLoggedIn) return false;
    
    try {
      // Update last activity and check if session is still valid
      await SessionManager.updateLastActivity();
      final isValid = await SessionManager.isSessionValid();
      
      if (!isValid) {
        // Try to refresh the session using the refresh token
        final refreshResult = await SessionManager.refreshSession();
        
        if (refreshResult.success && refreshResult.newToken != null) {
          // Update the token and user data
          _token = refreshResult.newToken;
          if (refreshResult.newRefreshToken != null) {
            // Update refresh token if provided
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('refresh_token', refreshResult.newRefreshToken!);
          }
          
          // Get updated user data from server
          final sessionInfo = await SessionManager.getSessionInfoFromServer(_token!);
          if (sessionInfo != null && sessionInfo['valid'] == true && sessionInfo['user'] != null) {
            _user = User.fromJson(sessionInfo['user']);
            _userData = sessionInfo['user'];
          }
          
          notifyListeners();
          return true;
        } else {
          // Session refresh failed, clear user data
          await clearUserData(null);
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error refreshing session: $e');
      return false;
    }
  }

  // Auto-refresh session if it's about to expire
  Future<bool> autoRefreshSessionIfNeeded() async {
    if (!isLoggedIn) return false;
    
    try {
      final isExpiringSoon = await SessionManager.isSessionExpiringSoon();
      
      if (isExpiringSoon) {
        print('Session is expiring soon, attempting auto-refresh...');
        return await refreshSession();
      }
      
      return true;
    } catch (e) {
      print('Error in auto-refresh: $e');
      return false;
    }
  }

  // Check session status and handle accordingly
  Future<bool> checkAndHandleSession() async {
    if (!isLoggedIn) return false;
    
    try {
      // First check if session is valid
      final isValid = await SessionManager.isSessionValid();
      
      if (!isValid) {
        // Try to refresh the session
        return await refreshSession();
      }
      
      // Check if session is about to expire and auto-refresh if needed
      return await autoRefreshSessionIfNeeded();
    } catch (e) {
      print('Error checking and handling session: $e');
      return false;
    }
  }

  // Get detailed session information
  Future<Map<String, dynamic>?> getSessionInfo() async {
    if (!isLoggedIn || _token == null) return null;
    
    try {
      return await SessionManager.getSessionInfoFromServer(_token!);
    } catch (e) {
      print('Error getting session info: $e');
      return null;
    }
  }
}