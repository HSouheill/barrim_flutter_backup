import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HowToUseAppPage extends StatelessWidget {
  const HowToUseAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05054F),
      appBar: AppBar(
        title: Text(
          'How to Use Barrim',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1F4889),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2079C2),
                    Color(0xFF1F4889),
                    Color(0xFF05054F),
                  ],
                ),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/logo/barrim_logo.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome to Barrim',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Your All-in-One Guide to Lebanon\'s Services & Businesses',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // What is Barrim Section
            _buildSection(
              icon: Icons.info_outline,
              title: 'What is Barrim?',
              content: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBulletPoint(
                      'A powerful mobile app combining the best features of TripAdvisor, Google Maps, and Thumbtack',
                    ),
                    const SizedBox(height: 10),
                    _buildBulletPoint(
                      'Tailored specifically for the Lebanese market',
                    ),
                    const SizedBox(height: 10),
                    _buildBulletPoint(
                      'Explore restaurants, shops, and service providers with rich multimedia profiles',
                    ),
                    const SizedBox(height: 10),
                    _buildBulletPoint(
                      'Earn referral points, commissions, and redeem rewards',
                    ),
                  ],
                ),
              ),
            ),

            // Key Features Section
            _buildFeaturesSection(),

            // User Segments Section
            _buildUserSegmentsSection(),

            // Revenue Model Section
            _buildRevenueSection(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0094FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF0094FF),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String iconPath,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF0094FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              iconPath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return _buildSection(
      icon: Icons.star_outline,
      title: 'Key Features',
      content: Column(
        children: [
          _buildFeatureCard(
            iconPath: 'assets/barrim_icons/navigation.png',
            title: 'Map Navigation',
            description: 'Visually explore nearby businesses and services with real-time geo-location',
          ),
          _buildFeatureCard(
            iconPath: 'assets/barrim_icons/company.png',
            title: 'Company Pages',
            description: 'Rich profiles with photos, videos, location, price per person (PPP), social media links, and click-to-call',
          ),
          _buildFeatureCard(
            iconPath: 'assets/barrim_icons/services.png',
            title: 'Service Provider Tools',
            description: 'Schedule bookings, show availability, and receive issue descriptions via image upload',
          ),
          _buildFeatureCard(
            iconPath: 'assets/barrim_icons/referral.png',
            title: 'Referral System',
            description: 'Earn points by inviting friends; redeem for gifts and vouchers',
          ),
          _buildFeatureCard(
            iconPath: 'assets/barrim_icons/comission.png',
            title: 'Commission System',
            description: 'Receive financial incentives for successful referrals and registrations',
          ),
        ],
      ),
    );
  }

  Widget _buildUserSegmentCard({
    required String iconPath,
    required String title,
    required String description,
    required Color gradientStart,
    required Color gradientEnd,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientStart.withOpacity(0.2),
            gradientEnd.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: gradientStart.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientStart, gradientEnd],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              iconPath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSegmentsSection() {
    return _buildSection(
      icon: Icons.people_outline,
      title: 'User Segments',
      content: Column(
        children: [
          _buildUserSegmentCard(
            iconPath: 'assets/barrim_icons/referral.png',
            title: 'Regular Users',
            description: 'Discover and review businesses, send referrals, and earn points redeemable for rewards',
            gradientStart: const Color(0xFF0094FF),
            gradientEnd: const Color(0xFF05055A),
          ),
          _buildUserSegmentCard(
            iconPath: 'assets/barrim_icons/company.png',
            title: 'Companies',
            description: 'Showcase offerings, media, and contact details. Earn commission by referring others to the platform',
            gradientStart: const Color(0xFF00C9FF),
            gradientEnd: const Color(0xFF2079C2),
          ),
          _buildUserSegmentCard(
            iconPath: 'assets/barrim_icons/services.png',
            title: 'Service Providers',
            description: 'Display schedules, take bookings, chat with clients, and receive issue photos in advance',
            gradientStart: const Color(0xFF0094FF),
            gradientEnd: const Color(0xFF1F4889),
          ),
          _buildUserSegmentCard(
            iconPath: 'assets/barrim_icons/pipeline.png',
            title: 'Sales Agents',
            description: 'Use the sales dashboard to onboard new businesses and receive commissions on subscription plans',
            gradientStart: const Color(0xFF05055A),
            gradientEnd: const Color(0xFF0094FF),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard({
    String? iconPath,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0094FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (iconPath != null)
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0094FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
              ),
            ),
          if (iconPath != null) const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSection() {
    return _buildSection(
      icon: Icons.trending_up_outlined,
      title: 'How We Support Businesses',
      content: Column(
        children: [
          _buildRevenueCard(
            iconPath: 'assets/barrim_icons/subscription.png',
            title: 'Subscription Plans',
            description: 'Monthly/annual premium placement and features for businesses',
          ),
          _buildRevenueCard(
            iconPath: 'assets/barrim_icons/comission.png',
            title: 'Referral Commissions',
            description: 'Earn commission for each successful business onboarding',
          ),
          _buildRevenueCard(
            iconPath: 'assets/barrim_icons/referral.png',
            title: 'Gift Shop & Vouchers',
            description: 'Partnership opportunities with brands for additional revenue',
          ),
        ],
      ),
    );
  }
}

