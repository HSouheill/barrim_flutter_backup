import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../models/voucher.dart';
import '../user_dashboard/notification.dart' as notification;
import '../user_dashboard/home.dart';
import '../category/categories.dart';
import '../workers/worker_home.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import 'user_referral.dart';
import 'package:barrim/src/utils/authService.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({Key? key}) : super(key: key);

  @override
  _RewardsPageState createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int points = 0;
  bool hasError = false;
  String errorMessage = '';
  bool _isSidebarOpen = false;
  String? _profileImagePath;
  List<UserVoucher> vouchers = [];
  bool isLoadingVouchers = false;
  Set<String> purchasedVoucherIds = {};
  List<UserVoucher> purchasedVouchers = [];
  bool isLoadingPurchasedVouchers = false;

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  Widget _buildSidebar() {
    return Container(
      width: 199,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2079C2),
            Color(0xFF1F4889),
            Color(0xFF10105D),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(5, 0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(top: 30),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset('assets/logo/sidebar_logo.png', width: 50, height: 50),
                      Text(
                        'Barrim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                ListTile(
                  leading: Icon(Icons.home, color: Colors.white),
                  title: Text('Home', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const UserDashboard(userData: {})),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.category, color: Colors.white),
                  title: Text('Categories', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const CategoriesPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.white),
                  title: Text('Workers', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const DriversGuidesPage()),
                      );
                    });
                  },
                ),
                // ListTile(
                //   leading: Icon(Icons.book_online, color: Colors.white),
                //   title: Text('Bookings', style: TextStyle(color: Colors.white)),
                //   onTap: () {
                //     _toggleSidebar();
                //     Future.delayed(const Duration(milliseconds: 300), () {
                //       Navigator.of(context).pushReplacement(
                //         MaterialPageRoute(builder: (context) => const MyBookingsPage()),
                //       );
                //     });
                //   },
                // ),
                ListTile(
                  leading: Icon(Icons.share, color: Colors.white),
                  title: Text('Referral', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const ReferralPointsPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.white),
                  title: Text('Settings', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.blue),
                      title: Text('Logout', style: TextStyle(color: Colors.blue)),
                      onTap: () async {
                        _toggleSidebar();
                        await AuthService().logout();
                        Future.delayed(const Duration(milliseconds: 300), () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchReferralData();
    _fetchUserData();
    _fetchVouchers();
    _fetchPurchasedVouchers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReferralData() async {
    setState(() {
      hasError = false;
    });

    try {
      final referralData = await ApiService.getReferralData();

      setState(() {
        points = referralData['points'] ?? 0;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });

      // Show error to user
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to load points: $errorMessage'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData['profilePic'] != null) {
        setState(() {
          _profileImagePath = ApiService.getImageUrl(userData['profilePic']);
          print('Profile Image Path: $_profileImagePath');
        });
      } else {
        print('No profile picture found in user data');
      }
    } catch (e) {
      print('Error fetching user data: $e');
      // Don't update state on error to keep existing profile picture
    }
  }

  Future<void> _fetchVouchers() async {
    setState(() {
      isLoadingVouchers = true;
    });

    try {
      final voucherData = await ApiService.getAvailableVouchers();
      
      // Debug: Print voucher data
      print('Voucher Data from API: $voucherData');
      
      setState(() {
        if (voucherData['vouchers'] != null) {
          vouchers = (voucherData['vouchers'] as List)
              .map((voucherJson) => UserVoucher.fromJson(voucherJson))
              .toList();
          print('Parsed ${vouchers.length} vouchers');
        }
        isLoadingVouchers = false;
      });
    } catch (e) {
      setState(() {
        isLoadingVouchers = false;
        hasError = true;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _fetchPurchasedVouchers() async {
    setState(() {
      isLoadingPurchasedVouchers = true;
    });

    try {
      final purchasedData = await ApiService.getUserPurchasedVouchers();
      
      // Debug: Print purchased voucher data
      print('Purchased Voucher Data from API: $purchasedData');
      
      setState(() {
        if (purchasedData['vouchers'] != null) {
          final vouchers = purchasedData['vouchers'] as List;
          purchasedVoucherIds = vouchers
              .map((userVoucher) => userVoucher['voucher']['id'] as String)
              .toSet();
          
          // Parse purchased vouchers
          purchasedVouchers = vouchers
              .map((userVoucherJson) => UserVoucher.fromJson(userVoucherJson))
              .toList();
          
          print('Found ${purchasedVoucherIds.length} purchased vouchers');
          print('Parsed ${purchasedVouchers.length} purchased voucher objects');
          
          // Debug: Print each voucher details
          for (int i = 0; i < purchasedVouchers.length; i++) {
            final voucher = purchasedVouchers[i].voucher;
            final purchase = purchasedVouchers[i].purchase;
            print('Voucher $i: ${voucher.title} (ID: ${voucher.id})');
            print('Purchase $i: Used=${purchase?.isUsed}, Date=${purchase?.purchasedAt}');
          }
        }
        isLoadingPurchasedVouchers = false;
      });
    } catch (e) {
      setState(() {
        isLoadingPurchasedVouchers = false;
      });
      print('Error fetching purchased vouchers: $e');
      // Don't update state on error to keep existing purchased vouchers
    }
  }

  Future<void> _purchaseVoucher(String voucherId) async {
    try {
      final result = await ApiService.purchaseVoucher(voucherId);
      
      if (result['status'] == 200) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher purchased successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Add to purchased vouchers set
        setState(() {
          purchasedVoucherIds.add(voucherId);
        });
        
        // Refresh vouchers and points
        await _fetchVouchers();
        await _fetchReferralData();
        await _fetchPurchasedVouchers();
      } else {
        throw Exception(result['message'] ?? 'Failed to purchase voucher');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to purchase voucher: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF2079C2),
                      Color(0xFF1F4889),
                      Color(0xFF10105D),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  children: [
                    Image.asset('assets/logo/barrim_logo.png', height: 70, width: 60),
                    Spacer(),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade200,
                      child: _profileImagePath != null && _profileImagePath!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                _profileImagePath!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading profile image: $error');
                                  print('Failed profile image path: $_profileImagePath');
                                  return Icon(Icons.person, color: Colors.white, size: 22);
                                },
                              ),
                            )
                          : Icon(Icons.person, color: Colors.white, size: 22),
                    ),
                    SizedBox(width: 12),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => notification.NotificationsPage(),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.notifications,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _toggleSidebar,
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  tabs: const [
                    Tab(text: 'Available'),
                    Tab(text: 'Purchased'),
                  ],
                ),
              ),

              // Points Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Points',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    Row(
                      children: [
                        Image.asset(
                          'assets/icons/points.png',
                          height: 24,
                          width: 24,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$points',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Rewards List
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Available Vouchers Tab
                    isLoadingVouchers
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : hasError
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Failed to load vouchers',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      errorMessage,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _fetchVouchers,
                                      child: Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : vouchers.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.card_giftcard,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No vouchers available',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Check back later for new rewards!',
                                          style: TextStyle(color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: vouchers.length,
                                    itemBuilder: (context, index) {
                                      final userVoucher = vouchers[index];
                                      return _buildVoucherCard(userVoucher);
                                    },
                                  ),
                    
                    // Purchased Vouchers Tab
                    isLoadingPurchasedVouchers
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : purchasedVouchers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No purchased vouchers',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Purchase vouchers to see them here!',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Debug: purchasedVouchers.length = ${purchasedVouchers.length}',
                                      style: TextStyle(color: Colors.red, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: purchasedVouchers.length,
                                itemBuilder: (context, index) {
                                  final userVoucher = purchasedVouchers[index];
                                  print('Building purchased voucher card $index: ${userVoucher.voucher.title}');
                                  return _buildPurchasedVoucherCard(userVoucher);
                                },
                              ),
                  ],
                ),
              ),
            ],
          ),

          // Semi-transparent overlay when sidebar is open
          if (_isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),

          // Sidebar
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _isSidebarOpen ? 0 : -250,
            top: 0,
            bottom: 0,
            child: _buildSidebar(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(UserVoucher userVoucher) {
    final voucher = userVoucher.voucher;
    final isPurchased = purchasedVoucherIds.contains(voucher.id);
    final canPurchase = userVoucher.canPurchase && points >= voucher.points && !isPurchased;
    
    // Debug: Print voucher information
    print('Voucher: ${voucher.title}');
    print('Image URL: ${voucher.imageUrl}');
    print('Full Image URL: ${voucher.imageUrl != null ? ApiService.getImageUrl(voucher.imageUrl!) : 'No image'}');
    print('Is Purchased: $isPurchased');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Row(
        children: [
          // Left side - voucher image or discount badge
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
            child: Container(
              width: 80,
              height: 80,
              color: voucher.imageUrl == null 
                  ? (voucher.discount != null ? Colors.red : Colors.blue)
                  : null,
              child: voucher.imageUrl != null
                  ? Image.network(
                      ApiService.getImageUrl(voucher.imageUrl!),
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading voucher image: $error');
                        print('Image URL: ${ApiService.getImageUrl(voucher.imageUrl!)}');
                        return Container(
                          color: voucher.discount != null ? Colors.red : Colors.blue,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (voucher.discount != null) ...[
                                  Text(
                                    voucher.discount!,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Text(
                                    'Discount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.card_giftcard,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const Text(
                                    'Voucher',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (voucher.discount != null) ...[
                            Text(
                              voucher.discount!,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Discount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              Icons.card_giftcard,
                              color: Colors.white,
                              size: 32,
                            ),
                            const Text(
                              'Voucher',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),

          // Right side - voucher details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (voucher.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      voucher.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/icons/points.png',
                            height: 20,
                            width: 20,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${voucher.points}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: canPurchase
                            ? () => _purchaseVoucher(voucher.id)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPurchased 
                              ? Colors.green 
                              : canPurchase 
                                  ? Colors.blue 
                                  : Colors.grey[300],
                          minimumSize: const Size(60, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          isPurchased 
                              ? 'Purchased' 
                              : canPurchase 
                                  ? 'Get' 
                                  : 'Insufficient Points',
                          style: TextStyle(
                            color: isPurchased 
                                ? Colors.white 
                                : canPurchase 
                                    ? Colors.white 
                                    : Colors.grey[600],
                            fontSize: isPurchased 
                                ? 12 
                                : canPurchase 
                                    ? 14 
                                    : 10,
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
          // Purchased indicator
          if (isPurchased)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPurchasedVoucherCard(UserVoucher userVoucher) {
    final voucher = userVoucher.voucher;
    final purchase = userVoucher.purchase;
    
    // Debug: Print voucher information
    print('Purchased Voucher: ${voucher.title}');
    print('Purchase Date: ${purchase?.purchasedAt}');
    print('Is Used: ${purchase?.isUsed}');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Left side - voucher image or discount badge
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  color: voucher.imageUrl == null 
                      ? (voucher.discount != null ? Colors.red : Colors.blue)
                      : null,
                  child: voucher.imageUrl != null
                      ? Image.network(
                          ApiService.getImageUrl(voucher.imageUrl!),
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading voucher image: $error');
                            print('Image URL: ${ApiService.getImageUrl(voucher.imageUrl!)}');
                            return Container(
                              color: voucher.discount != null ? Colors.red : Colors.blue,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (voucher.discount != null) ...[
                                      Text(
                                        voucher.discount!,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Text(
                                        'Discount',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.card_giftcard,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                      const Text(
                                        'Voucher',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (voucher.discount != null) ...[
                                Text(
                                  voucher.discount!,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'Discount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ] else ...[
                                Icon(
                                  Icons.card_giftcard,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const Text(
                                  'Voucher',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),

              // Right side - voucher details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (voucher.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          voucher.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (purchase != null) ...[
                        Text(
                          'Purchased: ${_formatDate(purchase.purchasedAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/icons/points.png',
                                height: 20,
                                width: 20,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${voucher.points}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: purchase?.isUsed == true ? Colors.orange : Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              purchase?.isUsed == true ? 'Used' : 'Available',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
          // Purchased indicator
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Placeholder for the NotificationsPage import
class NotificationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications')),
      body: Center(child: Text('Notifications Page')),
    );
  }
}