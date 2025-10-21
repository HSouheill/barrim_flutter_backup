import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/company_referral_service.dart';
import '../../../../utils/token_manager.dart';
import '../../headers/company_header.dart';
import 'dart:typed_data';
import '../../../../services/api_service.dart';
import 'company_rewars.dart';

class ReferralsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ReferralsPage({Key? key, required this.userData}) : super(key: key);

  @override
  State<ReferralsPage> createState() => _ReferralsPageState();
}

class _ReferralsPageState extends State<ReferralsPage> {
  final TokenManager _tokenManager = TokenManager();
  Map<String, dynamic> _referralData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  Uint8List? _qrCodeImage;
  String? logoUrl;
  String? _userReferralCode;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
    _loadCompanyData();
    _loadUserProfile();
  }

  Future<void> _loadReferralData() async {
    try {
      final token = await _tokenManager.getToken();
      if (token?.isEmpty == true) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Authentication required';
        });
        return;
      }

      // First ensure we have the user profile data
      if (_userReferralCode == null) {
        await _loadUserProfile();
      }

      final referralService = CompanyReferralService(token: token ?? '');
      final result = await referralService.getCompanyReferralData();

      if (result['success']) {
        print('Referral data received: ${result['data']}');

        // Extract the nested referralData
        final responseData = result['data'] ?? {};
        final referralData = responseData['referralData'] ?? {};

        // Construct the referral link using the user's referral code
        final String referralLink = 'https://barrim.com/referral?code=${_userReferralCode ?? ''}';

        final int referralsCount = referralData['referralCount'] ?? 
                                 referralData['referralsCount'] ?? 
                                 referralData['totalReferrals'] ?? 
                                 referralData['count'] ?? 
                                 responseData['referralCount'] ??
                                 responseData['referralsCount'] ??
                                 responseData['totalReferrals'] ??
                                 responseData['count'] ?? 0;
        
        final int totalRewards = referralData['points'] ?? 
                                referralData['totalPoints'] ?? 
                                referralData['rewardPoints'] ?? 
                                referralData['earnedPoints'] ??
                                responseData['points'] ??
                                responseData['totalPoints'] ??
                                responseData['rewardPoints'] ??
                                responseData['earnedPoints'] ?? 0;
        // Transform the data to match expected format, using userReferralCode as fallback
        final Map<String, dynamic> transformedData = {
          'referralCode': _userReferralCode ?? referralData['referralCode'] ?? '',
          'referralsCount': referralData['referralCount'] ?? 0,
          'totalRewards': referralData['points'] ?? 0,
          'referralLink': referralLink,  // Use our constructed referral link
          'qrCode': responseData['qrCode'],
          'referrals': [], // Initialize empty referrals list
        };

        setState(() {
          _referralData = transformedData;
          _isLoading = false;
        });

        // Generate QR code if we have a referral link
        if (_referralData.containsKey('qrCode')) {
          try {
            final qrCodeString = _referralData['qrCode'];
            if (qrCodeString != null && qrCodeString.startsWith('data:image/png;base64,')) {
              final base64Data = qrCodeString.replaceFirst('data:image/png;base64,', '');
              final bytes = base64.decode(base64Data);
              setState(() {
                _qrCodeImage = bytes;
              });
            }
          } catch (e) {
            print('Error processing QR code: $e');
          }
        }
      } else {
        // If API call fails, still show the referral code from user profile
        final String referralLink = 'https://barrim.com/referral?code=${_userReferralCode ?? ''}';
        setState(() {
          _referralData = {
            'referralCode': _userReferralCode ?? '',
            'referralsCount': 0,
            'totalRewards': 0,
            'referralLink': referralLink,
            'qrCode': null,
            'referrals': [],
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      // If there's an error, still show the referral code from user profile
      final String referralLink = 'https://barrim.com/referral?code=${_userReferralCode ?? ''}';
      setState(() {
        _referralData = {
          'referralCode': _userReferralCode ?? '',
          'referralsCount': 0,
          'totalRewards': 0,
          'referralLink': referralLink,
          'qrCode': null,
          'referrals': [],
        };
        _isLoading = false;
        _errorMessage = 'Failed to load referral data: $e';
      });
    }
  }

  Future<void> _shareReferral({required String code, required String link}) async {
    try {
      final token = await _tokenManager.getToken();
      final referralService = CompanyReferralService(token: token ?? '');
      await referralService.shareReferral(code: code, link: link);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Referral information copied to clipboard')),
      // );
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error sharing referral: $e')),
      // );
    }
  }

  Future<void> _loadCompanyData() async {
    try {
      final token = await _tokenManager.getToken();
      if (token?.isNotEmpty == true) {
        var data = await ApiService.getCompanyData(token!);
        if (data['companyInfo'] != null) {
          setState(() {
            logoUrl = data['companyInfo']['logo'];
          });
        }
      }
    } catch (error) {
      print('Error loading company data: $error');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final token = await _tokenManager.getToken();
      if (token?.isEmpty == true) {
        return;
      }
      
      var data = await ApiService.getUserProfile(token!);
      if (data['referralCode'] != null) {
        setState(() {
          _userReferralCode = data['referralCode'];
          // Update referral link if we already have referral data
          if (_referralData.isNotEmpty) {
            _referralData['referralLink'] = 'https://barrim.com/referral?code=${_userReferralCode}';
          }
        });
      }
    } catch (error) {
      print('Error loading user profile: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the referral code, using userReferralCode as fallback
    final String displayReferralCode = _referralData['referralCode'] ?? _userReferralCode ?? 'No code available';

    return Scaffold(
      body: Column(
        children: [
          // Using the imported CompanyAppHeader
        CompanyAppHeader(
          logoUrl: logoUrl,
          userData: widget.userData,
        ),
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
                : SingleChildScrollView(
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
                          value: '${_referralData['referralsCount'] ?? 0}',
                        ),
                        _StatItem(
                          label: 'Points Earned',
                          value: '${_referralData['totalRewards'] ?? 0}',
                        ),
                      ],
                    ),
                  ),

                  // Referral list
                  ..._buildReferralsList(),

                  // Check Rewards button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to the Rewards page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CompanyRewardsPage(userData: widget.userData),
                          ),
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
                              displayReferralCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                final code = displayReferralCode;
                                if (code.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: code));
                                  // ScaffoldMessenger.of(context).showSnackBar(
                                  //   const SnackBar(content: Text('Code copied to clipboard')),
                                  // );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Link section
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
                          _referralData['referralLink'] ?? 'No link available',
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
                          onPressed: displayReferralCode != 'No code available'
                              ? () => _shareReferral(
                            code: displayReferralCode,
                            link: _referralData['referralLink'] ?? '',
                          )
                              : null,
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
                          onPressed: _referralData['referralLink'] != null
                              ? () => _shareReferral(
                            code: displayReferralCode,
                            link: _referralData['referralLink'],
                          )
                              : null,
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

                  // QR Code image
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: _qrCodeImage != null
                        ? Image.memory(
                      _qrCodeImage!,
                      height: 150,
                      width: 150,
                    )
                        : Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text('QR Code Loading...'),
                      ),
                    ),
                  ),

                  // Bottom padding
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReferralsList() {
    print('Building referrals list with data: $_referralData');

    // Safely extract referrals list
    final referrals = _referralData['referrals'];
    List<dynamic> referralsList = [];

    if (referrals is List) {
      referralsList = referrals;
    } else if (referrals is Map) {
      // Sometimes APIs return objects instead of arrays
      referralsList = referrals.values.toList();
    }

    print('Referrals list length: ${referralsList.length}');

    if (referralsList.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'No referrals yet',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ];
    }

    return referralsList.map<Widget>((referral) {
      // Print each referral to debug
      print('Processing referral: $referral');

      // Handle both string IDs and actual referral objects
      if (referral is String) {
        // This is just an ID, we'd need to fetch the actual referral data
        // For now, show a placeholder
        return _ReferralItem(
          companyLogo: 'assets/images/default_logo.png',
          companyName: 'Company ID: ${referral.substring(0, min(referral.length, 8))}...',
          referralMethod: 'Referred company',
          amount: '+0 pts', // Cannot determine amount from just ID
        );
      }

      // Normal object handling
      return _ReferralItem(
        companyLogo: referral['logoUrl'] ?? 'assets/images/default_logo.png',
        companyName: referral['companyName'] ?? 'Unknown',
        referralMethod: referral['method'] ?? 'Referred company',
        amount: '+${referral['rewardAmount'] ?? 0} pts',
      );
    }).toList();
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

// Widget for referral items
class _ReferralItem extends StatelessWidget {
  final String companyLogo;
  final String companyName;
  final String referralMethod;
  final String amount;

  const _ReferralItem({
    required this.companyLogo,
    required this.companyName,
    required this.referralMethod,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: companyLogo.startsWith('http')
                ? Image.network(
              companyLogo,
              width: 90,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/default_logo.png',
                width: 90,
                height: 50,
                fit: BoxFit.cover,
              ),
            )
                : Image.asset(
              companyLogo,
              width: 90,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  referralMethod,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}