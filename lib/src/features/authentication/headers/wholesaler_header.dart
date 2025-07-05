import 'package:flutter/material.dart';

import '../screens/wholesaler_dashboard/wholesaler_settings.dart';
import '../screens/wholesaler_dashboard/wholesaler_dashboard.dart';

class WholesalerHeader extends StatelessWidget {
  final VoidCallback? onLogoTap;
  final VoidCallback? onAvatarTap;
  final String? logoUrl;

  const WholesalerHeader({
    Key? key, 
    this.onLogoTap, 
    this.onAvatarTap,
    this.logoUrl,
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
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 16),
      height: 125,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onLogoTap ?? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WholesalerDashboard(userData: {}),
                ),
              );
            },
            child: Image.asset('assets/logo/barrim_logo.png', height: 60),
          ),
          Spacer(),

          // Make CircleAvatar clickable to navigate to Settings
          GestureDetector(
            onTap: onAvatarTap ?? () {
              // Navigate directly to SettingsPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WholesalerSettings()),
              );
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: logoUrl != null && logoUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        logoUrl!,
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
                      ),
                    )
                  : Image.asset(
                      'assets/logo/barrim_logo1.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          SizedBox(width: 12),
          Icon(
            Icons.notifications,
            color: Colors.white,
            size: 32,
          ),
        ],
      ),
    );
  }
}