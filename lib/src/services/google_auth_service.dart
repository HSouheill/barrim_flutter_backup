import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:io';

import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/utils/api_constants.dart';

class GoogleSignInProvider extends ChangeNotifier {
  GoogleSignIn? _googleSignIn;
  
  GoogleSignIn get googleSignIn {
    if (_googleSignIn == null) {
      // For Android, don't set clientId - it will be auto-detected from google-services.json
      // For iOS, set the client ID explicitly
      if (Platform.isAndroid) {
        _googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'profile',
          ],
          // clientId is not set for Android - it will be auto-detected from google-services.json
        );
      } else {
        _googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'profile',
          ],
          clientId: '307776183600-aoags2ect1p5i6rmebgsltb9ipsfin86.apps.googleusercontent.com', // iOS client ID from GoogleService-Info.plist
        );
      }
    }
    return _googleSignIn!;
  }
  GoogleSignInAccount? _user;
  GoogleSignInAccount get user => _user!;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Custom HTTP client with proper SSL handling ---
  static http.Client? _customClient;
  static Future<http.Client> _getCustomClient() async {
    if (_customClient != null) return _customClient!;
    
    // In production, use standard HTTP client for proper SSL validation
    // Let's Encrypt certificates are automatically trusted
    _customClient = http.Client();
    return _customClient!;
  }
  
  static Future<http.Response> _makeRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = await _getCustomClient();
    switch (method.toUpperCase()) {
      case 'GET':
        return await client.get(uri, headers: headers);
      case 'POST':
        return await client.post(uri, headers: headers, body: body);
      case 'PUT':
        return await client.put(uri, headers: headers, body: body);
      case 'DELETE':
        return await client.delete(uri, headers: headers, body: body);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

  Future<Map<String, dynamic>?> googleLogin() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check internet connection first
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection');
        }
      } on SocketException catch (_) {
        throw Exception('No internet connection. Please check your network settings and try again.');
      }

      // Start the Google Sign In process
      try {
        print("Starting Google Sign-In process...");
        print("Platform: ${Platform.isAndroid ? 'Android' : 'iOS'}");
        print("Client ID configured: ${Platform.isAndroid ? 'Yes' : 'Using default'}");
        
        // Sign out first to ensure fresh login
        await googleSignIn.signOut();
        print("Signed out from previous session");
        
        // Force a new sign-in to get fresh tokens
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          print("Google Sign-In was canceled by user");
          _isLoading = false;
          notifyListeners();
          return null; // User canceled the sign-in flow
        }
        _user = googleUser;
        print("Google Sign-In successful for user: ${googleUser.email}");
      } catch (e) {
        print("=========================================");
        print("Google Sign In ERROR DETAILS:");
        print("Error: $e");
        print("Error type: ${e.runtimeType}");
        print("Error string: ${e.toString()}");
        if (e is PlatformException) {
          print("Error code: ${e.code}");
          print("Error message: ${e.message}");
          print("Error details: ${e.details}");
        }
        print("=========================================");
        
        // More detailed error handling
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('network_error') || errorString.contains('network error')) {
          throw Exception('Network error occurred. Please check your connection and try again.');
        } else if (errorString.contains('sign_in_canceled') || errorString.contains('sign in canceled')) {
          _isLoading = false;
          notifyListeners();
          return null; // User canceled sign-in
        } else if (errorString.contains('sign_in_failed') || errorString.contains('sign in failed')) {
          // Provide more helpful error message
          String errorMsg = 'Google Sign-In failed. ';
          if (errorString.contains('developer_error') || errorString.contains('10:')) {
            errorMsg += 'Configuration error. Please ensure Google Sign-In is properly configured.';
          } else if (errorString.contains('api_not_connected') || errorString.contains('api not connected')) {
            errorMsg += 'Google Play Services is not available. Please update Google Play Services.';
          } else {
            errorMsg += 'Please check your Google account settings and try again.';
          }
          throw Exception(errorMsg);
        } else if (errorString.contains('developer_error') || errorString.contains('10:')) {
          throw Exception('Google Sign-In configuration error. Please check that the app is properly configured in Google Cloud Console and Firebase.');
        } else if (errorString.contains('api_not_connected') || errorString.contains('api not connected')) {
          throw Exception('Google Play Services is not available. Please update Google Play Services on your device.');
        } else {
          // Include the original error for debugging
          throw Exception('Failed to sign in with Google: ${e.toString()}');
        }
      }

      // Get the authentication details
      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await _user!.authentication;
        print("Successfully obtained Google auth tokens");
      } catch (e) {
        print("Error getting Google auth tokens: $e");
        throw Exception('Failed to get authentication tokens from Google: ${e.toString()}');
      }

      // Check if idToken is available
      if (googleAuth.idToken == null) {
        throw Exception('Failed to get ID token from Google authentication');
      }

      // Debug: Check token expiration
      try {
        final parts = googleAuth.idToken!.split('.');
        if (parts.length >= 2) {
          final payload = parts[1];
          // Fix base64 padding
          String paddedPayload = payload;
          while (paddedPayload.length % 4 != 0) {
            paddedPayload += '=';
          }
          final decodedPayload = base64Url.decode(paddedPayload);
          final payloadMap = jsonDecode(utf8.decode(decodedPayload));
          final exp = payloadMap['exp'];
          final iat = payloadMap['iat'];
          final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          
          print("Token debug - exp: $exp, iat: $iat, current: $currentTime");
          if (exp != null && currentTime > exp) {
            print("WARNING: Token appears to be expired!");
          }
        }
      } catch (e) {
        print("Could not decode token for debugging: $e");
      }

      // Send the Google ID token to your backend using the new endpoint
      http.Response? response;
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(seconds: 2);

      while (response == null && retryCount < maxRetries) {
        try {
          print("Attempting to send Google ID token to backend (attempt ${retryCount + 1})");

          final apiUrl = '${ApiService.baseUrl}${ApiConstants.googleAuthEndpoint}';
          print("API URL: $apiUrl");
          print("Base URL: ${ApiService.baseUrl}");
          print("Endpoint: ${ApiConstants.googleAuthEndpoint}");

          // Request body structure - backend expects idToken
          final requestBody = {
            'idToken': googleAuth.idToken,
          };

          print("Request body: ${jsonEncode(requestBody)}");
          print("Token length: ${googleAuth.idToken?.length}");
          print("Token starts with: ${googleAuth.idToken?.substring(0, 20)}...");

          response = await _makeRequest(
            'POST',
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 15));

          print("API response status code: ${response.statusCode}");
          print("API response body: ${response.body}");
        } catch (e) {
          print("API call error: $e");
          retryCount++;
          if (retryCount >= maxRetries) {
            throw Exception('Server communication failed: ${e.toString()}');
          }
          await Future.delayed(retryDelay);
        }
      }

      if (response == null) {
        throw Exception('Failed to communicate with server after multiple attempts');
      }

      // Parse response with error handling
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
        print("Decoded response data: $responseData");
      } catch (e) {
        print("JSON decode error: $e");
        throw Exception('Invalid response format from server: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Response structure from the backend endpoint
        final token = responseData['token'];
        final refreshToken = responseData['refreshToken'];
        final userData = responseData['user'];

        // Save token
        if (token != null) {
          await ApiService.saveToken(token);
        } else {
          throw Exception('Invalid response: Missing token');
        }

        // Save refresh token if available
        if (refreshToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('refresh_token', refreshToken);
        }

        // Save user data
        if (userData != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(userData));
        } else {
          throw Exception('Invalid response: Missing user data');
        }

        _isLoading = false;
        notifyListeners();
        
        // Return data in the expected format for the login page
        return {
          'token': token,
          'user': userData,
        };
      } else if (response.statusCode == 404 || 
                 response.statusCode == 422 ||
                 (response.statusCode == 400 && 
                 (responseData['message']?.toString().toLowerCase().contains('not found') == true ||
                  responseData['error']?.toString().toLowerCase().contains('not found') == true ||
                  responseData['message']?.toString().toLowerCase().contains('user not found') == true ||
                  responseData['error']?.toString().toLowerCase().contains('user not found') == true ||
                  responseData['message']?.toString().toLowerCase().contains('does not exist') == true ||
                  responseData['error']?.toString().toLowerCase().contains('does not exist') == true))) {
        // User doesn't exist - need to signup
        // Extract Google user information for signup
        print("User not found in database, preparing signup data");
        
        String fullName = '';
        String email = '';
        
        if (_user != null) {
          fullName = _user!.displayName ?? '';
          email = _user!.email;
          // If displayName is empty, try to extract from email
          if (fullName.isEmpty && email.isNotEmpty) {
            fullName = email.split('@')[0];
          }
        }
        
        final googleUserInfo = {
          'fullName': fullName,
          'email': email,
        };
        
        _isLoading = false;
        notifyListeners();
        
        // Return signup required response
        return {
          'needsSignup': true,
          'userData': googleUserInfo,
        };
      } else {
        // Handle other error responses
        String errorMessage;
        if (response.statusCode == 401) {
          errorMessage = responseData['error'] ?? responseData['message'] ?? 'Invalid Google credentials';
        } else if (response.statusCode == 400) {
          errorMessage = responseData['error'] ?? responseData['message'] ?? 'Invalid request format';
        } else if (response.statusCode == 500) {
          errorMessage = responseData['error'] ?? responseData['message'] ?? 'Server error occurred';
        } else {
          errorMessage = responseData['error'] ?? responseData['message'] ?? 'Failed to authenticate with backend';
        }
        throw Exception('$errorMessage (Status: ${response.statusCode})');
      }
    } catch (e) {
      print("GoogleSignInProvider error: $e");
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> logout() async {
    try {
      await googleSignIn.disconnect();
      await ApiService.clearToken();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');

      _user = null;
      notifyListeners();
    } catch (e) {
      print("Logout error: $e");
      _error = e.toString();
      notifyListeners();
    }
  }
}