import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'companyProfileSettings.dart';
import 'company_notification_settings.dart';
import '../responsive_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/token_manager.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_provider.dart';
import 'company_dashboard.dart';
import '../login_page.dart';
import 'package:barrim/src/components/secure_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({Key? key}) : super(key: key);

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  String? logoUrl;
  final TokenManager _tokenManager = TokenManager();
  final AuthService _authService = AuthService();
  Map<String, dynamic> userData = {};
  String? companyEmail;
  bool _isLoggingOut = false; // Add loading state for logout
  @override
  void initState() {
    super.initState();
    print('CompanySettingsPage: initState called');
    print('CompanySettingsPage: AuthService baseUrl: ${_authService.baseUrl}');
    print('CompanySettingsPage: ApiService baseUrl: ${ApiService.baseUrl}');
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    try {
      final token = await _tokenManager.getToken();
      if (token?.isNotEmpty == true) {
        var data = await ApiService.getCompanyData(token!);
        String? email;
        if (data['companyInfo'] != null) {
          // Fetch email using ApiService.getUserProfile
          var userProfile = await ApiService.getUserProfile(token);
          email = userProfile['email'];
          setState(() {
            logoUrl = data['companyInfo']['logo'];
            userData = data['companyInfo'];
            // Add token to userData so it can be passed to other screens
            userData['token'] = token;
            companyEmail = email;
          });
        }
      }
    } catch (error) {
      print('Error loading company data: $error');
    }
  }

  void _showLogoutConfirmationDialog() {
    print('CompanySettingsPage: _showLogoutConfirmationDialog called');
    showDialog(
      context: context,
      barrierDismissible: !_isLoggingOut, // Prevent dismissal while logging out
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: _isLoggingOut ? null : () {
                print('CompanySettingsPage: Cancel button pressed');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isLoggingOut ? null : () {
                print('CompanySettingsPage: Logout button pressed in dialog');
                Navigator.pop(context);
                print('CompanySettingsPage: About to call _performLogout()');
                _performLogout();
              },
              child: _isLoggingOut 
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Logging out...'),
                      ],
                    )
                  : const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      print('CompanySettingsPage: _performLogout called');
      
      // Show loading indicator
      setState(() {
        _isLoggingOut = true;
      });

      print('CompanySettingsPage: Loading state set to true');

      // Try to get UserProvider and clear user data
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        print('CompanySettingsPage: UserProvider obtained');
        await userProvider.clearUserData(context);
        print('CompanySettingsPage: UserProvider data cleared');
      } catch (e) {
        print('CompanySettingsPage: Error with UserProvider: $e');
        print('CompanySettingsPage: Continuing with other logout steps...');
      }

      // Call the logout endpoint and clear token
      print('CompanySettingsPage: Calling _authService.logout()');
      await _authService.logout();
      print('CompanySettingsPage: _authService.logout() completed');

      // Clear any stored company data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('company_data');
      await prefs.remove('company_contact_data');
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      print('CompanySettingsPage: All local data cleared');

      // Navigate to login page and clear navigation stack
      if (mounted) {
        print('CompanySettingsPage: Navigating to login page');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('CompanySettingsPage: Error during logout: $e');
      
      // Even if there's an error, try to clear local data and navigate
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('company_data');
        await prefs.remove('company_contact_data');
        await prefs.remove('auth_token');
        await prefs.remove('user_data');
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginPage()),
            (route) => false,
          );
        }
      } catch (clearError) {
        print('CompanySettingsPage: Error clearing local data: $clearError');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always reset loading state
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
        print('CompanySettingsPage: Loading state reset to false');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullLogoUrl = logoUrl != null ? '${ApiService.baseUrl}/$logoUrl' : null;

    return Scaffold(
      body: Column(
        children: [
          // Header with gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF2079C2),
                  Color(0xFF1F4889),
                  Color(0xFF10105D),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.only(  // Add this for bottom rounding
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    // Top bar with logo and notification icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back button - Barrim logo
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CompanyDashboard(userData: userData),
                              ),
                            );
                          },
                          child: Image.asset('assets/logo/barrim_logo.png', height: 60),
                        ),

                        // Right side icons
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CompanyDashboard(userData: userData),
                                  ),
                                );
                              },
                              child: ClipOval(
                                child: (logoUrl != null && logoUrl!.isNotEmpty)
                                    ? Image.network(
                                        fullLogoUrl!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Image.asset(
                                            'assets/logo/barrim_logo1.png',
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      )
                                    : Image.asset(
                                        'assets/logo/barrim_logo1.png',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CompanyNotificationSettingsPage(userData: userData),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // User info section
                    GestureDetector(
                      onTap: () {
                        // Navigate to company profile settings
                       Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompanyProfileSettings(userData: userData),
                            ),
                          );
                          },
                      child: Row(
                        children: [
                          ClipOval(
                            child: (logoUrl != null && logoUrl!.isNotEmpty)
                                ? Image.network(
                                    fullLogoUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/logo/barrim_logo1.png',
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                                : Image.asset(
                                    'assets/logo/barrim_logo1.png',
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['name'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  companyEmail ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Notifications button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF0094FF),
                    Color(0xFF05055A),
                    Color(0xFF0094FF),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                title: Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.7,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
                onTap: () {
                 Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompanyNotificationSettingsPage(userData: userData),
                        ),
                      );
                },
              ),
            ),
          ),

          // Logout button with red door icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFE53E3E), // Red color
                    Color(0xFFC53030), // Darker red
                    Color(0xFFE53E3E), // Red color
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: _isLoggingOut
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.exit_to_app, // Exit door icon
                        color: Colors.white,
                        size: 22,
                      ),
                title: Text(
                  _isLoggingOut ? 'Logging out...' : 'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.7,
                  ),
                ),
                trailing: _isLoggingOut
                    ? null
                    : const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                onTap: _isLoggingOut ? null : () {
                  _showLogoutConfirmationDialog();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}