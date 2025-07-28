import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_dashboard.dart';
import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_notification_settings.dart';
import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_personal_information.dart';
import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_profile_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barrim/src/services/wholesaler_service.dart';
import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/services/user_provider.dart';
import 'package:barrim/src/utils/token_manager.dart';
import 'package:barrim/src/features/authentication/screens/login_page.dart';



class WholesalerSettings extends StatefulWidget {
  final VoidCallback? onLogoTap;
  const WholesalerSettings({Key? key, this.onLogoTap}) : super(key: key);

  @override
  State<WholesalerSettings> createState() => _WholesalerSettingsState();
}

class _WholesalerSettingsState extends State<WholesalerSettings> {
  String? _logoUrl;
  final WholesalerService _wholesalerService = WholesalerService();
  final TokenManager _tokenManager = TokenManager();

  @override
  void initState() {
    super.initState();
    _loadWholesalerLogo();
  }

  Future<void> _loadWholesalerLogo() async {
    try {
      final wholesalerData = await _wholesalerService.getWholesalerData();
      if (wholesalerData != null && mounted) {
        // Convert logo URL to full URL if it's a relative path
        String? logoUrl = wholesalerData.logoUrl;
        if (logoUrl != null && logoUrl.isNotEmpty) {
          // If it's a relative path, convert to full URL
          if (logoUrl.startsWith('/') || logoUrl.startsWith('uploads/')) {
            logoUrl = '${ApiService.baseUrl}/$logoUrl';
          }
          // If it starts with file://, remove it and convert to full URL
          else if (logoUrl.startsWith('file://')) {
            logoUrl = logoUrl.replaceFirst('file://', '');
            if (logoUrl.startsWith('/')) {
              logoUrl = '${ApiService.baseUrl}$logoUrl';
            } else {
              logoUrl = '${ApiService.baseUrl}/$logoUrl';
            }
          }
        }
        setState(() {
          _logoUrl = logoUrl;
        });
      }
          } catch (e) {
        print('Error loading wholesaler logo: $e');
      }
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

      // Clear token using TokenManager
      await _tokenManager.clearToken();

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
                          onTap: widget.onLogoTap ?? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WholesalerDashboard(userData: {}),
                              ),
                            );
                          },
                          child: Image.asset('assets/logo/barrim_logo.png', height: 60),
                        ),

                        // Right side icons
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 22,
                              child: _logoUrl != null && _logoUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        _logoUrl!,
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Image.asset(
                                            'assets/logo/barrim_logo1.png',
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/logo/barrim_logo1.png',
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // User info section
                    FutureBuilder(
                      future: WholesalerService().getWholesalerData(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        } else if (snapshot.hasError) {
                          return const Text(
                            'Failed to load wholesaler info',
                            style: TextStyle(color: Colors.white),
                          );
                        } else if (snapshot.hasData && snapshot.data != null) {
                          final wholesaler = snapshot.data;
                          // Debug: Print wholesaler data to see what's available
                          print('Wholesaler data: name=${wholesaler!.name}, businessName=${wholesaler!.businessName}, email=${wholesaler!.email}');
                          return GestureDetector(
                            onTap: () {
                              // Navigate to company profile settings
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const WholesalerProfileSettings()),
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 28,
                                  child: _logoUrl != null && _logoUrl!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            _logoUrl!,
                                            width: 58,
                                            height: 58,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Image.asset(
                                                'assets/logo/barrim_logo1.png',
                                                width: 58,
                                                height: 58,
                                                fit: BoxFit.cover,
                                              );
                                            },
                                          ),
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
                                        wholesaler!.businessName.isNotEmpty 
                                            ? wholesaler!.businessName 
                                            : 'Wholesaler',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        wholesaler!.additionalEmails.isNotEmpty 
                                            ? wholesaler!.additionalEmails.first 
                                            : 'No email available',
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
                                  size: 30,
                                ),
                              ],
                            ),
                          );
                        } else {
                          return const SizedBox();
                        }
                      },
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
                    MaterialPageRoute(builder: (context) => const WholesalerPersonalInformation()),
                  );
                },
              ),
            ),
          ),

          // Notifications button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
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
                    MaterialPageRoute(builder: (context) => const WholesalerNotificationSettingsPage()),
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