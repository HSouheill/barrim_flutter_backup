import 'package:flutter/material.dart';
import '../../../../services/sp_referral_service.dart';
import '../../headers/service_provider_header.dart';
import '../../../../services/serviceprovider_controller.dart';
import 'package:provider/provider.dart';

class ServiceProviderRewards extends StatefulWidget {
  const ServiceProviderRewards({Key? key}) : super(key: key);

  @override
  State<ServiceProviderRewards> createState() => _ServiceProviderRewardsState();
}

class _ServiceProviderRewardsState extends State<ServiceProviderRewards> {
  final ReferralService _referralService = ReferralService();
  final ServiceProviderController _serviceProviderController = ServiceProviderController();
  int _points = 0;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchServiceProviderData();
    _loadReferralData();
  }

  Future<void> _fetchServiceProviderData() async {
    await _serviceProviderController.initialize();
  }

  Future<void> _loadReferralData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _referralService.getServiceProviderReferralData();

      if (result.isSuccess && result.data != null) {
        setState(() {
          _points = result.data?.points ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Failed to load points';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading points: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _serviceProviderController,
      child: Scaffold(
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage))
                  : Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Column(
                          children: [
                            // Rewards title with dividers
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

                            // Points display
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '\$$_points',
                                style: TextStyle(
                                  fontSize: 32,
                                  color: Color(0xFF2079C2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Reward cards
                            _buildRewardCard(
                              discountPercentage: '20%',
                              pointsRequired: '30',
                              description: 'Get 20% discount code to use for any activity!',
                              color: Color(0xFFEF5350),
                              currentPoints: _points,
                            ),

                            const SizedBox(height: 12),

                            _buildRewardCard(
                              discountPercentage: '30%',
                              pointsRequired: '50',
                              description: 'Get 30% discount code to use for any activity!',
                              color: Color(0xFFEF5350),
                              currentPoints: _points,
                            ),

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
      ),
    );
  }

  // Reward card widget
  Widget _buildRewardCard({
    required String discountPercentage,
    required String pointsRequired,
    required String description,
    required Color color,
    required int currentPoints,
  }) {
    final canRedeem = currentPoints >= int.parse(pointsRequired);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    discountPercentage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Discount Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              pointsRequired,
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF2079C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              ' \$',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF2079C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ElevatedButton(
                          onPressed: canRedeem ? () {
                            _redeemReward(int.parse(pointsRequired));
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canRedeem
                                ? Color(0xFF2079C2)
                                : Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            minimumSize: const Size(0, 25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Get',
                            style: TextStyle(
                              color: canRedeem ? Colors.white : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _redeemReward(int pointsRequired) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Redeem Reward?'),
        content: Text('This will deduct $pointsRequired points from your balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reward redeemed successfully!')),
      );
      // Refresh points after redemption
      _loadReferralData();
    }
  }
}