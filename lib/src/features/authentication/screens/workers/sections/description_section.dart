import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../services/api_service.dart';

class DescriptionSection extends StatelessWidget {
  final Map<String, dynamic> providerData;

  const DescriptionSection({
    Key? key,
    required this.providerData,
  }) : super(key: key);

  String _getFullImageUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    // Remove leading slash if present and construct full URL
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final baseUrl = ApiService.baseUrl;
    return baseUrl.endsWith('/') ? baseUrl + cleanPath : baseUrl + '/' + cleanPath;
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (!await launchUrl(phoneUri)) {
      throw Exception('Could not launch $phoneUri');
    }
  }

  Future<void> _sendWhatsAppMessage(String phoneNumber) async {
    // Remove any non-numeric characters from the phone number
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');
    if (!await launchUrl(whatsappUri)) {
      throw Exception('Could not launch $whatsappUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get social links from provider data
    final socialLinks = providerData['socialLinks'] ?? {};
    final phoneNumber = providerData['phoneNumber']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description Header with dividers
        Row(
          children: [
            Expanded(child: Divider(color: Colors.blue[200])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
              child: Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.blue[200])),
          ],
        ),
        const SizedBox(height: 2),

        // Profile details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Social Media Icons Row (moved to top, right-aligned)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () => _makePhoneCall(phoneNumber),
                    child: _buildSocialIcon(Icons.phone, Colors.white, Colors.green),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _sendWhatsAppMessage(phoneNumber),
                    child: _buildSocialIcon(Icons.message, Colors.white, Colors.green[700]!),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final instagramUrl = socialLinks['instagram']?.toString();
                      if (instagramUrl != null && instagramUrl.isNotEmpty) {
                        _launchUrl(instagramUrl);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Instagram link not available')),
                        );
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.pink,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/icons/instagram.png',
                          width: 18,
                          height: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final facebookUrl = socialLinks['facebook']?.toString();
                      if (facebookUrl != null && facebookUrl.isNotEmpty) {
                        _launchUrl(facebookUrl);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Facebook link not available')),
                        );
                      }
                    },
                    child: _buildSocialIcon(Icons.facebook, Colors.white, Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Full Name Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Full Name: ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    providerData['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Location Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location: ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (providerData['location'] ?? 'Location not specified') ?? 'Location not specified',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Skills Row
              

              // Service Type Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Type: ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (providerData['serviceType'] ?? 'Service Provider') ?? 'Service Provider',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Emergency Status Row
              // Row(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   children: [
              //     const Text(
              //       'Emergency Status: ',
              //       style: TextStyle(
              //         fontSize: 15,
              //         color: Colors.black87,
              //       ),
              //     ),
              //     Expanded(
              //       child: Text(
              //         (providerData['emergencyStatus'] ?? 'Not Available') ?? 'Not Available',
              //         style: TextStyle(
              //           fontSize: 15,
              //           color: providerData['emergencyStatus'] == 'Available' ? Colors.green : Colors.red,
              //           fontWeight: FontWeight.w500,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
              // const SizedBox(height: 12),

              // Description Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description: ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (providerData['description'] ?? 'No description available') ?? 'No description available',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Portfolio Images
              if (providerData['portfolioImages'] != null && 
                  (providerData['portfolioImages'] as List).isNotEmpty) ...[
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.blue)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Portfolio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPortfolioGrid(context, providerData['portfolioImages']),
              ],

            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioGrid(BuildContext context, List<dynamic> portfolioImagePaths) {
    // Convert paths to full URLs
    final portfolioImageUrls = portfolioImagePaths
        .map((path) => _getFullImageUrl(path.toString()))
        .toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: portfolioImageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showImageDialog(context, portfolioImageUrls[index]),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: portfolioImageUrls[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialIcon(IconData icon, Color iconColor, Color backgroundColor) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          color: iconColor,
          size: 18,
        ),
      ),
    );
  }

  String? _formatList(dynamic list) {
    if (list == null) return null;
    if (list is List) {
      // Convert each element to string, filter out null/empty values, and ensure non-null strings
      final List<String> stringList = list
          .map((item) => item?.toString())
          .whereType<String>()  // This ensures we only keep non-null strings
          .where((item) => item.isNotEmpty)
          .toList();
      return stringList.isEmpty ? null : stringList.join(', ');
    }
    return null;
  }
} 