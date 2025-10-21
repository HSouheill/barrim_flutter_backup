import 'package:flutter/material.dart';
import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/models/user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../utils/session_manager.dart';
import 'notification_provider.dart';
import 'extended_session_service.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _error;
  User? _user;
  String? _token;
  String? _rememberMeToken; // Add remember me token field
  bool _isInitialized = false;
  DateTime? _lastValidationTime; // Track last validation time
  DateTime? _lastLoginTime; // Track last login time to prevent aggressive validation
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
      // First try to load from extended session service
      final extendedToken = await ExtendedSessionService.getToken();
      final extendedUserData = await ExtendedSessionService.getUserData();
      
      if (extendedToken != null && extendedUserData != null) {
        // Check if extended session is valid
        final isExtendedValid = await ExtendedSessionService.isSessionValid();
        
        if (isExtendedValid) {
          _token = extendedToken;
          _user = User.fromJson(json.decode(extendedUserData));
          _userData = json.decode(extendedUserData);
          print('Extended session data loaded from storage for user: ${_user?.id}');
          
          // Load last visited page from extended session
          await _loadLastVisitedPageFromExtended();
          
          // Validate session in background (non-blocking)
          _validateExtendedSessionInBackground();
        } else {
          print('Extended session expired, falling back to regular session');
          await _loadRegularSession();
        }
      } else {
        // Fall back to regular session manager
        await _loadRegularSession();
      }

      // Load last login time
      await _loadLastLoginTime();
    } catch (e) {
      print('Error initializing session: $e');
      await _clearStoredData();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  // Load regular session from SessionManager
  Future<void> _loadRegularSession() async {
    try {
      final token = await SessionManager.getToken();
      final userData = await SessionManager.getUserData();
      
      if (token != null && userData != null) {
        _token = token;
        _user = User.fromJson(json.decode(userData));
        _userData = json.decode(userData);
        print('Regular session data loaded from storage for user: ${_user?.id}');
        
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
      print('Error loading regular session: $e');
      await _clearStoredData();
    }
  }
  
  // Load last login time from storage
  Future<void> _loadLastLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLoginTimestamp = prefs.getInt('last_login_time');
      
      if (lastLoginTimestamp != null) {
        _lastLoginTime = DateTime.fromMillisecondsSinceEpoch(lastLoginTimestamp);
        print('Loaded last login time: ${_lastLoginTime}');
      }
    } catch (e) {
      print('Error loading last login time: $e');
    }
  }
  
  // Save last login time to storage
  Future<void> _saveLastLoginTime() async {
    try {
      if (_lastLoginTime != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_login_time', _lastLoginTime!.millisecondsSinceEpoch);
        print('Saved last login time: ${_lastLoginTime}');
      }
    } catch (e) {
      print('Error saving last login time: $e');
    }
  }

  // Validate session in background without blocking the UI
  void _validateSessionInBackground() async {
    try {
      // Throttle validation to prevent excessive calls
      final now = DateTime.now();
      
      // Skip validation if user just logged in (within last 5 minutes)
      if (_lastLoginTime != null) {
        final timeSinceLogin = now.difference(_lastLoginTime!);
        if (timeSinceLogin.inMinutes < 5) {
          print('Skipping validation - user just logged in ${timeSinceLogin.inSeconds}s ago');
          return;
        }
      }
      
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
      
      // Just update last activity without aggressive validation/refresh
      // This prevents clearing the session right after login
      print('Updating last activity for background session monitoring');
      await SessionManager.updateLastActivity();
      print('Session background monitoring completed successfully');
    } catch (e) {
      print('Error in background session monitoring: $e');
      // Don't clear session on monitoring error - just log it
    }
  }

  // Clear stored data
  Future<void> _clearStoredData() async {
    // Clear both regular and extended session data
    await Future.wait([
      SessionManager.clearSession(),
      ExtendedSessionService.clearSession(),
    ]);
    
    _token = null;
    _user = null;
    _userData = null;
    _rememberMeToken = null; // Clear remember me token
    _lastVisitedPage = null; // Clear last visited page
    _lastPageData = null; // Clear last page data
    _lastLoginTime = null; // Clear last login time
    
    // Clear remember me token and last page from storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remember_me_token');
      await prefs.remove('last_visited_page');
      await prefs.remove('last_page_data');
      await prefs.remove('last_login_time');
    } catch (e) {
      print('Error clearing stored data: $e');
    }
  }

  // Set user data
  void setUser(Map<String, dynamic> userData) {
    _userData = userData;
    _user = User.fromJson(userData);
    
    // Record login time to prevent aggressive validation immediately after login
    _lastLoginTime = DateTime.now();
    _saveLastLoginTime();
    
    _saveUserData(userData);
    notifyListeners();
  }

  // Set token
  void setToken(String token) {
    _token = token;
    
    // Record login time to prevent aggressive validation immediately after login
    _lastLoginTime = DateTime.now();
    _saveLastLoginTime();
    
    _saveToken(token);
    notifyListeners();
  }

  // Set both user and token together (for Google/Apple sign-in)
  Future<void> setUserAndTokenTogether(Map<String, dynamic> userData, String token) async {
    _userData = userData;
    _user = User.fromJson(userData);
    _token = token;
    
    // Record login time to prevent aggressive validation immediately after login
    _lastLoginTime = DateTime.now();
    await _saveLastLoginTime();
    
    // Save session with both token and user data
    await SessionManager.saveSession(
      token: token,
      userData: json.encode(userData),
    );
    
    print('User and token saved successfully. Login time recorded.');
    notifyListeners();
  }
  
  // Set user and token with extended session support
  Future<void> setUserAndTokenWithExtendedSession(
    Map<String, dynamic> userData, 
    String token, {
    bool rememberMe = false,
    String? refreshToken,
  }) async {
    _userData = userData;
    _user = User.fromJson(userData);
    _token = token;
    
    // Record login time to prevent aggressive validation immediately after login
    _lastLoginTime = DateTime.now();
    await _saveLastLoginTime();
    
    // Save to both regular and extended session services
    await Future.wait([
      SessionManager.saveSession(
        token: token,
        userData: json.encode(userData),
      ),
      ExtendedSessionService.saveExtendedSession(
        token: token,
        userData: json.encode(userData),
        refreshToken: refreshToken,
        rememberMe: rememberMe,
      ),
    ]);
    
    print('User and token saved with extended session support (Remember Me: $rememberMe)');
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
    
    // Save to both regular and extended session storage
    _saveLastPageToStorage();
    _saveLastPageToExtendedStorage(pageName, pageData, routePath, routeArguments);
    
    print('Saved last visited page: $pageName (route: ${routePath ?? pageName})');
  }
  
  // Save last page to extended storage
  Future<void> _saveLastPageToExtendedStorage(
    String pageName,
    Map<String, dynamic>? pageData,
    String? routePath,
    Map<String, dynamic>? routeArguments,
  ) async {
    try {
      await ExtendedSessionService.saveLastVisitedPage(
        pageName,
        pageData: pageData,
        routePath: routePath,
        routeArguments: routeArguments,
      );
    } catch (e) {
      print('Error saving last page to extended storage: $e');
    }
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
  
  // Load last visited page from extended session
  Future<void> _loadLastVisitedPageFromExtended() async {
    try {
      final savedPage = await ExtendedSessionService.getLastVisitedPage();
      final savedPageData = await ExtendedSessionService.getLastPageData();
      
      if (savedPage != null) {
        _lastVisitedPage = savedPage;
        _lastPageData = savedPageData;
        print('Loaded last visited page from extended session: $savedPage');
      }
    } catch (e) {
      print('Error loading last visited page from extended session: $e');
    }
  }
  
  // Validate extended session in background
  void _validateExtendedSessionInBackground() async {
    try {
      // Throttle validation to prevent excessive calls
      final now = DateTime.now();
      
      // Skip validation if user just logged in (within last 5 minutes)
      if (_lastLoginTime != null) {
        final timeSinceLogin = now.difference(_lastLoginTime!);
        if (timeSinceLogin.inMinutes < 5) {
          print('Skipping extended validation - user just logged in ${timeSinceLogin.inSeconds}s ago');
          return;
        }
      }
      
      if (_lastValidationTime != null) {
        final timeSinceLastValidation = now.difference(_lastValidationTime!);
        if (timeSinceLastValidation.inMinutes < 10) {
          print('Skipping extended validation - too soon since last validation (${timeSinceLastValidation.inSeconds}s ago)');
          return;
        }
      }
      _lastValidationTime = now;
      
      // First do local validation (fast)
      final isLocallyValid = await ExtendedSessionService.isSessionValid(validateWithServer: false);
      
      if (!isLocallyValid) {
        print('Extended session locally invalid - clearing session');
        await _clearStoredData();
        notifyListeners();
        return;
      }
      
      // Just update last activity without aggressive validation/refresh
      print('Updating last activity for extended session monitoring');
      await ExtendedSessionService.updateLastActivity();
      print('Extended session background monitoring completed successfully');
    } catch (e) {
      print('Error in extended session background monitoring: $e');
      // Don't clear session on monitoring error - just log it
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
  
  // Check if the saved route is valid with extended timeout (for remember me)
  Future<bool> isSavedRouteValidExtended({Duration maxAge = const Duration(days: 365)}) async {
    try {
      return await ExtendedSessionService.isSavedRouteValid(maxAge: maxAge);
    } catch (e) {
      print('Error checking extended route validity: $e');
      return false;
    }
  }
  
  // Get current route information from extended session
  Future<Map<String, dynamic>?> getCurrentRouteInfoFromExtended() async {
    try {
      return await ExtendedSessionService.getCurrentRouteInfo();
    } catch (e) {
      print('Error getting current route info from extended session: $e');
      return null;
    }
  }

  // Save token to storage
  Future<void> _saveToken(String token) async {
    if (_userData != null) {
      await SessionManager.saveSession(
        token: token,
        userData: json.encode(_userData!),
      );
    } else {
      print('Warning: Attempting to save token without user data');
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
    } else {
      print('Warning: Attempting to save user data without token');
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
    _userData = user.toJson();
    
    // Record login time to prevent aggressive validation immediately after login
    _lastLoginTime = DateTime.now();
    _saveLastLoginTime();
    
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
      // First try extended session refresh
      final isExtendedValid = await ExtendedSessionService.isSessionValid();
      if (isExtendedValid) {
        await ExtendedSessionService.updateLastActivity();
        return true;
      }
      
      // Fall back to regular session refresh
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