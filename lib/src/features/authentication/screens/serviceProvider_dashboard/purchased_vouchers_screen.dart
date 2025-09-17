import 'package:flutter/material.dart';
import '../../../../services/sp_voucher_service.dart';
import '../../../../models/voucher_models.dart';
import '../../headers/service_provider_header.dart';
import '../../../../services/serviceprovider_controller.dart';
import 'package:provider/provider.dart';

class PurchasedVouchersScreen extends StatefulWidget {
  const PurchasedVouchersScreen({Key? key}) : super(key: key);

  @override
  State<PurchasedVouchersScreen> createState() => _PurchasedVouchersScreenState();
}

class _PurchasedVouchersScreenState extends State<PurchasedVouchersScreen> {
  final ServiceProviderVoucherService _voucherService = ServiceProviderVoucherService();
  final ServiceProviderController _serviceProviderController = ServiceProviderController();
  List<ServiceProviderVoucherPurchase> _purchasedVouchers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchServiceProviderData();
    _loadPurchasedVouchers();
  }

  Future<void> _fetchServiceProviderData() async {
    await _serviceProviderController.initialize();
  }

  Future<void> _loadPurchasedVouchers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _voucherService.getPurchasedVouchers();

      if (result.isSuccess && result.data != null) {
        setState(() {
          _purchasedVouchers = result.data!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Failed to load purchased vouchers';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading purchased vouchers: $e';
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
                  onLogoNavigation: () {
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPurchasedVouchers,
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : Container(
                color: Colors.white,
                child: _purchasedVouchers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No purchased vouchers',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Purchase vouchers from the rewards section',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Column(
                                children: [
                                  // Title with dividers
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: Text(
                                          'My Vouchers',
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
                                  const SizedBox(height: 16),
                                  
                                  // Voucher cards
                                  ...(_purchasedVouchers.map((purchase) => 
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildPurchasedVoucherCard(purchase),
                                    ),
                                  ).toList()),
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

  Widget _buildPurchasedVoucherCard(ServiceProviderVoucherPurchase purchase) {
    final isUsed = purchase.isUsed;
    final statusColor = isUsed ? Colors.grey : Color(0xFF4CAF50);
    final statusText = isUsed ? 'Used' : 'Available';
    final statusIcon = isUsed ? Icons.check_circle : Icons.receipt;

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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${purchase.pointsUsed} \$',
                    style: TextStyle(
                      color: Color(0xFF2079C2),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Voucher ID: ${purchase.voucherId}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Purchased: ${_formatDate(purchase.purchasedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (purchase.usedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Used: ${_formatDate(purchase.usedAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              if (!isUsed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _useVoucher(purchase.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Use Voucher',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _useVoucher(String purchaseId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use Voucher?'),
        content: Text('Are you sure you want to use this voucher? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Use'),
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
        final result = await _voucherService.useVoucher(purchaseId);

        // Close loading dialog
        Navigator.of(context).pop();

        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voucher used successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh data after use
          _loadPurchasedVouchers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to use voucher'),
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
