import 'package:flutter/material.dart';
import 'package:barrim/src/components/secure_network_image.dart';

import '../screens/user_dashboard/notification.dart';
import '../screens/settings/settings.dart';
import '../screens/user_dashboard/home.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoTap;
  final String? profileImagePath;

  const AppHeader({
    Key? key,
    this.onNotificationTap,
    this.onMenuTap,
    this.onProfileTap,
    this.onLogoTap,
    this.profileImagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF2079C2), // #2079C2
            Color(0xFF1F4889), // #1F4889
            Color(0xFF10105D), // #10105D
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 40,
      ),
      height: 125,
      child: Row(
        children: [
          InkWell(
            onTap: onLogoTap ?? () {
              // Default navigation to homepage if no callback provided
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => UserDashboard(
                    userData: {
                      'token': 'dummy_token', // You might need to pass actual user data
                    },
                  ),
                ),
              );
            },
            child: Image.asset('assets/logo/barrim_logo.png', height: 60),
          ),

          Spacer(),

          InkWell(
            onTap: onProfileTap ?? () {
              // Default navigation to SettingsPage if no callback provided
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(),
                ),
              );
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: (profileImagePath != null && profileImagePath!.isNotEmpty)
                  ? ClipOval(
                      child: SecureNetworkImage(
                        imageUrl: profileImagePath!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) {
                          print('Error loading profile image: $error');
                          print('Failed profile image path: $profileImagePath');
                          return const Icon(Icons.person, color: Colors.white, size: 22);
                        },
                      ),
                    )
                  : Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ),
          SizedBox(width: 18),
          InkWell(
            onTap: onNotificationTap ?? () {
              // Navigate to Notifications page when notification icon is clicked
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsPage(),
                ),
              );
            },
            child: ImageIcon(
              AssetImage('assets/icons/notification_icon.png'),
              size: 26,
              color: Colors.white,  // Adjust icon color
            ),
          ),
          SizedBox(width: 18),
          // Update the onMenuTap callback in the InkWell
          InkWell(
            onTap: onMenuTap,
            child: ImageIcon(
              AssetImage('assets/icons/sidebar_icon.png'),
              size: 26,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}