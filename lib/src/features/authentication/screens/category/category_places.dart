import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../../../../services/api_service.dart';
import '../../../../components/secure_network_image.dart'; // Add SecureNetworkImage import
import '../referrals/rewards.dart';
import '../settings/settings.dart'; // Add SettingsPage import
import 'branch_details.dart';
import 'category_filter.dart'; // Add this import for FilterOptions
import '../../headers/dashboard_headers.dart';
import '../../headers/sidebar.dart';

class CategoryPlaces extends StatefulWidget {
  final String categoryId;

  const CategoryPlaces({super.key, required this.categoryId});

  @override
  _CategoryPlacesState createState() => _CategoryPlacesState();
}

class _CategoryPlacesState extends State<CategoryPlaces> {
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _filteredBranches = []; // Add filtered branches list
  bool _isLoading = true;
  String _errorMessage = '';
  String? _profileImagePath;
  bool _isSidebarOpen = false;

  // Add filter options
  FilterOptions _filterOptions = FilterOptions(
    priceSort: 'none',
    priceRange: const RangeValues(0, 1000),
    ratingSort: 'none',
    openNow: false,
    closest: false,
  );

  // Map to define category relationships (parent categories and their related subcategories)
  final Map<String, List<String>> _categoryRelationships = {
    'food_dining': ['Restaurant', 'Cafe', 'Fast Food', 'Bakery', 'Dessert', 'Fine & Dining'],
    'Restaurant': ['food_dining', 'Fine & Dining', 'Cafe', 'Casual Dining'],
    'nightlife': ['Bar', 'Club', 'Lounge', 'Pub', 'Karaoke'],
    'shopping': ['Mall', 'Boutique', 'Market', 'Department Store', 'Retail'],
    'health': ['Hospital', 'Clinic', 'Pharmacy', 'Fitness', 'Wellness'],
    'services': ['Cleaning', 'Repair', 'Maintenance', 'Delivery', 'Professional'],
    // Add more relationships as needed
  };

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData != null && userData['profilePic'] != null) {
        setState(() {
          _profileImagePath = ApiService.getImageUrl(userData['profilePic']);
          if (!kReleaseMode) {
            print('Profile Image Path: $_profileImagePath');
          }
        });
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error fetching user data: $e');
      }
    }
  }

  Future<void> _loadBranches() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Fetch all branches - this already returns List<Map<String, dynamic>>
      final List<Map<String, dynamic>> allBranches = await ApiService.getAllBranches();

      if (!kReleaseMode) {
        print('Found ${allBranches.length} branches in the response');
      }

      // Get related categories for the selected category
      final relatedCategories = _getRelatedCategories(widget.categoryId);
      if (!kReleaseMode) {
        print('Related categories to ${widget.categoryId}: $relatedCategories');
      }

      // Filter branches by category or subcategory including related ones
      final filteredBranches = allBranches.where((branch) {
        // Filter out branches whose status is not active
        final branchStatus = branch['status'];
        if (branchStatus != 'active') {
          return false;
        }
        // Debug branch data
        if (!kReleaseMode) {
          print('Processing branch: ${branch['name']} - Category: ${branch['category']}, SubCategory: ${branch['subCategory']}');
        }

        // Get category and subcategory with case-insensitive comparison
        final String branchCategory = (branch['category'] ?? '').toString();
        final String branchSubCategory = (branch['subCategory'] ?? '').toString();

        // For category matching, check main category and related categories
        final bool categoryMatch =
            _matchesCategory(branchCategory, widget.categoryId) ||
                relatedCategories.any((cat) => _matchesCategory(branchCategory, cat));

        // For subcategory matching, check if subcategory matches our categoryId or related categories
        final bool subCategoryMatch =
            _matchesCategory(branchSubCategory, widget.categoryId) ||
                relatedCategories.any((cat) => _matchesCategory(branchSubCategory, cat));

        // Debug match results
        if (categoryMatch || subCategoryMatch) {
          if (!kReleaseMode) {
            print('MATCH found for branch: ${branch['name']}');
            print('categoryMatch: $categoryMatch, subCategoryMatch: $subCategoryMatch');
          }
        }

        // Return true if either the main category or the subcategory matches
        return categoryMatch || subCategoryMatch;
      }).toList();

      if (!kReleaseMode) {
        print('Filtered branches count: ${filteredBranches.length}');
      }

      setState(() {
        _branches = filteredBranches;
        _filteredBranches = filteredBranches; // Initialize filtered branches
        _isLoading = false;
      });
      
      // Apply initial filters after branches are loaded
      _applyFilters(_filterOptions);
    } catch (e) {
      if (!kReleaseMode) {
        print('Error loading branches: $e');
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load branches: ${e.toString()}';
      });
    }
  }

  // Method to apply filters to branches
  void _applyFilters(FilterOptions filters) {
    setState(() {
      _filterOptions = filters;

      // Start with all branches
      List<Map<String, dynamic>> filtered = List.from(_branches);

      // Apply price range filter (if branches have price data)
      filtered = filtered.where((branch) {
        // Extract price from branch data, default to 0 if not available
        double branchPrice = 0.0;
        if (branch['price'] != null && branch['price'] is num) {
          branchPrice = (branch['price'] as num).toDouble();
        } else if (branch['averagePrice'] != null && branch['averagePrice'] is num) {
          branchPrice = (branch['averagePrice'] as num).toDouble();
        }
        
        return branchPrice >= filters.priceRange.start && branchPrice <= filters.priceRange.end;
      }).toList();

      // Apply "Open Now" filter if enabled
      if (filters.openNow) {
        filtered = filtered.where((branch) {
          // Check if branch is open (you may need to adjust this based on your data structure)
          final isOpen = branch['isOpen'] ?? branch['openNow'] ?? true;
          return isOpen == true;
        }).toList();
      }

      // Apply sorting
      if (filters.priceSort == 'highToLow') {
        filtered.sort((a, b) {
          double priceA = _extractPrice(a);
          double priceB = _extractPrice(b);
          return priceB.compareTo(priceA);
        });
      } else if (filters.priceSort == 'lowToHigh') {
        filtered.sort((a, b) {
          double priceA = _extractPrice(a);
          double priceB = _extractPrice(b);
          return priceA.compareTo(priceB);
        });
      }

      if (filters.ratingSort == 'highToLow') {
        filtered.sort((a, b) {
          double ratingA = _extractRating(a);
          double ratingB = _extractRating(b);
          return ratingB.compareTo(ratingA);
        });
      } else if (filters.ratingSort == 'lowToHigh') {
        filtered.sort((a, b) {
          double ratingA = _extractRating(a);
          double ratingB = _extractRating(b);
          return ratingA.compareTo(ratingB);
        });
      }

      // Apply "Closest to" filter if enabled
      if (filters.closest) {
        // For now, we'll sort by a default distance (you may need to implement actual distance calculation)
        filtered.sort((a, b) {
          // This is a placeholder - you should implement actual distance calculation
          double distanceA = _extractDistance(a);
          double distanceB = _extractDistance(b);
          return distanceA.compareTo(distanceB);
        });
      }

      _filteredBranches = filtered;
    });
  }

  // Helper method to extract price from branch data
  double _extractPrice(Map<String, dynamic> branch) {
    if (branch['price'] != null && branch['price'] is num) {
      return (branch['price'] as num).toDouble();
    } else if (branch['averagePrice'] != null && branch['averagePrice'] is num) {
      return (branch['averagePrice'] as num).toDouble();
    }
    return 0.0;
  }

  // Helper method to extract rating from branch data
  double _extractRating(Map<String, dynamic> branch) {
    if (branch['rating'] != null && branch['rating'] is num) {
      return (branch['rating'] as num).toDouble();
    }
    return 0.0;
  }

  // Helper method to extract distance from branch data (placeholder)
  double _extractDistance(Map<String, dynamic> branch) {
    // This is a placeholder - implement actual distance calculation based on user location
    if (branch['distance'] != null && branch['distance'] is num) {
      return (branch['distance'] as num).toDouble();
    }
    // Return a random distance for now (you should implement actual distance calculation)
    return (branch['name']?.hashCode ?? 0) % 10 + 1.0;
  }

  // Helper method for case-insensitive and format-flexible category matching
  bool _matchesCategory(String actual, String expected) {
    if (actual.isEmpty || expected.isEmpty) return false;

    // Case-insensitive comparison
    final String normalizedActual = actual.toLowerCase().replaceAll('_', ' ').replaceAll('&', 'and');
    final String normalizedExpected = expected.toLowerCase().replaceAll('_', ' ').replaceAll('&', 'and');

    return normalizedActual == normalizedExpected ||
        normalizedActual.contains(normalizedExpected) ||
        normalizedExpected.contains(normalizedActual);
  }

  // Get all categories related to the specified category (bidirectional relationships)
  List<String> _getRelatedCategories(String categoryId) {
    Set<String> relatedCategories = {};

    // Add directly related categories from our map
    if (_categoryRelationships.containsKey(categoryId)) {
      relatedCategories.addAll(_categoryRelationships[categoryId]!);
    }

    // Add categories that have the current categoryId as their related category
    _categoryRelationships.forEach((category, relatedList) {
      if (relatedList.any((item) => _matchesCategory(item, categoryId))) {
        relatedCategories.add(category);
      }
    });

    return relatedCategories.toList();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  Widget _buildImages(Map<String, dynamic> branch) {
    // Check if images exist and are not empty
    List<dynamic>? images;

    if (branch.containsKey('images')) {
      // Handle different possible formats of images data
      if (branch['images'] is List) {
        images = branch['images'] as List;
      } else if (branch['images'] is String) {
        // Handle case where images might be a comma-separated string
        String imageStr = branch['images'] as String;
        if (imageStr.isNotEmpty) {
          images = imageStr.split(',');
        }
      }
    }

    // Return empty container if no images
    if (images == null || images.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('No images available', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          String imageUrl = images![index].toString();

          // Ensure URL is fully formed
          if (!imageUrl.startsWith('http') && !imageUrl.startsWith('https')) {
            // Append base URL if it's a relative path
            String baseUrl = ApiService.baseUrl;
            imageUrl = imageUrl.startsWith('/')
                ? '$baseUrl$imageUrl'
                : '$baseUrl/$imageUrl';
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                imageUrl,
                width: 160,
                height: 120,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 160,
                    height: 120,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  if (!kReleaseMode) {
                    print('Image error: $error');
                  }
                  return Container(
                    width: 160,
                    height: 120,
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, color: Colors.grey[600]),
                        SizedBox(height: 4),
                        Text(
                          'Image failed to load',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // Custom header with filter button
  Widget _buildCustomHeader() {
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
        left: 16,
        right: 16,
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 20,
      ),
      child: Column(
        children: [
          // Top row with logo, profile, notifications, menu, and filter
          Row(
            children: [
              Image.asset('assets/logo/barrim_logo.png', height: 60),
              Spacer(),
              
              // Filter button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(Icons.filter_list, color: Color(0xFF2079C2)),
                  onPressed: () {
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
                ),
              ),
              SizedBox(width: 12),
              
              // Profile avatar
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: (_profileImagePath != null && _profileImagePath!.isNotEmpty)
                      ? ClipOval(
                          child: SecureNetworkImage(
                            imageUrl: _profileImagePath!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) {
                              return const Icon(Icons.person, color: Colors.white, size: 22);
                            },
                          ),
                        )
                      : Icon(Icons.person, color: Colors.white, size: 22),
                ),
              ),
              SizedBox(width: 18),
              
              // Notifications
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsPage(),
                    ),
                  );
                },
                child: ImageIcon(
                  AssetImage('assets/icons/notification_icon.png'),
                  size: 26,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 18),
              
              // Menu button
              InkWell(
                onTap: _toggleSidebar,
                child: ImageIcon(
                  AssetImage('assets/icons/sidebar_icon.png'),
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          // Category title
          SizedBox(height: 20),
          Text(
            _getCategoryTitle(widget.categoryId),
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Filter summary
          if (_hasActiveFilters())
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getFilterSummary(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
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
          Column(
            children: [
              // Custom header with filter button
              _buildCustomHeader(),
              Expanded(
                child: _buildBody(),
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
            child: Sidebar(
              onCollapse: _toggleSidebar,
              parentContext: context,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_filteredBranches.isEmpty) {
      return Center(child: Text('No branches found for this category or related categories'));
    }

    // Get featured branches
    final featuredBranches = _getFeaturedBranches();
    
    // Get remaining branches (excluding featured ones)
    final remainingBranches = _filteredBranches.where((branch) => 
      !featuredBranches.any((featured) => featured['_id'] == branch['_id'])
    ).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Section - Take the top rated branches
          if (featuredBranches.isNotEmpty)
            CategorySection(
              title: 'Featured',
              branches: featuredBranches.map((branch) => BranchCard(
                branch: branch,
                onTap: () => _navigateToBranchDetails(branch),
              )).toList(),
            ),

          // Category filter chips
          _buildCategoryFilters(),


          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: remainingBranches.length,
            itemBuilder: (context, index) {
              return BranchCard(
                branch: remainingBranches[index],
                onTap: () => _navigateToBranchDetails(remainingBranches[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  // Build horizontal scrollable category filter chips
  Widget _buildCategoryFilters() {
    // Get related categories to the current category
    List<String> relatedCategories = _getRelatedCategories(widget.categoryId);

    // Add the current category to the front of the list
    relatedCategories.insert(0, widget.categoryId);

    // Remove duplicates
    relatedCategories = relatedCategories.toSet().toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: relatedCategories.length,
          itemBuilder: (context, index) {
            final categoryId = relatedCategories[index];
            final isSelected = categoryId == widget.categoryId;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(_getCategoryTitle(categoryId)),
                selected: isSelected,
                onSelected: (selected) {
                  if (!isSelected) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryPlaces(categoryId: categoryId),
                      ),
                    );
                  }
                },
                backgroundColor: Colors.grey[200],
                selectedColor: Colors.blue[100],
                checkmarkColor: Colors.blue,
              ),
            );
          },
        ),
      ),
    );
  }

  // Method to get featured branches (top 3 by rating)
  List<Map<String, dynamic>> _getFeaturedBranches() {
    // Create a copy of filtered branches list to avoid modifying the original
    List<Map<String, dynamic>> sortedBranches = List.from(_filteredBranches);

    // Sort by rating (highest first) if rating exists
    sortedBranches.sort((a, b) {
      double ratingA = 0.0;
      double ratingB = 0.0;

      // Try to extract rating value, default to 0 if not found
      if (a.containsKey('rating') && a['rating'] is num) {
        ratingA = (a['rating'] as num).toDouble();
      }

      if (b.containsKey('rating') && b['rating'] is num) {
        ratingB = (b['rating'] as num).toDouble();
      }

      return ratingB.compareTo(ratingA);
    });

    // Return top 3 or fewer if there aren't enough branches
    return sortedBranches.take(3).toList();
  }

  // Navigate to branch details page (placeholder for now)
  void _navigateToBranchDetails(Map<String, dynamic> branch) {
    // Navigate to branch details page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BranchDetailsPage(branch: branch),
      ),
    );
  }

  String _getCategoryTitle(String categoryId) {
    // Map category IDs to their display names
    final categoryNames = {
      'food_dining': 'Food & Dining',
      'Restaurant': 'Restaurant',
      'Cafe': 'Cafe',
      'Fast Food': 'Fast Food',
      'Bakery': 'Bakery',
      'Dessert': 'Dessert',
      'Fine & Dining': 'Fine & Dining',
      'Casual Dining': 'Casual Dining',
      'nightlife': 'Nightlife',
      'Bar': 'Bar',
      'Club': 'Club',
      'Lounge': 'Lounge',
      'Pub': 'Pub',
      'Karaoke': 'Karaoke',
      'shopping': 'Shopping',
      'Mall': 'Mall',
      'Boutique': 'Boutique',
      'Market': 'Market',
      'Department Store': 'Department Store',
      'Retail': 'Retail',
      'health': 'Health',
      'Hospital': 'Hospital',
      'Clinic': 'Clinic',
      'Pharmacy': 'Pharmacy',
      'Fitness': 'Fitness',
      'Wellness': 'Wellness',
      'services': 'Services',
      'Cleaning': 'Cleaning',
      'Repair': 'Repair',
      'Maintenance': 'Maintenance',
      'Delivery': 'Delivery',
      'Professional': 'Professional Services',
      'education': 'Education',
      'Transportation': 'Transportation',
      'Events': 'Events',
      'outdoor_activities': 'Outdoor Activities',
      'Entertainment': 'Entertainment',
      'Home_Living': 'Home & Living',
      'Beauty_Fashion': 'Beauty & Fashion',
      'Automative_Services': 'Automative Services',
      'real_state': 'Real State',
      'cultural_sites': 'Cultural Sites',
      'kids_family': 'Kids & Family',
      'pet_services': 'Pet Services',
      'financial_services': 'Financial Services',
      'tech_gadgets': 'Tech Gadgets',
      'souks_artisans': 'Souks & Artisans',
      'speciality_stores': 'Speciality Stores',
      'hospitality': 'Hospitality',
      'emergency_services': 'Emergency Services',
      'deals_promos': 'Deals & Promos',
    };

    return categoryNames[categoryId] ?? categoryId.replaceAll('_', ' ');
  }

  bool _hasActiveFilters() {
    return _filterOptions.priceSort != 'none' ||
           _filterOptions.priceRange.start != 0 ||
           _filterOptions.priceRange.end != 1000 ||
           _filterOptions.ratingSort != 'none' ||
           _filterOptions.openNow ||
           _filterOptions.closest;
  }

  String _getFilterSummary() {
    List<String> summaryParts = [];

    if (_filterOptions.priceSort != 'none') {
      summaryParts.add('Price: ${_filterOptions.priceSort}');
    }
    if (_filterOptions.priceRange.start != 0 || _filterOptions.priceRange.end != 1000) {
      summaryParts.add('Price Range: ${_filterOptions.priceRange.start.toInt()} - ${_filterOptions.priceRange.end.toInt()}');
    }
    if (_filterOptions.ratingSort != 'none') {
      summaryParts.add('Rating: ${_filterOptions.ratingSort}');
    }
    if (_filterOptions.openNow) {
      summaryParts.add('Open Now');
    }
    if (_filterOptions.closest) {
      summaryParts.add('Closest to you');
    }

    return summaryParts.join(', ');
  }
}

class CategorySection extends StatelessWidget {
  final String title;
  final List<Widget> branches;

  const CategorySection({
    super.key,
    required this.title,
    required this.branches,
  });

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return SizedBox.shrink(); // Don't show section if no branches
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...branches,
      ],
    );
  }
}

class BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  final VoidCallback onTap;

  const BranchCard({
    super.key,
    required this.branch,
    required this.onTap,
  });

  Widget _buildImages(Map<String, dynamic> branch) {
    // Check if images exist and are not empty
    List<dynamic>? images;

    if (branch.containsKey('images')) {
      // Handle different possible formats of images data
      if (branch['images'] is List) {
        images = branch['images'] as List;
      } else if (branch['images'] is String) {
        // Handle case where images might be a comma-separated string
        String imageStr = branch['images'] as String;
        if (imageStr.isNotEmpty) {
          images = imageStr.split(',');
        }
      }
    }

    // Return empty container if no images
    if (images == null || images.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('No images available', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          String imageUrl = images![index].toString();

          // Ensure URL is fully formed
          if (!imageUrl.startsWith('http') && !imageUrl.startsWith('https')) {
            // Append base URL if it's a relative path
            String baseUrl = ApiService.baseUrl;
            imageUrl = imageUrl.startsWith('/')
                ? '$baseUrl$imageUrl'
                : '$baseUrl/$imageUrl';
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                imageUrl,
                width: 160,
                height: 120,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 160,
                    height: 120,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  if (!kReleaseMode) {
                    print('Image error: $error');
                  }
                  return Container(
                    width: 160,
                    height: 120,
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, color: Colors.grey[600]),
                        SizedBox(height: 4),
                        Text(
                          'Image failed to load',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract rating from branch data or use default
    final double rating = branch['rating'] is num
        ? (branch['rating'] as num).toDouble()
        : 0.0;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branch name and rating
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      branch['name'] ?? 'Unnamed Branch',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : "N/A",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatAddress(branch['location']),
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Main Category and Subcategories as chips
              _buildCategoryChips(branch),

              SizedBox(height: 8),

              // Images
              _buildImages(branch),
            ],
          ),
        ),
      ),
    );
  }

  // New method to build category and subcategory chips
  Widget _buildCategoryChips(Map<String, dynamic> branch) {
    List<Widget> chips = [];

    // Add main category chip
    if (branch['category'] != null) {
      chips.add(
        Chip(
          label: Text(
            branch['category'].toString(),
            style: TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.blue.withOpacity(0.1),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    // Add subcategory chip (if exists)
    if (branch['subCategory'] != null && branch['subCategory'].toString().isNotEmpty) {
      chips.add(
        Chip(
          label: Text(
            branch['subCategory'].toString(),
            style: TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.green.withOpacity(0.1),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: chips,
    );
  }

  String _formatAddress(Map<String, dynamic>? location) {
    if (location == null) return 'No address provided';

    final street = location['street'] ?? '';
    final city = location['city'] ?? '';
    final country = location['country'] ?? '';

    return [street, city, country].where((part) => part.isNotEmpty).join(', ');
  }
}