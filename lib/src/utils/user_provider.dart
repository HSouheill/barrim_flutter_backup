import 'package:flutter/foundation.dart';

class User {
  final String id;
  final String email;
  // Add other user properties as needed

  User({
    required this.id,
    required this.email,
  });
}

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  String? _currentToken;

  // Getter for current user
  User? get currentUser => _currentUser;

  // Getter for current token
  String? get currentToken => _currentToken;

  // Check if user is logged in
  bool get isLoggedIn => _currentUser != null;

  // Login method
  void login(User user, String token) {
    _currentUser = user;
    _currentToken = token;
    notifyListeners();
  }

  // Logout method
  void logout() {
    _currentUser = null;
    _currentToken = null;
    notifyListeners();
  }

  // Update user method
  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  // Update token method
  void updateToken(String token) {
    _currentToken = token;
    notifyListeners();
  }
}