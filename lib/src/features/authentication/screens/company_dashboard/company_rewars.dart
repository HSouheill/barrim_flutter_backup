import 'package:flutter/material.dart';
import '../../../../services/company_referral_service.dart';
import '../../../../services/company_voucher_service.dart';
import '../../../../models/voucher_models.dart';
import '../../../../utils/token_manager.dart';
import '../../headers/company_header.dart';
import '../../../../services/api_service.dart';


class CompanyRewardsPage extends StatefulWidget {
   final Map<String, dynamic> userData; 
  const CompanyRewardsPage({Key? key, required this.userData}) : super(key: key);

  @override
  State<CompanyRewardsPage> createState() => _CompanyRewardsPageState();
}

class _CompanyRewardsPageState extends State<CompanyRewardsPage> {
  int companyPoints = 0;
  bool isLoading = true;
  String errorMessage = '';
  final TokenManager _tokenManager = TokenManager();
  String? logoUrl;
  List<CompanyVoucher> availableVouchers = [];
  List<CompanyVoucher> purchasedVouchers = []; // Changed to CompanyVoucher to match the API response
  Set<String> purchasedVoucherIds = {}; // Track purchased voucher IDs
  bool isLoadingVouchers = false;

  @override
  void initState() {
    super.initState();
    _fetchCompanyPoints();
    _loadCompanyData();
    _fetchAvailableVouchers();
    _fetchPurchasedVouchers();
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

  Future<void> _fetchCompanyPoints() async {
    try {
      final token = await _tokenManager.getToken();
      if (token?.isEmpty == true) {
        setState(() {
          isLoading = false;
          errorMessage = 'Authentication required';
        });
        return;
      }

      final referralService = CompanyReferralService(token: token ?? '');
      final result = await referralService.getCompanyReferralData();

      if (result['success']) {
        setState(() {
          companyPoints = result['data']['points'] ?? 0;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = result['error'] ?? 'Failed to load points';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading points: $e';
      });
    }
  }

  Future<void> _fetchAvailableVouchers() async {
    try {
      final token = await _tokenManager.getToken();
      if (token?.isEmpty == true) {
        return;
      }

      setState(() {
        isLoadingVouchers = true;
      });

      final voucherService = CompanyVoucherService(token: token!);
      final result = await voucherService.getAvailableVouchers();

      if (result['success']) {
        final data = result['data'];
        final vouchers = (data['vouchers'] as List?)
            ?.map((v) => CompanyVoucher.fromJson(v))
            .toList() ?? [];
        
        setState(() {
          availableVouchers = vouchers;
          isLoadingVouchers = false;
        });
      } else {
        setState(() {
          isLoadingVouchers = false;
        });
        print('Error fetching vouchers: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        isLoadingVouchers = false;
      });
      print('Exception fetching vouchers: $e');
    }
  }

  Future<void> _fetchPurchasedVouchers() async {
    try {
      final token = await _tokenManager.getToken();
      if (token?.isEmpty == true) {
        return;
      }

      final voucherService = CompanyVoucherService(token: token!);
      final result = await voucherService.getPurchasedVouchers();
      
      if (result['success']) {
        final data = result['data'];
        print('Purchased vouchers API response: $data');
        final List<CompanyVoucher> purchasedVouchers = (data['vouchers'] as List?)
            ?.map<CompanyVoucher>((v) => CompanyVoucher.fromJson(v))
            .toList() ?? <CompanyVoucher>[];
        
        // Extract voucher IDs from purchased vouchers
        final purchasedIds = purchasedVouchers
            .map((v) => v.voucher.id)
            .toSet();
        
        setState(() {
          this.purchasedVouchers = purchasedVouchers;
          purchasedVoucherIds = purchasedIds;
        });
        
        print('Fetched ${purchasedVouchers.length} purchased vouchers');
      } else {
        print('Error fetching purchased vouchers: ${result['error']}');
      }
      
    } catch (e) {
      print('Exception fetching purchased vouchers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CompanyAppHeader(
            logoUrl: logoUrl,
            userData: widget.userData,
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                ? Center(child: Text(errorMessage))
                : Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Rewards title with dividers
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
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

                          // Back button under title
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 16),
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back_ios,
                                      color: Color(0xFF2079C2),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Back',
                                      style: TextStyle(
                                        color: Color(0xFF2079C2),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

                          // Actual points display instead of hardcoded value
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '\$$companyPoints',
                              style: TextStyle(
                                fontSize: 32,
                                color: Color(0xFF2079C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),




                          // Available Vouchers Section
                          if (availableVouchers.isNotEmpty) ...[
                            // Row(
                            //   children: [
                            //     const Expanded(child: Divider()),
                            //     Padding(
                            //       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                            //       child: Text(
                            //         'Available Vouchers',
                            //         style: TextStyle(
                            //           color: Color(0xFF2079C2),
                            //           fontSize: 18,
                            //           fontWeight: FontWeight.bold,
                            //         ),
                            //       ),
                            //     ),
                            //     const Expanded(child: Divider()),
                            //   ],
                            // ),
                            const SizedBox(height: 16),
                            ...availableVouchers.map((companyVoucher) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildVoucherCard(companyVoucher),
                            )),
                          ],

                          // Loading indicator for vouchers
                          if (isLoadingVouchers)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            ),

                          // Purchased Vouchers Section
                          if (purchasedVouchers.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                                  child: Text(
                                    'Purchased Vouchers',
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
                            ...purchasedVouchers.map((companyVoucher) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildVoucherCard(companyVoucher),
                            )),
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


  // Build voucher card widget
  Widget _buildVoucherCard(CompanyVoucher companyVoucher) {
    final voucher = companyVoucher.voucher;
    final canPurchase = companyVoucher.canPurchase;
    final isPurchased = purchasedVoucherIds.contains(voucher.id);
    
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
        border: isPurchased ? Border.all(
          color: Colors.green.withOpacity(0.5),
          width: 2,
        ) : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Row(
          children: [
            Container(
              width: 80,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFF2079C2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: voucher.imageUrl != null && voucher.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                      child: Image.network(
                        voucher.imageUrl!.startsWith('http') 
                            ? voucher.imageUrl! 
                            : '${ApiService.baseUrl}/${voucher.imageUrl!.replaceFirst('/', '')}',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                voucher.discountType == 'percentage' 
                                    ? '${voucher.discountValue.toInt()}%'
                                    : '\$${voucher.discountValue.toInt()}',
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
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          voucher.discountType == 'percentage' 
                              ? '${voucher.discountValue.toInt()}%'
                              : '\$${voucher.discountValue.toInt()}',
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
                              fontSize: 14,
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
                          onPressed: isPurchased ? null : (canPurchase ? () {
                            _purchaseVoucher(voucher.id);
                          } : null),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPurchased
                                ? Colors.green
                                : canPurchase
                                    ? Color(0xFF2079C2)
                                    : Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            minimumSize: const Size(0, 25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            isPurchased ? 'Used' : 'Purchase',
                            style: TextStyle(
                              color: isPurchased 
                                  ? Colors.white 
                                  : canPurchase 
                                      ? Colors.white 
                                      : Colors.black54,
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
            // Used badge
            if (isPurchased)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'USED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseVoucher(String voucherId) async {
    try {
      final token = await _tokenManager.getToken();
      if (token?.isEmpty == true) {
        _showErrorDialog('Authentication required');
        return;
      }

      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Purchase Voucher?'),
          content: Text('This will deduct points from your balance and immediately activate the voucher.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Purchase'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final voucherService = CompanyVoucherService(token: token!);
      final result = await voucherService.purchaseVoucher(voucherId);

      // Hide loading
      Navigator.of(context).pop();

      if (result['success']) {
        _showSuccessDialog('Voucher purchased and activated successfully!');
        // Refresh data
        _fetchCompanyPoints();
        _fetchAvailableVouchers();
        _fetchPurchasedVouchers(); // Refresh purchased vouchers from backend
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to purchase voucher');
      }
    } catch (e) {
      // Hide loading if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorDialog('Error purchasing voucher: $e');
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

}