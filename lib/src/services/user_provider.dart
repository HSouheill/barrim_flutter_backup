import 'package:flutter/material.dart';
import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/models/user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  DateTime? _lastValidationTime; // Track last validation time
  String? _lastVisitedPage; // Track last visited page
  Map<String, dynamic>? _lastPageData; // Track data for last visited page
  
  // Secure storage for credentials
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
  String? get token => _token;
  String? get rememberMeToken => _rememberMeToken; // Getter for remember me token
  bool get isLoggedIn => _user != null && _token != null;
  bool get isInitialized => _isInitialized;
  String? get lastVisitedPage => _lastVisitedPage;
  Map<String, dynamic>? get lastPageData => _lastPageData;

  // Constructor to initialize session on app startup
  UserProvider() {
    _initializeSession();
  }

  // Initialize session by loading stored data (non-blocking)
  Future<void> _initializeSession() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      // Load stored data without server validation to avoid blocking
      final token = await SessionManager.getToken();
      final userData = await SessionManager.getUserData();
      
      if (token != null && userData != null) {
        _token = token;
        _user = User.fromJson(json.decode(userData));
        _userData = json.decode(userData);
        print('Session data loaded from storage for user: ${_user?.id}');
        
        // Validate session in background (non-blocking)
        _validateSessionInBackground();
      } else {
        print('No stored session data found');
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

      // Load last visited page
      await _loadLastVisitedPage();
    } catch (e) {
      print('Error initializing session: $e');
      await _clearStoredData();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Validate session in background without blocking the UI
  void _validateSessionInBackground() async {
    try {
      // Throttle validation to prevent excessive calls
      final now = DateTime.now();
      if (_lastValidationTime != null) {
        final timeSinceLastValidation = now.difference(_lastValidationTime!);
        if (timeSinceLastValidation.inMinutes < 2) {
          print('Skipping validation - too soon since last validation (${timeSinceLastValidation.inSeconds}s ago)');
          return;
        }
      }
      _lastValidationTime = now;
      
      // First do local validation (fast)
      final isLocallyValid = await SessionManager.isSessionValid(validateWithServer: false);
      
      if (!isLocallyValid) {
        print('Session locally invalid - clearing session');
        await _clearStoredData();
        notifyListeners();
        return;
      }
      
      // Try to refresh the session first before validating
      print('Attempting to refresh session before validation...');
      final refreshResult = await SessionManager.refreshSession();
      
      if (refreshResult.success) {
        print('Session refreshed successfully');
        // Update local data with new token
        if (refreshResult.newToken != null) {
          _token = refreshResult.newToken;
          _saveToken(refreshResult.newToken!);
        }
        await SessionManager.updateLastActivity();
        notifyListeners();
        return;
      }
      
      // If refresh failed, try server validation with more lenient error handling
      print('Session refresh failed, attempting server validation...');
      final isValid = await SessionManager.isSessionValid(validateWithServer: true).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Server validation timeout - keeping session for now');
          return true; // Assume valid to avoid blocking
        },
      );
      
      if (!isValid) {
        // Only clear session if we're certain it's invalid
        // Check if it's a network error vs actual authentication failure
        print('Server validation failed - checking if it\'s a network issue...');
        
        // Try one more quick validation to distinguish network vs auth errors
        final quickCheck = await SessionManager.isSessionValid(validateWithServer: false);
        if (quickCheck) {
          print('Local validation still passes - keeping session despite server validation failure');
          // Update last activity to keep session alive
          await SessionManager.updateLastActivity();
          return;
        }
        
        print('Both local and server validation failed - clearing session');
        await _clearStoredData();
        notifyListeners();
      } else {
        print('Session validated successfully with server');
        // Update last activity
        await SessionManager.updateLastActivity();
      }
    } catch (e) {
      print('Error validating session in background: $e');
      // Don't clear session on validation error to avoid false negatives
      // Only clear if it's a critical error that affects local storage
      if (e.toString().contains('storage') || e.toString().contains('corrupted')) {
        print('Critical storage error - clearing session');
        await _clearStoredData();
        notifyListeners();
      }
    }
  }

  // Clear stored data
  Future<void> _clearStoredData() async {
    await SessionManager.clearSession();
    _token = null;
    _user = null;
    _userData = null;
    _rememberMeToken = null; // Clear remember me token
    _lastVisitedPage = null; // Clear last visited page
    _lastPageData = null; // Clear last page data
    
    // Clear remember me token and last page from storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_me_token');
      await prefs.remove('last_visited_page');
      await prefs.remove('last_page_data');
    } catch (e) {
      print('Error clearing stored data: $e');
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

  // Save last visited page with full route information
  void saveLastVisitedPage(String pageName, {
    Map<String, dynamic>? pageData,
    String? routePath,
    Map<String, dynamic>? routeArguments,
  }) {
    _lastVisitedPage = pageName;
    _lastPageData = {
      'pageName': pageName,
      'pageData': pageData ?? {},
      'routePath': routePath ?? pageName,
      'routeArguments': routeArguments ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _saveLastPageToStorage();
    print('Saved last visited page: $pageName (route: ${routePath ?? pageName})');
  }

  // Clear last visited page
  void clearLastVisitedPage() {
    _lastVisitedPage = null;
    _lastPageData = null;
    _clearLastPageFromStorage();
    print('Cleared last visited page');
  }

  // Save last page to storage
  Future<void> _saveLastPageToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastVisitedPage != null) {
        await prefs.setString('last_visited_page', _lastVisitedPage!);
        if (_lastPageData != null) {
          await prefs.setString('last_page_data', json.encode(_lastPageData!));
        } else {
          await prefs.remove('last_page_data');
        }
      } else {
        await prefs.remove('last_visited_page');
        await prefs.remove('last_page_data');
      }
    } catch (e) {
      print('Error saving last visited page: $e');
    }
  }

  // Clear last page from storage
  Future<void> _clearLastPageFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_visited_page');
      await prefs.remove('last_page_data');
    } catch (e) {
      print('Error clearing last visited page: $e');
    }
  }

  // Load last visited page from storage
  Future<void> _loadLastVisitedPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getString('last_visited_page');
      final savedPageData = prefs.getString('last_page_data');
      
      if (savedPage != null) {
        _lastVisitedPage = savedPage;
        if (savedPageData != null) {
          try {
            _lastPageData = json.decode(savedPageData);
          } catch (e) {
            print('Error parsing last page data: $e');
            _lastPageData = null;
          }
        }
        print('Loaded last visited page: $savedPage');
      }
    } catch (e) {
      print('Error loading last visited page: $e');
    }
  }

  // Get current route information for restoration
  Map<String, dynamic>? getCurrentRouteInfo() {
    if (_lastPageData == null) return null;
    
    return {
      'pageName': _lastPageData!['pageName'],
      'routePath': _lastPageData!['routePath'],
      'pageData': _lastPageData!['pageData'],
      'routeArguments': _lastPageData!['routeArguments'],
      'timestamp': _lastPageData!['timestamp'],
    };
  }

  // Check if the saved route is still valid (not too old)
  bool isSavedRouteValid({Duration maxAge = const Duration(hours: 24)}) {
    if (_lastPageData == null) return false;
    
    final timestamp = _lastPageData!['timestamp'] as int?;
    if (timestamp == null) return false;
    
    final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final age = now.difference(savedTime);
    
    return age <= maxAge;
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
  Future<void> clearUserData(BuildContext? context, {bool clearCredentials = false}) async {
    _userData = null;
    _user = null;
    _token = null;
    _rememberMeToken = null; // Clear remember me token
    
    // Clear stored data
    await _clearStoredData();
    
    // Clear credentials if requested (e.g., when user explicitly logs out)
    if (clearCredentials) {
      await this.clearCredentials();
    }
    
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

  // Save credentials for Remember Me functionality
  Future<void> saveCredentials(String emailOrPhone, String password) async {
    try {
      await _secureStorage.write(key: 'saved_email_or_phone', value: emailOrPhone);
      await _secureStorage.write(key: 'saved_password', value: password);
      await _secureStorage.write(key: 'remember_me_enabled', value: 'true');
      print('Credentials saved for Remember Me');
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  // Load saved credentials
  Future<Map<String, String?>> loadCredentials() async {
    try {
      final emailOrPhone = await _secureStorage.read(key: 'saved_email_or_phone');
      final password = await _secureStorage.read(key: 'saved_password');
      final rememberMeEnabled = await _secureStorage.read(key: 'remember_me_enabled');
      
      if (emailOrPhone != null && password != null && rememberMeEnabled == 'true') {
        print('Saved credentials loaded');
        return {
          'emailOrPhone': emailOrPhone,
          'password': password,
          'rememberMe': 'true',
        };
      }
    } catch (e) {
      print('Error loading credentials: $e');
    }
    return {};
  }

  // Clear saved credentials
  Future<void> clearCredentials() async {
    try {
      await _secureStorage.delete(key: 'saved_email_or_phone');
      await _secureStorage.delete(key: 'saved_password');
      await _secureStorage.delete(key: 'remember_me_enabled');
      print('Saved credentials cleared');
    } catch (e) {
      print('Error clearing credentials: $e');
    }
  }

  // Check if Remember Me is enabled
  Future<bool> isRememberMeEnabled() async {
    try {
      final rememberMeEnabled = await _secureStorage.read(key: 'remember_me_enabled');
      return rememberMeEnabled == 'true';
    } catch (e) {
      print('Error checking Remember Me status: $e');
      return false;
    }
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