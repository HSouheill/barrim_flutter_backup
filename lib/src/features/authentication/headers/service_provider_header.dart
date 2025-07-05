import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/service_provider.dart';
import '../../../services/api_service.dart';
import '../../../components/secure_network_image.dart';
import '../screens/serviceProvider_dashboard/sp_settings.dart';
import '../screens/serviceprovider_dashboard/serviceprovider_dashboard.dart';

class ServiceProviderHeader extends StatelessWidget {
  final VoidCallback? onAvatarTap;
  final ServiceProvider? serviceProvider;
  final bool isLoading;
  final VoidCallback? onLogoTap;

  const ServiceProviderHeader({
    Key? key,
    this.onAvatarTap,
    this.serviceProvider,
    this.isLoading = true,
    this.onLogoTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Construct logo URL if available
    String? logoUrl;
    if (serviceProvider?.logoPath != null && serviceProvider!.logoPath!.isNotEmpty) {
      // Check if logoPath already contains the full URL
      if (serviceProvider!.logoPath!.startsWith('https')) {
        logoUrl = serviceProvider!.logoPath;
      } else {
        // Construct the full URL
        final baseUrl = ApiService.baseUrl;
        logoUrl = "$baseUrl/${serviceProvider!.logoPath}";
        print("Logo URL: $logoUrl"); // Debug print
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2079C2),
            Color(0xFF1E88E5),
          ],
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Row(
          children: [
            // Logo on the left
            GestureDetector(
              onTap: onLogoTap ?? () {
                if (serviceProvider != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceproviderDashboard(userData: serviceProvider!.toJson()),
                    ),
                  );
                }
              },
              child: SizedBox(
                height: 50, // Header height
                width: 50,  // Keep square for aspect ratio
                child: Image.asset(
                  'assets/logo/barrim_logo1.png',
                  fit: BoxFit.contain, // Ensures the logo scales proportionally
                ),
              ),
            ),
            const Spacer(),
            
            // Make CircleAvatar clickable to navigate to Settings
            GestureDetector(
              onTap: onAvatarTap ?? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SPSettingsPage()),
                );
              },
              child: isLoading || logoUrl == null
                  ? const CircleAvatar(
                      radius: 22,
                      backgroundImage: AssetImage('assets/logo/barrim_logo1.png'),
                    )
                  : CircleAvatar(
                      radius: 22,
                      child: ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: logoUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) {
                            print("Error loading image: $error"); // Debug print
                            print("Failed URL: $url"); // Debug print
                            return const CircleAvatar(
                              radius: 25,
                              backgroundImage: AssetImage('assets/logo/barrim_logo1.png'),
                            );
                          },
                        ),
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
      ),
    );
  }
}