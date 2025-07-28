import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import 'session_manager.dart';

class DebugSession {
  static Future<void> logSessionInfo(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final sessionInfo = await SessionManager.getSessionInfo();
    
    print('=== SESSION DEBUG INFO ===');
    print('UserProvider.isLoggedIn: ${userProvider.isLoggedIn}');
    print('UserProvider.isInitialized: ${userProvider.isInitialized}');
    print('UserProvider.token: ${userProvider.token != null ? 'Token exists' : 'No token'}');
    print('UserProvider.user: ${userProvider.user != null ? 'User exists (${userProvider.user!.id})' : 'No user'}');
    print('SessionManager.hasToken: ${sessionInfo['hasToken']}');
    print('SessionManager.hasUserData: ${sessionInfo['hasUserData']}');
    print('SessionManager.lastActivity: ${sessionInfo['lastActivity']}');
    print('SessionManager.tokenExpired: ${sessionInfo['tokenExpired']}');
    print('SessionManager.isSessionValid: ${await SessionManager.isSessionValid()}');
    print('========================');
  }

  static Future<void> clearSessionForTesting(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await SessionManager.clearSession();
    userProvider.clearUserData(context);
    print('Session cleared for testing');
  }

  static Future<void> simulateAppBackground(BuildContext context) async {
    print('Simulating app going to background...');
    // This would be called by the app lifecycle
    await SessionManager.updateLastActivity();
    print('Last activity updated');
  }

  static Future<void> simulateAppResume(BuildContext context) async {
    print('Simulating app resume...');
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isValid = await userProvider.refreshSession();
    print('Session refresh result: $isValid');
  }
} 