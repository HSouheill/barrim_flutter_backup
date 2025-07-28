// Update in wholesaler_referral.dart

import 'dart:convert';

import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_rewards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/wholesaler_model.dart';
import '../../../../services/wholesaler_service.dart';
import '../../../../services/api_service.dart';
import '../../headers/wholesaler_header.dart';
import '../referrals/rewards.dart';

class WholesalerReferral extends StatefulWidget {
  const WholesalerReferral({Key? key}) : super(key: key);

  @override
  State<WholesalerReferral> createState() => _WholesalerReferralState();
}

class _WholesalerReferralState extends State<WholesalerReferral> {
  final WholesalerService _wholesalerService = WholesalerService();
  bool _isLoading = true;
  WholesalerReferralData? _referralData;
  List<Wholesaler> _referredWholesalers = [];
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
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

  Future<void> _loadReferralData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Starting to load referral data...');
      // Load referral data
      final referralData = await _wholesalerService.getWholesalerReferralData();
      print('Received referral data: $referralData');

      // Update state once we have all the data
      if (mounted) {
        print('Updating state with referral data');
        setState(() {
          _referralData = referralData;
          _isLoading = false;
        });
        print('State updated. Referral data: $_referralData');
      }
    } catch (e) {
      print('Error loading referral data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Failed to load referral data. Please try again later.'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Using the imported WholesalerHeader
          WholesalerHeader(logoUrl: _logoUrl, userData: {}),

          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _loadReferralData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Referrals title section
                    const _TitleDivider(title: 'Referrals'),

                    // Stats section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatItem(
                            label: 'Referred Companies',
                            value: '${_referralData?.referralCount ?? 0}',
                          ),
                          _StatItem(
                            label: 'Points Earned',
                            value: '${_referralData?.points ?? 0}',
                          ),
                        ],
                      ),
                    ),

                    // Referral list display will go here in a future update
                    // For now we'll just show a placeholder
                    if (_referralData != null && _referralData!.referralCount > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Text(
                          'Referrals history will be displayed here.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                    // Check Rewards button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to the Rewards page
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WholesalerRewards()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          minimumSize: const Size(200, 40),
                        ),
                        child: const Text('Check Rewards'),
                      ),
                    ),

                    // Referral Link section
                    const _TitleDivider(title: 'Referral Link'),

                    // Unique code section
                    if (_referralData != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Unique Code:',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _referralData?.referralCode ?? 'No code available',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () {
                                    if (_referralData?.referralCode != null) {
                                      Clipboard.setData(
                                        ClipboardData(text: _referralData!.referralCode!),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Code copied to clipboard')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Link section
                    if (_referralData != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Link:',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _referralData?.referralLink ?? 'No link available',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Share buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              if (_referralData?.referralCode != null) {
                                // Implement share functionality in a future update
                                // For now, just copy to clipboard
                                Clipboard.setData(
                                  ClipboardData(text: _referralData!.referralCode!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Code copied to clipboard')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              minimumSize: const Size(140, 40),
                            ),
                            child: const Text('Share Code'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (_referralData?.referralLink != null) {
                                // Implement share functionality in a future update
                                // For now, just copy to clipboard
                                Clipboard.setData(
                                  ClipboardData(text: _referralData!.referralLink!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Link copied to clipboard')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              minimumSize: const Size(140, 40),
                            ),
                            child: const Text('Share Link'),
                          ),
                        ],
                      ),
                    ),

                    // QR Code section
                    const _TitleDivider(title: 'QR Code'),

                    // QR Code image - using the QR code from referral data
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: _referralData?.qrCode != null
                          ? Image.memory(
                        _base64ToImage(_referralData!.qrCode!),
                        height: 150,
                        width: 150,
                        errorBuilder: (context, error, stackTrace) {
                          print("Error loading QR code: $error");
                          return const Icon(
                            Icons.qr_code,
                            size: 150,
                            color: Colors.grey,
                          );
                        },
                      )
                          : const Icon(
                        Icons.qr_code,
                        size: 150,
                        color: Colors.grey,
                      ),
                    ),

                    // Bottom padding
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to convert base64 data URI to image bytes
  Uint8List _base64ToImage(String base64String) {
    // Check if the string is a data URI (starts with data:image/)
    if (base64String.startsWith('data:image/')) {
      // Extract the base64 part after the comma
      final commaIndex = base64String.indexOf(',');
      if (commaIndex != -1) {
        base64String = base64String.substring(commaIndex + 1);
      }
    }
    return base64Decode(base64String);
  }
}

// Widget for title with dividers on both sides
class _TitleDivider extends StatelessWidget {
  final String title;

  const _TitleDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              color: Colors.grey,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Expanded(
            child: Divider(
              color: Colors.grey,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget for stat items (companies and amount)
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}