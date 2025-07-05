import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/authService.dart';
import '../../../services/user_provider.dart';
import '../../../services/notification_provider.dart';
import '../screens/booking/myboooking.dart';
import '../screens/login_page.dart';
import '../screens/referrals/user_referral.dart';
import '../screens/settings/settings.dart';
import '../screens/category/categories.dart';
import '../screens/workers/worker_home.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback onCollapse;
  final BuildContext parentContext;
  final AuthService authService = AuthService();

  Sidebar({super.key, required this.onCollapse, required this.parentContext});

  // Method to handle logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Close WebSocket connection first
      try {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.closeConnection();
        print('WebSocket connection closed during logout');
      } catch (e) {
        print('Error closing WebSocket during logout: $e');
      }

      // Clear user data from UserProvider
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.clearUserData(context);
      } catch (e) {
        print('Error clearing user data during logout: $e');
      }

      final Map<String, dynamic> response = await authService.logout();

      if (response['status'] == 200 || response['status'] == 401) {
        // Close sidebar
        onCollapse();

        // Navigate to LoginPage
        Navigator.of(parentContext).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );

        // Show success message
        // ScaffoldMessenger.of(parentContext).showSnackBar(
        //   const SnackBar(
        //     content: Text('Logged out successfully'),
        //     backgroundColor: Colors.green,
        //   ),
        // );
      } else {
        // Show error message but still attempt to navigate to login
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Logout failed: ${response['message']}'),
        //     backgroundColor: Colors.red,
        //   ),
        // );

        // Force logout anyway by navigating to login page
        onCollapse();
        Navigator.of(parentContext).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      // Handle exceptions
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Error during logout: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );

      // Force logout anyway by navigating to login page
      onCollapse();
      Navigator.of(parentContext).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Important: Use the Navigator.of(context) for most navigation
    // and Navigator.of(parentContext) only when needed to prevent overlap issues
    return Container(
      width:199,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2079C2),
            Color(0xFF1F4889),
            Color(0xFF10105D),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(5, 0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align content to left
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.only(top: 30),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset('assets/logo/sidebar_logo.png', width: 50, height: 50),
                      // SizedBox(width: 4),
                      Text(
                        'Barrim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                _buildMenuItem(Icons.home, 'Home'),
                _buildMenuItem(
                  Icons.category,
                  'Categories',
                  onTap: () {
                    onCollapse();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(parentContext).pushReplacement(
                        MaterialPageRoute(builder: (context) => const CategoriesPage()),
                      );
                    });
                  },
                ),

                _buildMenuItem(
                  Icons.people,
                  'Workers',
                  onTap: () {
                    onCollapse();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(parentContext).pushReplacement(
                        MaterialPageRoute(builder: (context) => const DriversGuidesPage()),
                      );
                    });
                  },
                ),

                // _buildMenuItem(
                //   Icons.book_online,
                //   'Bookings',
                //   onTap: () {
                //     onCollapse();
                //     Future.delayed(const Duration(milliseconds: 300), () {
                //       Navigator.of(parentContext).pushReplacement(
                //         MaterialPageRoute(builder: (context) => const MyBookingsPage()),
                //       );
                //     });
                //   },
                // ),

                _buildMenuItem(
                  Icons.share,
                  'Referral',
                  onTap: () {
                    onCollapse();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(parentContext).pushReplacement(
                        MaterialPageRoute(builder: (context) => const ReferralPointsPage()),
                      );
                    });
                  },
                ),

                _buildMenuItem(
                  Icons.settings,
                  'Settings',
                  onTap: () {
                    onCollapse();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(parentContext).pushReplacement(
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    });
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildMenuItem(
                      Icons.logout,
                      'Logout',
                      textColor: Colors.blue,
                      iconColor: Colors.blue,
                      onTap: () => _handleLogout(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap, Color textColor = Colors.white, Color iconColor = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      onTap: onTap,
    );
  }
}