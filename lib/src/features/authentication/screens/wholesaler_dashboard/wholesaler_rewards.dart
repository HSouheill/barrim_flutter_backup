import 'package:flutter/material.dart';
import '../../../../services/wholesaler_service.dart';
import '../../../../services/api_service.dart';
import '../../headers/wholesaler_header.dart';


class WholesalerRewards extends StatefulWidget {
  const WholesalerRewards({Key? key}) : super(key: key);

  @override
  State<WholesalerRewards> createState() => _WholesalerRewardsState();
}

class _WholesalerRewardsState extends State<WholesalerRewards> {
  final WholesalerService _wholesalerService = WholesalerService();
  bool _isLoading = true;
  int _points = 0;
  String _errorMessage = '';
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _loadWholesalerData();
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

  Future<void> _loadWholesalerData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Try to get wholesaler data
      final wholesaler = await _wholesalerService.getWholesalerData();

      if (wholesaler != null) {
        setState(() {
          _points = wholesaler.points;
          _isLoading = false;
        });
      } else {
        // If wholesaler data is null, try to get referral data which also contains points
        final referralData = await _wholesalerService.getWholesalerReferralData();

        if (referralData != null) {
          setState(() {
            _points = referralData.points;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load point balance';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
      print('Error loading wholesaler data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Import the company header from the provided file
          WholesalerHeader(logoUrl: _logoUrl),

          // Main content area
          Expanded(
            child: Container(
              color: Colors.white,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
                  : SingleChildScrollView(
                child: Column(
                  children: [
                    // Balance and Rewards section
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Rewards title with dividers
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
                                child: Text(
                                  'Rewards',
                                  style: TextStyle(
                                    color: Color(0xFF2079C2),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),

                          // Balance section
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Balance',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF2079C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Balance amount - now using actual points
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '\$ $_points',
                              style: TextStyle(
                                fontSize: 32,
                                color: Color(0xFF2079C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Dynamic rewards section - will be populated from backend
                          if (_points > 0) ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  'Available rewards will be displayed here based on your points balance.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ] else ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  'Earn more points to unlock rewards!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }




}