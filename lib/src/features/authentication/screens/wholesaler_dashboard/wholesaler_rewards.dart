import 'package:flutter/material.dart';
import '../../../../services/wholesaler_service.dart';
import '../../../../services/wholesaler_voucher_service.dart';
import '../../../../services/api_service.dart';
import '../../../../models/voucher_models.dart';
import '../../headers/wholesaler_header.dart';


class WholesalerRewards extends StatefulWidget {
  const WholesalerRewards({Key? key}) : super(key: key);

  @override
  State<WholesalerRewards> createState() => _WholesalerRewardsState();
}

class _WholesalerRewardsState extends State<WholesalerRewards> with TickerProviderStateMixin {
  final WholesalerService _wholesalerService = WholesalerService();
  final WholesalerVoucherService _voucherService = WholesalerVoucherService();
  bool _isLoading = true;
  int _points = 0;
  String _errorMessage = '';
  String? _logoUrl;
  
  // Voucher data
  List<WholesalerVoucher> _availableVouchers = [];
  List<WholesalerVoucherPurchase> _purchasedVouchers = [];
  bool _isLoadingVouchers = false;
  bool _isLoadingPurchased = false;
  
  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWholesalerData();
    _loadWholesalerLogo();
    _loadAvailableVouchers();
    _loadPurchasedVouchers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _loadAvailableVouchers() async {
    setState(() {
      _isLoadingVouchers = true;
    });

    try {
      final result = await _voucherService.getAvailableVouchers();
      if (mounted) {
        setState(() {
          _isLoadingVouchers = false;
          if (result.isSuccess) {
            _availableVouchers = result.data ?? [];
            // Debug: Print voucher data to see what we're getting
            for (var voucherData in _availableVouchers) {
              print('Voucher: ${voucherData.voucher.title}');
              print('Image URL: ${voucherData.voucher.imageUrl}');
              print('Full voucher data: ${voucherData.voucher.toJson()}');
            }
          } else {
            print('Error loading vouchers: ${result.errorMessage}');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVouchers = false;
        });
      }
      print('Error loading vouchers: $e');
    }
  }

  Future<void> _loadPurchasedVouchers() async {
    setState(() {
      _isLoadingPurchased = true;
    });

    try {
      final result = await _voucherService.getPurchasedVouchers();
      if (mounted) {
        setState(() {
          _isLoadingPurchased = false;
          if (result.isSuccess) {
            _purchasedVouchers = result.data ?? [];
          } else {
            print('Error loading purchased vouchers: ${result.errorMessage}');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPurchased = false;
        });
      }
      print('Error loading purchased vouchers: $e');
    }
  }

  Future<void> _purchaseVoucher(String voucherId) async {
    try {
      final result = await _voucherService.purchaseVoucher(voucherId);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voucher purchased successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh data
        _loadWholesalerData();
        _loadAvailableVouchers();
        _loadPurchasedVouchers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to purchase voucher'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _useVoucher(String purchaseId) async {
    try {
      final result = await _voucherService.useVoucher(purchaseId);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voucher used successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh purchased vouchers
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Import the company header from the provided file
          WholesalerHeader(logoUrl: _logoUrl, userData: {}),

          // Main content area
          Expanded(
            child: Container(
              color: Colors.white,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
                  : Column(
                children: [
                  // Balance section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      children: [
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
                      ],
                    ),
                  ),

                  // Tab bar
                  Container(
                    color: Colors.grey[100],
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Color(0xFF2079C2),
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: Color(0xFF2079C2),
                      tabs: const [
                        Tab(text: 'Available Vouchers'),
                        Tab(text: 'My Vouchers'),
                      ],
                    ),
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAvailableVouchersTab(),
                        _buildPurchasedVouchersTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableVouchersTab() {
    if (_isLoadingVouchers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableVouchers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No vouchers available at the moment.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableVouchers.length,
      itemBuilder: (context, index) {
        final voucherData = _availableVouchers[index];
        final voucher = voucherData.voucher;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Row(
            children: [
              // Minimized Voucher Image
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  color: Color(0xFF2079C2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  child: voucher.imageUrl != null && voucher.imageUrl!.isNotEmpty
                      ? Image.network(
                          _getVoucherImageUrl(voucher.imageUrl!),
                          fit: BoxFit.cover,
                          width: 80,
                          height: 100,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 80,
                              height: 100,
                              color: Color(0xFF2079C2),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Image load error: $error');
                            return _buildMinimizedImagePlaceholder();
                          },
                        )
                      : _buildMinimizedImagePlaceholder(),
                ),
              ),
              
              // Voucher Content
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
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (voucher.discountType.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Discount: ${voucher.discountValue}${voucher.discountType == 'percentage' ? '%' : '\$'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${voucher.points} pts',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2079C2),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: voucherData.canPurchase
                                ? () => _purchaseVoucher(voucher.id)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: voucherData.canPurchase
                                  ? Color(0xFF2079C2)
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              voucherData.canPurchase ? 'Purchase' : 'Insufficient',
                              style: const TextStyle(fontSize: 12),
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
        );
      },
    );
  }

  Widget _buildPurchasedVouchersTab() {
    if (_isLoadingPurchased) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_purchasedVouchers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'You haven\'t purchased any vouchers yet.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _purchasedVouchers.length,
      itemBuilder: (context, index) {
        final purchase = _purchasedVouchers[index];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Voucher #${purchase.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: purchase.isUsed ? Colors.grey : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        purchase.isUsed ? 'Used' : 'Available',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Points used: ${purchase.pointsUsed}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Purchased: ${_formatDate(purchase.purchasedAt)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (purchase.isUsed && purchase.usedAt != null) ...[
                  Text(
                    'Used: ${_formatDate(purchase.usedAt!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (!purchase.isUsed) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _useVoucher(purchase.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2079C2),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Use Voucher'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildMinimizedImagePlaceholder() {
    return Container(
      width: 80,
      height: 100,
      color: Color(0xFF2079C2),
      child: const Center(
        child: Icon(
          Icons.card_giftcard,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getVoucherImageUrl(String imageUrl) {
    print('Original imageUrl: $imageUrl');
    
    // If the imageUrl is already a full URL, return it as is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      print('Full URL detected: $imageUrl');
      return imageUrl;
    }
    
    // If it's a relative path starting with /, construct the full URL
    if (imageUrl.startsWith('/')) {
      String fullUrl = '${ApiService.baseUrl}$imageUrl';
      print('Absolute path - constructed URL: $fullUrl');
      return fullUrl;
    }
    
    // If it starts with uploads/, construct the full URL
    if (imageUrl.startsWith('uploads/')) {
      String fullUrl = '${ApiService.baseUrl}/$imageUrl';
      print('Uploads path - constructed URL: $fullUrl');
      return fullUrl;
    }
    
    // If it starts with file://, remove it and construct the full URL
    if (imageUrl.startsWith('file://')) {
      String cleanUrl = imageUrl.replaceFirst('file://', '');
      String fullUrl;
      if (cleanUrl.startsWith('/')) {
        fullUrl = '${ApiService.baseUrl}$cleanUrl';
      } else {
        fullUrl = '${ApiService.baseUrl}/$cleanUrl';
      }
      print('File URL - constructed URL: $fullUrl');
      return fullUrl;
    }
    
    // Default case: assume it's a filename and prepend uploads/ path
    String fullUrl = '${ApiService.baseUrl}/uploads/$imageUrl';
    print('Default case (filename) - constructed URL: $fullUrl');
    return fullUrl;
  }
}


