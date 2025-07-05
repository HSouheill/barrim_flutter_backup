import 'package:flutter/material.dart';
import '../../../../services/company_referral_service.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchCompanyPoints();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    try {
      final token = await _tokenManager.getToken();
      if (token.isNotEmpty) {
        var data = await ApiService.getCompanyData(token);
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
      if (token.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'Authentication required';
        });
        return;
      }

      final referralService = CompanyReferralService(token: token);
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

  // Updated reward card widget to handle points comparison
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
                            // TODO: Implement redemption logic
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

  // Updated freebie reward card widget
  Widget _buildFreebieRewardCard({
    required String title,
    required String pointsRequired,
    required String image,
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
              child: Image.asset(
                image,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
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
                        title,
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
                            // TODO: Implement redemption logic
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
    // TODO: Implement actual redemption logic
    // This would involve calling an API endpoint to deduct points
    // and grant the reward

    // For now, just show a confirmation dialog
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
      // Refresh points after redemption
      _fetchCompanyPoints();
    }
  }
}