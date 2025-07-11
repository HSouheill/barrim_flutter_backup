import 'package:flutter/material.dart';
import '../screens/company_dashboard/company_settings.dart';
import '../screens/company_dashboard/company_dashboard.dart';
import '../screens/company_dashboard/company_notification_settings.dart';
import '../../../services/api_service.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class CompanyAppHeader extends StatelessWidget {
  final VoidCallback? onAvatarTap;
  final String? logoUrl;
  final Map<String, dynamic> userData;
  final VoidCallback? onLogoTap;

  const CompanyAppHeader({
    Key? key, 
    this.onAvatarTap,
    this.logoUrl,
    required this.userData,
    this.onLogoTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('CompanyAppHeader: Building with logoUrl: $logoUrl');
    final fullLogoUrl = logoUrl != null && logoUrl!.isNotEmpty
        ? (logoUrl!.startsWith('http') ? logoUrl! : '${ApiService.baseUrl}/$logoUrl')
        : null;
    print('CompanyAppHeader: Full logo URL: $fullLogoUrl');

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
                  builder: (context) => CompanyDashboard(userData: userData),
                ),
              );
            },
            child: Image.asset('assets/logo/barrim_logo.png', height: 60),
          ),
          Spacer(),

          InkWell(
            onTap: onAvatarTap ?? () {
              // Navigate directly to SettingsPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: (logoUrl != null && logoUrl!.isNotEmpty)
                  ? ClipOval(
                      child: SecureNetworkImage(
                        imageUrl: fullLogoUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) {
                          print('CompanyAppHeader: Image network error: $error');
                          return const Icon(Icons.person, color: Colors.white, size: 22);
                        },
                      ),
                    )
                  : Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ),
          SizedBox(width: 12),
          GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanyNotificationSettingsPage(userData: userData),
              ),
            );
          },
          child: Icon(
            Icons.notifications,
            color: Colors.white,
            size: 32,
          ),
        ),
        ],
      ),
    );
  }
}