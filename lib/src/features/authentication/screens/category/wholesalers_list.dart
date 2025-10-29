import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../components/secure_network_image.dart';
import '../../../../utils/authService.dart';
import '../user_dashboard/notification.dart';
import '../user_dashboard/home.dart';
import '../workers/worker_home.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import 'wholesaler_categories.dart';
import '../help/how_to_use_app.dart';

class WholesalersListPage extends StatefulWidget {
  final String categoryName;
  final String subcategoryName;

  const WholesalersListPage({
    Key? key,
    required this.categoryName,
    required this.subcategoryName,
  }) : super(key: key);

  @override
  _WholesalersListPageState createState() => _WholesalersListPageState();
}

class _WholesalersListPageState extends State<WholesalersListPage> {
  bool _isSidebarOpen = false;
  String? _profileImagePath;
  bool _isLoadingWholesalers = true;
  String? _wholesalersError;

  // Wholesalers data
  List<Map<String, dynamic>> _allWholesalers = [];
  List<Map<String, dynamic>> _filteredWholesalers = [];

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadWholesalers();
    _fetchUserData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData['profilePic'] != null) {
        setState(() {
          _profileImagePath = ApiService.getImageUrl(userData['profilePic']);
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _loadWholesalers() async {
    try {
      setState(() {
        _isLoadingWholesalers = true;
        _wholesalersError = null;
      });

      print('WholesalersListPage: Loading wholesalers from backend...');
      final wholesalersData = await ApiService.getAllWholesalers();
      print('WholesalersListPage: Received ${wholesalersData.length} wholesalers');
      
      // Check if we received an empty list (no wholesalers in database)
      if (wholesalersData.isEmpty) {
        print('WholesalersListPage: No wholesalers found in database');
      }
      
      if (mounted) {
        // Filter wholesalers by subcategory
        final List<Map<String, dynamic>> subcategoryWholesalers = [];
        
        for (var wholesaler in wholesalersData) {
          final wholesalerMap = Map<String, dynamic>.from(wholesaler);
          final wholesalerSubcategory = wholesalerMap['subcategory']?.toString().toLowerCase() ?? '';
          final subcategoryName = widget.subcategoryName.toLowerCase();
          
          // Check if wholesaler belongs to this subcategory
          if (wholesalerSubcategory.contains(subcategoryName) || 
              subcategoryName.contains(wholesalerSubcategory) ||
              wholesalerSubcategory == subcategoryName) {
            subcategoryWholesalers.add(wholesalerMap);
          }
        }

        setState(() {
          _allWholesalers = subcategoryWholesalers;
          _filteredWholesalers = List.from(subcategoryWholesalers);
          _isLoadingWholesalers = false;
        });
        
        print('WholesalersListPage: Filtered ${subcategoryWholesalers.length} wholesalers for subcategory "${widget.subcategoryName}"');
      }
    } catch (e) {
      print('WholesalersListPage: Error loading wholesalers: $e');
      if (mounted) {
        setState(() {
          _isLoadingWholesalers = false;
          // Provide a more user-friendly error message
          if (e.toString().contains('Cannot connect to server')) {
            _wholesalersError = 'Unable to connect to the server. Please check your internet connection and try again.';
          } else if (e.toString().contains('timeout')) {
            _wholesalersError = 'Request timed out. Please check your internet connection and try again.';
          } else if (e.toString().contains('Failed to parse')) {
            _wholesalersError = 'There was an issue processing the data. Please try again.';
          } else {
            _wholesalersError = 'Failed to load wholesalers. Please try again.';
          }
          _allWholesalers = [];
          _filteredWholesalers = [];
        });
      }
    }
  }

  // Search functionality methods
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _isSearching = _searchQuery.isNotEmpty;
    });
    _applySearch();
  }

  void _applySearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredWholesalers = List.from(_allWholesalers);
      } else {
        _filteredWholesalers = _allWholesalers.where((wholesaler) {
          final name = wholesaler['name']?.toString().toLowerCase() ?? '';
          final businessName = wholesaler['businessName']?.toString().toLowerCase() ?? '';
          final description = wholesaler['description']?.toString().toLowerCase() ?? '';
          
          return name.contains(_searchQuery) || 
                 businessName.contains(_searchQuery) ||
                 description.contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isSearching = false;
    });
    _applySearch();
  }

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
                  leading: Icon(Icons.store, color: Colors.white),
                  title: Text('Wholesaler Categories', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const WholesalerCategoriesPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.white),
                  title: Text('Service Providers', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const DriversGuidesPage()),
                      );
                    });
                  },
                ),
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
                  leading: Icon(Icons.help_outline, color: Colors.white),
                  title: Text('How to Use', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HowToUseAppPage()),
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Custom header
          Column(
            children: [
              WholesalersListHeader(
                categoryName: widget.categoryName,
                subcategoryName: widget.subcategoryName,
                onBackPressed: () => Navigator.pop(context),
                onMenuTap: _toggleSidebar,
                profileImagePath: _profileImagePath,
                searchController: _searchController,
                isSearching: _isSearching,
                onClearSearch: _clearSearch,
              ),

              // Search results indicator
              if (_isSearching)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Search results for "${_searchQuery}" (${_filteredWholesalers.length} found)',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: _clearSearch,
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Space to accommodate overlapping tiles
              SizedBox(height: _isSearching ? 20 : 10),

              // Wholesalers list
              Expanded(
                child: _buildWholesalersList(),
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

  Widget _buildWholesalersList() {
    if (_isLoadingWholesalers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              'Loading wholesalers...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Show empty search results
    if (_isSearching && _filteredWholesalers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No wholesalers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Clear Search'),
            ),
          ],
        ),
      );
    }
    
    if (_wholesalersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load wholesalers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _wholesalersError!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadWholesalers,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredWholesalers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No wholesalers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No wholesalers available in this subcategory yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadWholesalers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredWholesalers.length,
        itemBuilder: (context, index) {
          final wholesaler = _filteredWholesalers[index];
          return WholesalerCard(
            wholesaler: wholesaler,
          );
        },
      ),
    );
  }
}

class WholesalersListHeader extends StatelessWidget {
  final String categoryName;
  final String subcategoryName;
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuTap;
  final String? profileImagePath;
  final TextEditingController? searchController;
  final bool isSearching;
  final VoidCallback? onClearSearch;

  const WholesalersListHeader({
    Key? key,
    required this.categoryName,
    required this.subcategoryName,
    this.onBackPressed,
    this.onMenuTap,
    this.profileImagePath,
    this.searchController,
    this.isSearching = false,
    this.onClearSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
        bottom: 50,
      ),
      height: 332,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top row with back button, logo and icons
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: onBackPressed,
              ),
              Image.asset('assets/logo/barrim_logo.png', height: 70, width: 60),
              Spacer(),
              CircleAvatar(
                backgroundColor: Colors.blue,
                backgroundImage: (profileImagePath != null && profileImagePath!.startsWith('http'))
                    ? null
                    : null,
                radius: 22,
                child: (profileImagePath != null && profileImagePath!.startsWith('http'))
                    ? ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: profileImagePath!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          placeholder: Icon(Icons.person, color: Colors.white),
                          errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.white),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white),
              ),
              SizedBox(width: 12),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsPage(),
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
                onPressed: onMenuTap,
              ),
            ],
          ),

          // Category and subcategory name
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  subcategoryName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Search bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search wholesalers...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(fontSize: 16, color: Colors.white),
                            contentPadding: EdgeInsets.symmetric(vertical: 9.5),
                          ),
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                      if (isSearching && onClearSearch != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GestureDetector(
                            onTap: onClearSearch,
                            child: Icon(Icons.clear, color: Colors.white, size: 24),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Icon(Icons.search, color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WholesalerCard extends StatelessWidget {
  final Map<String, dynamic> wholesaler;

  const WholesalerCard({
    Key? key,
    required this.wholesaler,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = wholesaler['name'] ?? wholesaler['businessName'] ?? 'Unknown Wholesaler';
    final description = wholesaler['description'] ?? 'Wholesaler';
    final address = wholesaler['address'] ?? '';
    final phone = wholesaler['phone'] ?? '';
    final email = wholesaler['email'] ?? '';
    final website = wholesaler['website'] ?? '';
    final rating = wholesaler['rating'] ?? 0.0;
    final isVerified = wholesaler['isVerified'] ?? false;
    final subcategory = wholesaler['subcategory'] ?? '';
    final category = wholesaler['category'] ?? '';
    final yearsInBusiness = wholesaler['yearsInBusiness'] ?? wholesaler['yearsExperience'] ?? 0;
    final workingHours = wholesaler['workingHours'] ?? '';
    final deliveryAvailable = wholesaler['deliveryAvailable'] ?? false;
    final minimumOrder = wholesaler['minimumOrder'] ?? '';
    final paymentMethods = wholesaler['paymentMethods'] ?? [];
    final socialMedia = wholesaler['socialMedia'] ?? {};

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image and basic info
            Row(
              children: [
                // Profile image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildProfileImage(),
                ),
                SizedBox(width: 16),

                // Basic info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and verification
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified)
                            Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 20,
                            ),
                        ],
                      ),
                      SizedBox(height: 4),

                      // Category and subcategory
                      if (category.isNotEmpty || subcategory.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.category, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                category.isNotEmpty && subcategory.isNotEmpty 
                                    ? '$category - $subcategory'
                                    : category.isNotEmpty ? category : subcategory,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                      ],

                      // Rating
                      if (rating > 0) ...[
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Description
            if (description.isNotEmpty) ...[
              Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 12),
            ],

            // Contact Information
            if (phone.isNotEmpty || email.isNotEmpty || website.isNotEmpty) ...[
              Text(
                'Contact Information',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              if (phone.isNotEmpty) ...[
                _buildInfoRow(Icons.phone, 'Phone', phone),
                SizedBox(height: 4),
              ],
              if (email.isNotEmpty) ...[
                _buildInfoRow(Icons.email, 'Email', email),
                SizedBox(height: 4),
              ],
              if (website.isNotEmpty) ...[
                _buildInfoRow(Icons.language, 'Website', website),
                SizedBox(height: 4),
              ],
              SizedBox(height: 12),
            ],

            // Address
            if (address.isNotEmpty) ...[
              Text(
                'Address',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 4),
              _buildInfoRow(Icons.location_on, '', address),
              SizedBox(height: 12),
            ],

            // Business Details
            if (yearsInBusiness > 0 || workingHours.isNotEmpty || minimumOrder.isNotEmpty) ...[
              Text(
                'Business Details',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              if (yearsInBusiness > 0) ...[
                _buildInfoRow(Icons.business, 'Years in Business', '$yearsInBusiness years'),
                SizedBox(height: 4),
              ],
              if (workingHours.isNotEmpty) ...[
                _buildInfoRow(Icons.access_time, 'Working Hours', workingHours),
                SizedBox(height: 4),
              ],
              if (minimumOrder.isNotEmpty) ...[
                _buildInfoRow(Icons.shopping_cart, 'Minimum Order', minimumOrder),
                SizedBox(height: 4),
              ],
              if (deliveryAvailable) ...[
                _buildInfoRow(Icons.local_shipping, 'Delivery', 'Available'),
                SizedBox(height: 4),
              ],
              SizedBox(height: 12),
            ],

            // Payment Methods
            if (paymentMethods.isNotEmpty) ...[
              Text(
                'Payment Methods',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: paymentMethods.map<Widget>((method) => 
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      method.toString(),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).toList(),
              ),
              SizedBox(height: 12),
            ],

            // Social Media
            if (socialMedia.isNotEmpty) ...[
              Text(
                'Social Media',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: socialMedia.entries.map<Widget>((entry) {
                  IconData icon;
                  switch (entry.key.toLowerCase()) {
                    case 'facebook':
                      icon = Icons.facebook;
                      break;
                    case 'instagram':
                      icon = Icons.camera_alt;
                      break;
                    case 'twitter':
                      icon = Icons.alternate_email;
                      break;
                    case 'linkedin':
                      icon = Icons.business;
                      break;
                    case 'whatsapp':
                      icon = Icons.message;
                      break;
                    default:
                      icon = Icons.link;
                  }
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: Colors.blue[600]),
                      SizedBox(width: 4),
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty) ...[
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
              ],
              Text(
                value,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    final profilePic = wholesaler['profilePic'] ?? wholesaler['logo'];
    
    if (profilePic != null && profilePic.toString().isNotEmpty) {
      final imageUrl = ApiService.getImageUrl(profilePic.toString());
      return SecureNetworkImage(
        imageUrl: imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: Container(
          width: 60,
          height: 60,
          color: Colors.grey[300],
          child: Icon(Icons.store, color: Colors.grey[600]),
        ),
        errorWidget: (context, url, error) => Container(
          width: 60,
          height: 60,
          color: Colors.grey[300],
          child: Icon(Icons.store, color: Colors.grey[600]),
        ),
      );
    }
    
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[300],
      child: Icon(Icons.store, color: Colors.grey[600]),
    );
  }
}
