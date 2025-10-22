import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../components/secure_network_image.dart';
import '../../../../utils/authService.dart';
import '../user_dashboard/notification.dart';
import '../user_dashboard/home.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import 'service_providers_list.dart';
import '../../screens/category/wholesaler_categories.dart';

class ServiceProviderCategoryData {
  final String id;
  final String? logoUrl;
  final String name;
  final Color color;
  final String? description;
  final bool isActive;

  ServiceProviderCategoryData({
    required this.id,
    this.logoUrl,
    required this.name,
    required this.color,
    this.description,
    this.isActive = true,
  });
}

class ServiceProviderCategoriesPage extends StatefulWidget {
  const ServiceProviderCategoriesPage({Key? key}) : super(key: key);

  @override
  _ServiceProviderCategoriesPageState createState() => _ServiceProviderCategoriesPageState();
}

class _ServiceProviderCategoriesPageState extends State<ServiceProviderCategoriesPage> {
  bool _isSidebarOpen = false;
  String? _profileImagePath;
  bool _isLoadingCategories = true;
  String? _categoriesError;

  // Dynamic categories loaded from backend
  List<ServiceProviderCategoryData> _allCategories = [];
  List<ServiceProviderCategoryData> _filteredCategories = [];

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
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

      print('ServiceProviderCategoriesPage: Loading categories from backend...');
      final categoriesData = await ApiService.getAllServiceProviderCategories();
      print('ServiceProviderCategoriesPage: Received categories: $categoriesData');
      
      if (mounted) {
        // Convert backend categories to ServiceProviderCategoryData objects
        final List<ServiceProviderCategoryData> backendCategories = [];
        
        for (var category in categoriesData) {
          final categoryName = category['name'] ?? '';
          if (categoryName.isNotEmpty) {
            // Parse color from hex string or use default
            Color categoryColor = Colors.blue;
            if (category['color'] != null) {
              try {
                String colorString = category['color'].toString();
                if (colorString.startsWith('#')) {
                  categoryColor = Color(int.parse(colorString.replaceFirst('#', '0xFF')));
                }
              } catch (e) {
                print('Error parsing color for category $categoryName: $e');
                categoryColor = Colors.blue;
              }
            }
            
            final serviceProviderCategory = ServiceProviderCategoryData(
              id: categoryName.toLowerCase().replaceAll(' ', '_'),
              logoUrl: category['logo'],
              name: categoryName,
              color: categoryColor,
              description: category['description'],
              isActive: category['isActive'] ?? true,
            );
            backendCategories.add(serviceProviderCategory);
          }
        }

        setState(() {
          _allCategories = backendCategories;
          _filteredCategories = List.from(backendCategories);
          _isLoadingCategories = false;
        });
        
        print('ServiceProviderCategoriesPage: Categories loaded successfully. Count: ${_allCategories.length}');
        print('ServiceProviderCategoriesPage: Categories: ${_allCategories.map((c) => c.name).toList()}');
      }
    } catch (e) {
      print('ServiceProviderCategoriesPage: Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _categoriesError = 'Failed to load categories: $e';
          _allCategories = [];
          _filteredCategories = [];
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
        _filteredCategories = List.from(_allCategories);
      } else {
        _filteredCategories = _allCategories.where((category) =>
          category.name.toLowerCase().contains(_searchQuery)
        ).toList();
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

  void _navigateToServiceProviders(ServiceProviderCategoryData category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceProvidersListPage(
          categoryName: category.name,
          categoryId: category.id,
        ),
      ),
    );
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
                  leading: Icon(Icons.store, color: Colors.white),
                  title: Text('Wholesalers', style: TextStyle(color: Colors.white)),
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
              ServiceProviderCategoriesHeader(
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
                        'Search results for "${_searchQuery}" (${_filteredCategories.length} found)',
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
              SizedBox(height: _isSearching ? 20 : 110),

              // Categories grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double screenWidth = constraints.maxWidth;
                    double itemWidth = screenWidth >= 700 ? 150 : 80;
                    int crossAxisCount = screenWidth < 600 ? 3 : 4;
                    
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
                              'Loading service provider categories...',
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
                    if (_isSearching && _filteredCategories.isEmpty) {
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
                              'No categories found',
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
                          childAspectRatio: 0.9,
                        ),
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredCategories.length,
                        itemBuilder: (context, index) {
                          final category = _filteredCategories[index];
                          return ServiceProviderCategoryItem(
                            logoUrl: category.logoUrl,
                            name: category.name,
                            color: category.color,
                            onTap: () {
                              _navigateToServiceProviders(category);
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

class ServiceProviderCategoriesHeader extends StatelessWidget {
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuTap;
  final String? profileImagePath;
  final TextEditingController? searchController;
  final bool isSearching;
  final VoidCallback? onClearSearch;

  const ServiceProviderCategoriesHeader({
    Key? key,
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

          // Service Provider Categories text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Service Provider Categories',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
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
                            hintText: 'Search service provider categories...',
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

class ServiceProviderCategoryItem extends StatelessWidget {
  final String? logoUrl;
  final String name;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const ServiceProviderCategoryItem({
    Key? key,
    this.logoUrl,
    required this.name,
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
          SizedBox(height: 6),
          // Category title
          Flexible(
            child: Container(
              width: width,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoWidget() {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      if (logoUrl!.startsWith('http')) {
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
        return Image.asset(
          logoUrl!,
          width: width * 0.5,
          height: width * 0.5,
          color: color,
        );
      }
    }
    
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Icon(
      Icons.business,
      size: width * 0.4,
      color: color,
    );
  }
}
