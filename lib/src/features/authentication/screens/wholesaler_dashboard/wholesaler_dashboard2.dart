import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/subscription/wholesaler_subscription.dart';
import 'package:flutter/material.dart';
import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_referral.dart';
import 'package:provider/provider.dart';
import 'package:barrim/src/utils/subscription_provider.dart';

class WholesalerSocialActions extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Function({
  required String phone,
  required String whatsapp,
  required String website,
  required String facebook,
  required String instagram,
  }) updateCompanyData;
  final VoidCallback navigateToBranchesPage;

  const WholesalerSocialActions({
    Key? key,
    required this.userData,
    required this.updateCompanyData,
    required this.navigateToBranchesPage,
  }) : super(key: key);

  Widget _buildActionButton(BuildContext context, String title, IconData icon,
      VoidCallback onTap) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0094FF),
            Color(0xFF05055A),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditCompanyDialog(BuildContext context) {
    // Get current values from the user data
    final currentPhone = userData['phone'] ?? '';
    final currentWhatsApp = userData['whatsapp'] ?? '';
    final currentWebsite = userData['website'] ?? '';
    final currentFacebook = userData['facebook'] ?? '';
    final currentInstagram = userData['instagram'] ?? '';

    // Controllers for text fields
    final phoneController = TextEditingController(text: currentPhone);
    final whatsappController = TextEditingController(text: currentWhatsApp);
    final websiteController = TextEditingController(text: currentWebsite);
    final facebookController = TextEditingController(text: currentFacebook);
    final instagramController = TextEditingController(text: currentInstagram);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit Wholesaler Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+961 1 234 567',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'WhatsApp Number',
                    hintText: '+961 1 234 567',
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Website URL',
                    hintText: 'https://www.example.com',
                    prefixIcon: Icon(Icons.language),
                  ),
                  controller: websiteController,
                  keyboardType: TextInputType.url,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Facebook URL',
                    hintText: 'https://facebook.com/yourpage',
                    prefixIcon: Icon(Icons.facebook),
                  ),
                  controller: facebookController,
                  keyboardType: TextInputType.url,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Instagram URL',
                    hintText: 'https://instagram.com/yourpage',
                    prefixIcon: Icon(Icons.camera_alt),
                  ),
                  controller: instagramController,
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () {
                updateCompanyData(
                  phone: phoneController.text,
                  whatsapp: whatsappController.text,
                  website: websiteController.text,
                  facebook: facebookController.text,
                  instagram: instagramController.text,
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToReferralsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WholesalerReferral(),
      ),
    );
  }
  void _navigateToSubscriptionPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WholesalerSubscription(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divider and title for details section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.blue,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Details',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                    fontSize: 22,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),

        // Contact details section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // WhatsApp
              Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_android, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userData['whatsapp'] != null && userData['whatsapp'].isNotEmpty
                            ? userData['whatsapp']
                            : 'No WhatsApp number',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // Phone
              Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userData['phone'] != null && userData['phone'].isNotEmpty
                            ? userData['phone']
                            : 'No phone number',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // Instagram
              Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, color: Colors.purple),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userData['instagram'] != null && userData['instagram'].isNotEmpty
                            ? userData['instagram']
                            : 'No Instagram account',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // Facebook
              Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.facebook, color: Colors.indigo),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userData['facebook'] != null && userData['facebook'].isNotEmpty
                            ? userData['facebook']
                            : 'No Facebook page',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // Website
              Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, color: Colors.teal),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userData['website'] != null && userData['website'].isNotEmpty
                            ? userData['website']
                            : 'No website',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Edit button
        Center(
          child: ElevatedButton(
            onPressed: () => _showEditCompanyDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Edit'),
          ),
        ),

        SizedBox(height: 20),

        // Action buttons section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // _buildActionButton(
              //   context,
              //   'Reviews Checkup',
              //   Icons.star_rate,
              //       () {
              //     // Navigate to reviews page
              //     // You can implement this later
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       SnackBar(content: Text('Reviews feature coming soon')),
              //     );
              //   },
              // ),
              SizedBox(height: 10),
              _buildActionButton(
                context,
                'My Referrals',
                Icons.people,
                    () => _navigateToReferralsPage(context),
              ),
              SizedBox(height: 10),
              _buildActionButton(
                context,
                'Subscriptions',
                Icons.payment,
                    () => _navigateToSubscriptionPage(context),
              ),
            ],
          ),
        ),

        SizedBox(height: 30),
      ],
    );
  }
}