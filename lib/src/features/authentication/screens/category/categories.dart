import 'package:flutter/material.dart';
// Remove or rename this import to avoid the Context conflict
// import 'package:path/path.dart' as path_helper;  // Use with alias to avoid conflict

import '../../headers/sidebar.dart';
import '../user_dashboard/notification.dart';
import 'category_filter.dart';
import 'category_places.dart';
import '../user_dashboard/home.dart';
import '../workers/worker_home.dart';
import '../booking/myboooking.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import '../../../../services/api_service.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class CategoryData {
  final String id;
  final String iconPath;
  final String title;
  final Color color;
  final double price; // For price filtering
  final double rating; // For rating filtering
  final bool isOpen; // For "Open Now" filtering
  final double distance; // For "Closest to" filtering

  CategoryData({
    required this.id,
    required this.iconPath,
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

  @override
  void initState() {
    super.initState();
    _applyFilters(_filterOptions);
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

  // Create a list of all categories
  final List<CategoryData> _allCategories = [
    // Featured categories (shown at the top)
    CategoryData(
      id: 'food_dining',
      iconPath: 'assets/icons/food_dining.png',
      title: "Food & Dining",
      color: Colors.blue,
      price: 300,
      rating: 4.5,
      isOpen: true,
      distance: 2.5,
    ),
    CategoryData(
      id: 'nightlife',
      iconPath: 'assets/icons/nightlife.png',
      title: "Nightlife",
      color: Colors.blue,
      price: 500,
      rating: 4.2,
      isOpen: true,
      distance: 3.1,
    ),
    CategoryData(
      id: 'shopping',
      iconPath: 'assets/icons/shopping.png',
      title: "Shopping",
      color: Colors.blue,
      price: 200,
      rating: 4.0,
      isOpen: true,
      distance: 1.8,
    ),

    // Regular grid categories
    CategoryData(
      id: 'health',
      iconPath: 'assets/icons/health.png',
      title: "Health",
      color: Colors.blue,
      price: 400,
      rating: 4.7,
      isOpen: true,
      distance: 5.2,
    ),
    // Rest of the categories (unchanged)
    CategoryData(
      id: 'services',
      iconPath: 'assets/icons/services.png',
      title: "Services",
      color: Colors.blue,
      price: 150,
      rating: 3.8,
      isOpen: false,
      distance: 4.0,
    ),
    CategoryData(
      id: 'education',
      iconPath: 'assets/icons/education.png',
      title: "Education",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'Transportation',
      iconPath: 'assets/icons/transportation.png',
      title: "Transportation",
      color: Colors.blue,
      price: 50,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'Events',
      iconPath: 'assets/icons/events.png',
      title: "Events",
      color: Colors.blue,
      price: 50,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'outdoor_activities',
      iconPath: 'assets/icons/outdoor_activities.png',
      title: "Outdoor Activities",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'Entertainment',
      iconPath: 'assets/icons/entertainment.png',
      title: "Entertainment",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'Home_Living',
      iconPath: 'assets/icons/home_living.png',
      title: "Home & Living",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'Beauty_Fashion',
      iconPath: 'assets/icons/beauty_fashion.png',
      title: "Beauty & Fashion",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'Automative_Services',
      iconPath: 'assets/icons/automative_services.png',
      title: "Automative & Services",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'real_state',
      iconPath: 'assets/icons/realState.png',
      title: "Real State",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'cultural_sites',
      iconPath: 'assets/icons/cultural_sites.png',
      title: "Cultural Sites",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'kids_family',
      iconPath: 'assets/icons/kids_family.png',
      title: "Kids & Family",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'pet_services',
      iconPath: 'assets/icons/pet_services.png',
      title: "Pet Services",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'financial_services',
      iconPath: 'assets/icons/financial_services.png',
      title: "Financial Services",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'tech_gadgets',
      iconPath: 'assets/icons/tech_gadgets.png',
      title: "Tech Gadgets Services",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'souks_artisans',
      iconPath: 'assets/icons/souks_artisans.png',
      title: "Souks & Artisans",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'speciality_stores',
      iconPath: 'assets/icons/speciality_stores.png',
      title: "Speciality Stores",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'hospitality',
      iconPath: 'assets/icons/hospitality.png',
      title: "Hospitality",
      color: Colors.blue,
      price: 800,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'emergency_services',
      iconPath: 'assets/icons/emergency_services.png',
      title: "Emergency Services",
      color: Colors.blue,
      price: 200,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
    CategoryData(
      id: 'deals_promos',
      iconPath: 'assets/icons/deals_promos.png',
      title: "Deals & Promos",
      color: Colors.blue,
      price: 200,
      rating: 4.9,
      isOpen: true,
      distance: 7.5,
    ),
  ];

  List<CategoryData> _filteredCategories = [];
  List<CategoryData> _featuredCategories = [];

  // Method to apply filters
  void _applyFilters(FilterOptions filters) {
    setState(() {
      _filterOptions = filters;

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
      _featuredCategories = filtered.where((cat) =>
          ['food_dining', 'nightlife', 'shopping'].contains(cat.id)
      ).take(3).toList();

      _filteredCategories = filtered.where((cat) =>
      !['food_dining', 'nightlife', 'shopping'].contains(cat.id)
      ).toList();
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
                        MaterialPageRoute(builder: (context) => const Home(userData: {})),
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
                      onTap: () {
                        _toggleSidebar();
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
                    return GridView.builder(
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
                          iconPath: category.iconPath,
                          title: category.title,
                          color: category.color,
                          onTap: () {
                            _navigateToCategoryPlaces(category);
                          },
                          width: itemWidth,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // First row of featured categories overlapping the header
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
                          iconPath: category.iconPath,
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
  final String iconPath;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const CategoryItem({
    Key? key,
    required this.iconPath,
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
              child: Image.asset(
                iconPath,
                width: width * 0.5,
                height: width * 0.5,
                color: color, // Optional: tint the image
              ),
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
}