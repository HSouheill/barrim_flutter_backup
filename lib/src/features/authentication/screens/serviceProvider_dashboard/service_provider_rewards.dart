import 'package:flutter/material.dart';
import '../../../../services/sp_referral_service.dart';
import '../../../../services/sp_voucher_service.dart';
import '../../../../models/voucher_models.dart';
import '../../headers/service_provider_header.dart';
import '../../../../services/serviceprovider_controller.dart';
import 'package:provider/provider.dart';
import 'purchased_vouchers_screen.dart';

class ServiceProviderRewards extends StatefulWidget {
  const ServiceProviderRewards({Key? key}) : super(key: key);

  @override
  State<ServiceProviderRewards> createState() => _ServiceProviderRewardsState();
}

class _ServiceProviderRewardsState extends State<ServiceProviderRewards> {
  final ReferralService _referralService = ReferralService();
  final ServiceProviderVoucherService _voucherService = ServiceProviderVoucherService();
  final ServiceProviderController _serviceProviderController = ServiceProviderController();
  int _points = 0;
  bool _isLoading = true;
  String _errorMessage = '';
  List<ServiceProviderVoucher> _availableVouchers = [];
  bool _isLoadingVouchers = true;

  @override
  void initState() {
    super.initState();
    _fetchServiceProviderData();
    _loadReferralData();
    _loadAvailableVouchers();
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

  Future<void> _loadAvailableVouchers() async {
    setState(() {
      _isLoadingVouchers = true;
    });

    try {
      final result = await _voucherService.getAvailableVouchers();

      if (result.isSuccess && result.data != null) {
        setState(() {
          _availableVouchers = result.data!;
          _isLoadingVouchers = false;
        });
      } else {
        setState(() {
          _isLoadingVouchers = false;
        });
        // Don't show error for vouchers, just log it
        print('Failed to load vouchers: ${result.errorMessage}');
      }
    } catch (e) {
      setState(() {
        _isLoadingVouchers = false;
      });
      print('Error loading vouchers: $e');
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
                  onLogoNavigation: () {
                    // Navigate back to the previous screen
                    Navigator.of(context).pop();
                  },
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

                            // My Vouchers Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PurchasedVouchersScreen(),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.receipt_long, color: Colors.white),
                                label: Text(
                                  'My Vouchers',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF4CAF50),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Available Vouchers Section
                            if (_availableVouchers.isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Available Vouchers',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF2079C2),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Voucher cards
                              ...(_availableVouchers.map((voucher) => 
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildVoucherCard(voucher),
                                ),
                              ).toList()),
                            ] else if (_isLoadingVouchers) ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ] else ...[
                              // No vouchers available
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'No vouchers available at the moment',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
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
      ),
    );
  }

  // Voucher card widget
  Widget _buildVoucherCard(ServiceProviderVoucher serviceProviderVoucher) {
    final voucher = serviceProviderVoucher.voucher;
    final canPurchase = serviceProviderVoucher.canPurchase;
    final discountText = voucher.discountType == 'percentage' 
        ? '${voucher.discountValue.toInt()}%'
        : '\$${voucher.discountValue.toInt()}';

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
                color: Color(0xFFEF5350),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    discountText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Discount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            voucher.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            voucher.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${voucher.points}',
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
                          onPressed: canPurchase ? () {
                            _purchaseVoucher(voucher.id, voucher.points);
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canPurchase
                                ? Color(0xFF2079C2)
                                : Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            minimumSize: const Size(0, 25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Purchase',
                            style: TextStyle(
                              color: canPurchase ? Colors.white : Colors.black54,
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

  Future<void> _purchaseVoucher(String voucherId, int pointsRequired) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase Voucher?'),
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
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final result = await _voucherService.purchaseVoucher(voucherId);

        // Close loading dialog
        Navigator.of(context).pop();

        if (result.isSuccess) {
          // After purchase, mark voucher as used automatically
          try {
            final purchased = await _voucherService.getPurchasedVouchers();
            if (purchased.isSuccess && purchased.data != null) {
              final purchases = purchased.data!;
              final match = purchases.firstWhere(
                (p) => p.voucherId == voucherId && !p.isUsed,
                orElse: () => purchases.first,
              );
              if (match.id.isNotEmpty) {
                final useRes = await _voucherService.useVoucher(match.id);
                if (useRes.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Voucher purchased and marked as used.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(useRes.errorMessage ?? 'Purchased, but failed to mark as used'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Purchased, but could not locate the purchase to mark used'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Purchased, but failed to retrieve purchases'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Purchased, but error marking used: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }

          // Refresh data after purchase/use
          _loadReferralData();
          _loadAvailableVouchers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to purchase voucher'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}