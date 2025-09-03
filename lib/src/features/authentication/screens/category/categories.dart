import 'package:flutter/material.dart';

import '../user_dashboard/notification.dart';
import 'category_filter.dart';
import 'category_places.dart';
import '../user_dashboard/home.dart';
import '../workers/worker_home.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import '../../../../services/api_service.dart';
import 'package:barrim/src/components/secure_network_image.dart';
import 'package:barrim/src/utils/authService.dart';

class CategoryData {
  final String id;
  final String? logoUrl; // Changed from iconPath to logoUrl
  final String title;
  final Color color;
  final double price; // For price filtering
  final double rating; // For rating filtering
  final bool isOpen; // For "Open Now" filtering
  final double distance; // For "Closest to" filtering

  CategoryData({
    required this.id,
    this.logoUrl, // Made optional since it might not be available
    required this.title,
    required this.color,
    required this.price,
    required this.rating,
    this.isOpen = true,
    this.distance = 0.0,
  });
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({Key? key}) : super(key: key);

  @override
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  bool _isSidebarOpen = false;
  String? _profileImagePath;
  bool _isLoadingCategories = true;
  String? _categoriesError;

  // Dynamic categories loaded from backend
  List<CategoryData> _allCategories = [];
  List<CategoryData> _filteredCategories = [];
  List<CategoryData> _featuredCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData != null && userData['profilePic'] != null) {
        setState(() {
          _profileImagePath = ApiService.getImageUrl(userData['profilePic']);
          print('Profile Image Path: $_profileImagePath');
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _categoriesError = null;
      });

      print('CategoriesPage: Loading categories from backend...');
      final categoriesData = await ApiService.getAllCategoriesWithLogos();
      print('CategoriesPage: Received categories: $categoriesData');
      
      if (mounted) {
        // Convert backend categories to CategoryData objects
        final List<CategoryData> backendCategories = [];
        
        for (var entry in categoriesData.entries) {
          final categoryName = entry.key;
          final categoryData = entry.value;
          
          // Parse color from hex string or use default
          Color categoryColor = Colors.blue;
          if (categoryData['color'] != null) {
            try {
              categoryColor = Color(int.parse(categoryData['color'].toString().replaceFirst('#', '0xFF')));
            } catch (e) {
              print('Error parsing color for category $categoryName: $e');
              categoryColor = Colors.blue;
            }
          }
          
          final category = CategoryData(
            id: categoryName.toLowerCase().replaceAll(' ', '_'),
            logoUrl: categoryData['logo'],
            title: categoryName,
            color: categoryColor,
            price: _getDefaultPriceForCategory(categoryName),
            rating: _getDefaultRatingForCategory(categoryName),
            isOpen: true,
            distance: _getDefaultDistanceForCategory(categoryName),
          );
          backendCategories.add(category);
        }

        setState(() {
          _allCategories = backendCategories;
          _isLoadingCategories = false;
        });
        
        print('CategoriesPage: Categories loaded successfully. Count: ${_allCategories.length}');
        print('CategoriesPage: Categories: ${_allCategories.map((c) => c.title).toList()}');
        
        // Apply initial filters after categories are loaded
        _applyFilters(_filterOptions);
      }
    } catch (e) {
      print('CategoriesPage: Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _categoriesError = 'Failed to load categories: $e';
          _allCategories = [];
          _filteredCategories = [];
          _featuredCategories = [];
        });
      }
    }
  }

  // Helper method to get default price for a category
  double _getDefaultPriceForCategory(String categoryName) {
    final categoryLower = categoryName.toLowerCase();
    
    if (categoryLower.contains('food') || categoryLower.contains('restaurant')) {
      return 300.0;
    } else if (categoryLower.contains('night') || categoryLower.contains('bar')) {
      return 500.0;
    } else if (categoryLower.contains('shop') || categoryLower.contains('retail')) {
      return 200.0;
    } else if (categoryLower.contains('health') || categoryLower.contains('medical')) {
      return 400.0;
    } else if (categoryLower.contains('education') || categoryLower.contains('university')) {
      return 800.0;
    } else if (categoryLower.contains('transport') || categoryLower.contains('car')) {
      return 50.0;
    } else if (categoryLower.contains('emergency') || categoryLower.contains('urgent')) {
      return 200.0;
    } else {
      return 400.0; // Default price
    }
  }

  // Helper method to get default rating for a category
  double _getDefaultRatingForCategory(String categoryName) {
    // Most categories get a good default rating
    return 4.5;
  }

  // Helper method to get default distance for a category
  double _getDefaultDistanceForCategory(String categoryName) {
    // Random distance between 1-10 km for variety
    return 2.0 + (categoryName.length % 8);
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _navigateToCategoryPlaces(CategoryData category) {
    // Remove the explicit cast to BuildContext
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPlaces(categoryId: category.id),
      ),
    );
  }

  FilterOptions _filterOptions = FilterOptions(
    priceSort: 'none',
    priceRange: const RangeValues(0, 1000),
    ratingSort: 'none',
    openNow: false,
    closest: false,
  );

  // Method to apply filters
  void _applyFilters(FilterOptions filters) {
    setState(() {
      _filterOptions = filters;

      // Check if categories are available
      if (_allCategories.isEmpty) {
        _featuredCategories = [];
        _filteredCategories = [];
        return;
      }

      // Start with all categories
      List<CategoryData> filtered = List.from(_allCategories);

      // Apply price range filter
      filtered = filtered.where((category) =>
      category.price >= filters.priceRange.start &&
          category.price <= filters.priceRange.end
      ).toList();

      // Apply "Open Now" filter if enabled
      if (filters.openNow) {
        filtered = filtered.where((category) => category.isOpen).toList();
      }

      // Apply sorting
      if (filters.priceSort == 'highToLow') {
        filtered.sort((a, b) => b.price.compareTo(a.price));
      } else if (filters.priceSort == 'lowToHigh') {
        filtered.sort((a, b) => a.price.compareTo(b.price));
      }

      if (filters.ratingSort == 'highToLow') {
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
      } else if (filters.ratingSort == 'lowToHigh') {
        filtered.sort((a, b) => a.rating.compareTo(b.rating));
      }

      // Apply "Closest to" filter if enabled
      if (filters.closest) {
        filtered.sort((a, b) => a.distance.compareTo(b.distance));
      }

      // Separate featured categories (first 3) and regular grid categories
      // Use dynamic featured categories instead of hardcoded ones
      _featuredCategories = filtered.take(3).toList();
      _filteredCategories = filtered.skip(3).toList();
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Custom header with categories title and search bar
          Column(
            children: [
              CategoriesHeader(
                onBackPressed: () => Navigator.pop(context),
                onMenuTap: _toggleSidebar,
                onFilterTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FiltersPage(
                        initialFilters: _filterOptions,
                        onApplyFilters: _applyFilters,
                      ),
                    ),
                  );
                },
                filterOptions: _filterOptions,
                applyFilters: _applyFilters,
                profileImagePath: _profileImagePath,
              ),

              // Space to accommodate overlapping tiles
              SizedBox(height: 110),

              // Categories grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double screenWidth = constraints.maxWidth;
                    // Use 150 for iPad/large screens, 80 for phones
                    double itemWidth = screenWidth >= 700 ? 150 : 80;
                    int crossAxisCount = screenWidth < 600 ? 3 : 4; // Responsive: 3 for phones, 4 for larger screens
                    
                    if (_isLoadingCategories) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading categories...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (_categoriesError != null) {
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
                              'Failed to load categories',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _categoriesError!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadCategories,
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
                    
                    
                    return RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredCategories.length,
                        itemBuilder: (context, index) {
                          final category = _filteredCategories[index];
                          return CategoryItem(
                            logoUrl: category.logoUrl, // Pass logoUrl
                            title: category.title,
                            color: category.color,
                            onTap: () {
                              _navigateToCategoryPlaces(category);
                            },
                            width: itemWidth,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // First row of featured categories overlapping the header
          if (!_isLoadingCategories && _categoriesError == null && _featuredCategories.isNotEmpty)
            Positioned(
              top: 280,
              left: 12,
              right: 12,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double screenWidth = constraints.maxWidth;
                  double itemWidth = screenWidth >= 700 ? 150 : 80;
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _featuredCategories.map((category) =>
                          CategoryItem(
                            logoUrl: category.logoUrl, // Pass logoUrl
                            title: category.title,
                            color: category.color,
                            onTap: () {
                              _navigateToCategoryPlaces(category);
                            },
                            width: itemWidth,
                          )
                      ).toList(),
                    ),
                  );
                },
              ),
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
}

class CategoriesHeader extends StatelessWidget {
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuTap;
  final VoidCallback? onFilterTap;
  // Add these parameters to pass from parent
  final FilterOptions filterOptions;
  final Function(FilterOptions) applyFilters;
  final String? profileImagePath;

  const CategoriesHeader({
    Key? key,
    this.onBackPressed,
    this.onMenuTap,
    this.onFilterTap,
    required this.filterOptions,  // Add this required parameter
    required this.applyFilters,  // Add this required parameter
    this.profileImagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF2079C2), // #2079C2
            Color(0xFF1F4889), // #1F4889
            Color(0xFF10105D), // #10105D
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 50, // Increased bottom padding to make room for overlapping tiles
      ),
      height: 332, // Keep the original height
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top row with logo and icons
          Row(
            children: [
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
                  // Navigate to Categories page when menu icon is clicked
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
                onPressed: onMenuTap, // Use the callback here
              ),
            ],
          ),

          // Categories text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Categories',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Search bar and filter button
          Row(
            children: [
              // Search bar
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
                          decoration: InputDecoration(
                            hintText: 'Search for places, categories...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(fontSize: 16, color: Colors.white),
                            contentPadding: EdgeInsets.symmetric(vertical: 9.5),
                          ),
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
              SizedBox(width: 8),
              // Filter button with navigation to FiltersPage
              GestureDetector(
                onTap: onFilterTap, // Use the callback directly
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.filter_list, color: Colors.blue, size: 30),
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

class CategoryItem extends StatelessWidget {
  final String? logoUrl; // Changed from iconPath to logoUrl
  final String title;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const CategoryItem({
    Key? key,
    this.logoUrl, // Made optional since it might not be available
    required this.title,
    required this.color,
    required this.onTap,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container
          Container(
            width: width,
            height: width,
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
            child: Center(
              child: _buildLogoWidget(),
            ),
          ),
          SizedBox(height: 8),
          // Category title - increase width and add Container for better control
          Container(
            width: width, // Slightly wider than the icon container
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoWidget() {
    // If we have a logo URL, try to load it as a network image
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      if (logoUrl!.startsWith('http')) {
        // Network image
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SecureNetworkImage(
            imageUrl: logoUrl!,
            width: width * 0.6,
            height: width * 0.6,
            fit: BoxFit.contain,
            placeholder: _buildFallbackIcon(),
            errorWidget: (context, url, error) => _buildFallbackIcon(),
          ),
        );
      } else if (logoUrl!.startsWith('assets/')) {
        // Asset image
        return Image.asset(
          logoUrl!,
          width: width * 0.5,
          height: width * 0.5,
          color: color,
        );
      }
    }
    
    // Fallback to default icon
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Icon(
      Icons.category,
      size: width * 0.4,
      color: color,
    );
  }
}