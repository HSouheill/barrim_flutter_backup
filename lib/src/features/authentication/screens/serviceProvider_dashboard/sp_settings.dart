import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/personal_information_settings.dart';
import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/sp_notification.dart';
import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/sp_profile_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barrim/src/models/service_provider.dart';
import 'package:barrim/src/services/service_provider_services.dart';
import 'package:barrim/src/services/user_provider.dart';
import 'package:barrim/src/utils/token_manager.dart';
import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/serviceprovider_dashboard.dart';
import 'package:barrim/src/features/authentication/screens/login_page.dart';
import 'package:barrim/src/utils/authService.dart';

class SPSettingsPage extends StatefulWidget {
  const SPSettingsPage({Key? key}) : super(key: key);

  @override
  State<SPSettingsPage> createState() => _SPSettingsPageState();
}

class _SPSettingsPageState extends State<SPSettingsPage> {
  final ServiceProviderService _serviceProviderService = ServiceProviderService();
  final TokenManager _tokenManager = TokenManager();
  ServiceProvider? _serviceProvider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServiceProviderData();
  }

  Future<void> _loadServiceProviderData() async {
    try {
      final serviceProvider = await _serviceProviderService.getServiceProviderData();
      setState(() {
        _serviceProvider = serviceProvider;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error appropriately
    }
  }

  String? _getLogoUrl() {
    if (_serviceProvider?.logoPath == null || _serviceProvider!.logoPath!.isEmpty) {
      return null;
    }
    
    if (_serviceProvider!.logoPath!.startsWith('http')) {
      return _serviceProvider!.logoPath;
    }
    
    return "${_serviceProviderService.baseUrl}/${_serviceProvider!.logoPath}";
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogout();
              },
              child: const Text(
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
      // Get UserProvider and clear user data
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.clearUserData(context);

      // Call the logout endpoint and clear token
      await AuthService().logout();

      // Navigate to login page and clear navigation stack
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
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during logout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Top bar with logo and notification icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () {
                            if (_serviceProvider != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ServiceproviderDashboard(
                                    userData: _serviceProvider!.toJson(),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Image.asset('assets/logo/barrim_logo.png', height: 60),
                        ),

                        // Right side icons
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 24,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : _getLogoUrl() != null
                                      ? ClipOval(
                                          child: Image.network(
                                            _getLogoUrl()!,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person,
                                                color: Color(0xFF2079C2),
                                                size: 18,
                                              );
                                            },
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: Color(0xFF2079C2),
                                          size: 18,
                                        ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 32,
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
                          MaterialPageRoute(builder: (context) => const SPProfileSettings()),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 28,
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : _getLogoUrl() != null
                                    ? ClipOval(
                                        child: Image.network(
                                          _getLogoUrl()!,
                                          width: 58,
                                          height: 58,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.person,
                                              color: Color(0xFF2079C2),
                                              size: 24,
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Color(0xFF2079C2),
                                        size: 28,
                                      ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _serviceProvider?.fullName ?? 'Loading...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _serviceProvider?.email ?? '',
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
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
                ),
                title: const Text(
                  'Personal Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ServiceProviderInfoPage ()),
                  );
                },
              ),
            ),
          ),

          // Notifications button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                ),
                title: const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SPNotificationSettingsPage()),
                  );
                },
              ),
            ),
          ),

          // Logout button with red door icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
                leading: const Icon(
                  Icons.exit_to_app, // Exit door icon
                  color: Colors.white,
                  size: 22,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
                onTap: () {
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