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

          // Make CircleAvatar clickable to navigate to Settings
          GestureDetector(
            onTap: onAvatarTap ?? () {
              // Navigate directly to SettingsPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            child: ClipOval(
              child: (logoUrl != null && logoUrl!.isNotEmpty)
                  ? Image.network(
                      fullLogoUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('CompanyAppHeader: Image network error: $error');
                        return Image.asset(
                          'assets/logo/barrim_logo1.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        print('CompanyAppHeader: Loading image: $loadingProgress');
                        if (loadingProgress == null) {
                          print('CompanyAppHeader: Image loaded successfully');
                          return child;
                        }
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    )
                  : Image.asset(
                      'assets/logo/barrim_logo1.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
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