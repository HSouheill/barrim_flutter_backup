import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/service_provider_rewards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../services/sp_referral_service.dart';
import '../../../../services/serviceprovider_controller.dart';
import '../../headers/service_provider_header.dart';

class ServiceProviderReferrals extends StatefulWidget {
  const ServiceProviderReferrals({Key? key}) : super(key: key);

  @override
  State<ServiceProviderReferrals> createState() => _ServiceProviderReferralsState();
}

class _ServiceProviderReferralsState extends State<ServiceProviderReferrals> {
  final ReferralService _referralService = ReferralService();
  final ServiceProviderController _serviceProviderController = ServiceProviderController();
  ReferralData? _referralData;
  bool _isLoading = true;
  String? _error;
  Image? _qrCodeImage;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
    _fetchServiceProviderData();
  }

  Future<void> _fetchServiceProviderData() async {
    await _serviceProviderController.initialize();
  }

  Future<void> _loadReferralData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _referralService.getServiceProviderReferralData();

      if (result.isSuccess && result.data != null) {
        // Load QR code image
        final qrImage = await _referralService.getQRCodeImage(result.data!.referralCode);

        setState(() {
          _referralData = result.data;
          _qrCodeImage = qrImage;
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = result.errorMessage ?? 'Failed to load referral data';
          _isLoading = false;
        });
        debugPrint('Error loading referral data: ${result.errorMessage}');
      }
    } catch (e) {
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
      });
      debugPrint('Exception in _loadReferralData: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _serviceProviderController,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Consumer<ServiceProviderController>(
              builder: (context, controller, child) {
                return ServiceProviderHeader(
                  serviceProvider: controller.serviceProvider,
                  isLoading: controller.isLoading,
                );
              },
            ),

            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorWidget()
                  : _buildReferralContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _isRetrying
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: () {
                setState(() {
                  _isRetrying = true;
                });
                _loadReferralData().then((_) {
                  if (mounted) {
                    setState(() {
                      _isRetrying = false;
                    });
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: const Size(200, 40),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralContent() {
    return RefreshIndicator(
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
                    label: 'Referred Service Providers',
                    value: '${_referralData?.referredCount ?? 0}',
                  ),
                  _StatItem(
                    label: 'USD Awarded',
                    value: '\$${_referralData?.points ?? 0}',
                  ),
                ],
              ),
            ),

            // Referral list
            if (_referralData?.referredUsers != null)
              ..._buildReferralItems(),

            // Check Rewards button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to the Rewards page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ServiceProviderRewards()),
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
                      Expanded(
                        child: Text(
                          _referralData?.referralCode ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          if (_referralData?.referralCode != null) {
                            Clipboard.setData(
                              ClipboardData(text: _referralData!.referralCode),
                            );
                            _showCopiedSnackBar('Code copied to clipboard');
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _referralData != null
                              ? _referralService.getReferralLink(_referralData!.referralCode)
                              : 'N/A',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_referralData != null)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            final link = _referralService.getReferralLink(_referralData!.referralCode);
                            Clipboard.setData(ClipboardData(text: link));
                            _showCopiedSnackBar('Link copied to clipboard');
                          },
                        ),
                    ],
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
                      // Share code functionality
                      if (_referralData?.referralCode != null) {
                        _shareReferralCode(_referralData!.referralCode);
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
                      // Share link functionality
                      if (_referralData?.referralCode != null) {
                        _shareReferralLink(_referralData!.referralCode);
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

            // QR Code image
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _qrCodeImage ??
                  Image.asset(
                    'assets/qr_code.png',
                    height: 150,
                    width: 150,
                  ),
            ),

            // Bottom padding
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReferralItems() {
    List<Widget> items = [];

    if (_referralData?.referredUsers != null && _referralData!.referredUsers.isNotEmpty) {
      for (var user in _referralData!.referredUsers) {
        items.add(
          _ReferralItem(
            serviceProviderLogo: user.logoPath ?? 'assets/images/kfc.png',
            serviceProviderName: user.fullName,
            referralMethod: 'Referred using ${_getRandomReferralMethod()}',
            amount: '+\$5',
          ),
        );
      }
    } else {
      items.add(
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No referrals yet. Share your referral code to start earning!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return items;
  }

  String _getRandomReferralMethod() {
    final methods = ['referral link', 'unique code', 'QR code'];
    return methods[DateTime.now().millisecond % methods.length];
  }

  void _shareReferralCode(String code) {
    // This would normally use a share package like share_plus
    // For demo purposes, just copy to clipboard and show a snackbar
    Clipboard.setData(ClipboardData(text: code));
    _showCopiedSnackBar('Referral code copied and ready to share');
  }

  void _shareReferralLink(String code) {
    // This would normally use a share package like share_plus
    // For demo purposes, just copy to clipboard and show a snackbar
    final link = _referralService.getReferralLink(code);
    Clipboard.setData(ClipboardData(text: link));
    _showCopiedSnackBar('Referral link copied and ready to share');
  }

  void _showCopiedSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
  final String serviceProviderLogo;
  final String serviceProviderName;
  final String referralMethod;
  final String amount;

  const _ReferralItem({
    required this.serviceProviderLogo,
    required this.serviceProviderName,
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
            child: _buildImage(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceProviderName,
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

  Widget _buildImage() {
    if (serviceProviderLogo.startsWith('assets/')) {
      return Image.asset(
        serviceProviderLogo,
        width: 90,
        height: 50,
        fit: BoxFit.cover,
      );
    } else {
      return Image.network(
        serviceProviderLogo,
        width: 90,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading image: $error');
          return Image.asset(
            'assets/images/kfc.png',
            width: 90,
            height: 50,
            fit: BoxFit.cover,
          );
        },
      );
    }
  }
}