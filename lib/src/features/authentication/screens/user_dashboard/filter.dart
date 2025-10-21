import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/api_service.dart';
import '../../headers/dashboard_headers.dart';
import '../../headers/sidebar.dart';
import '../responsive_utils.dart';
import '../settings/settings.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({Key? key}) : super(key: key);

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  // Selected filter values
  String? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedDistance;
  String _selectedSortBy = 'Most Popular';
  String? _profileImagePath;

  // Dynamic categories that will be loaded from backend
  Map<String, List<String>> _categoryOptionsMap = {};
  bool _isLoadingCategories = true;
  String? _categoriesError;

  final List<String> _distanceOptions = [
    '500 m', '1 km', '2 km', '5 km', '10 km', '20 km', '50 km', '100 km', 'Custom...'
  ];
  final List<String> _sortByOptions = [
    'Closest',
    'Most Popular',
    'Most Recent',
    'Highest Rated',
    'Most Reviews'
  ];

  // Flag to track if sidebar is open
  bool _isSidebarOpen = false;

  // Add new state variables
  List<String> _currentSubCategoryOptions = ['All'];
  String? _customDistanceValue;

  void _handleNotificationTap() {
    // Implement notification tap logic
    print('Notification tapped');
  }

  // Toggle sidebar visibility
  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _updateSubCategoryOptions(String? category) {
    setState(() {
      if (category != null && category != 'All') {
        _currentSubCategoryOptions = _categoryOptionsMap[category] ?? ['All'];
      } else {
        _currentSubCategoryOptions = ['All'];
      }
      _selectedSubCategory = null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedSubCategory = null;
      _selectedDistance = null;
      _selectedSortBy = 'Most Popular';
      _currentSubCategoryOptions = ['All'];
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData != null && userData['profilePic'] != null) {
        setState(() {
          // Use the static getImageUrl method from ApiService
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

      final categories = await ApiService.getAllCategories();
      
      if (mounted) {
        // Add 'All' option to each category's subcategories
        final Map<String, List<String>> categoriesWithAll = {};
        categories.forEach((key, value) {
          categoriesWithAll[key] = ['All', ...value];
        });
        
        setState(() {
          _categoryOptionsMap = categoriesWithAll;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _categoriesError = 'Failed to load categories: $e';
          // Fallback to default categories if backend fails
          _categoryOptionsMap = {
            'Hotels': ['All', 'Luxury', 'Budget', 'Resort', 'Boutique', 'Business'],
            'Restaurant': ['All', 'Fast Food', 'Fine Dining', 'Casual Dining', 'Café', 'Bistro'],
            'Technology': ['All', 'Software', 'Hardware', 'IT Services', 'Telecommunications', 'E-commerce'],
            'Shops': ['All', 'Retail', 'Department Store', 'Specialty', 'Convenience', 'Online'],
            'Stations': ['All', 'Gas', 'Train', 'Bus', 'Electric Charging', 'Metro'],
            'Finance': ['All', 'Banking', 'Insurance', 'Investment', 'Accounting', 'Fintech'],
            'Food & Beverage': ['All', 'Bakery', 'Beverage', 'Catering', 'Grocery', 'Specialty Food'],
            'Real Estate': ['All', 'Residential', 'Commercial', 'Industrial', 'Property Management', 'Development'],
            'Other': ['All', 'Education', 'Healthcare', 'Entertainment', 'Transportation', 'Miscellaneous'],
          };
        });
      }
    }
  }

  // Helper method to get responsive padding
  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return 16.0; // Mobile
    } else if (screenWidth < 1200) {
      return 24.0; // Tablet
    } else {
      return 32.0; // Desktop
    }
  }

  // Helper method to get responsive sidebar width
  double _getSidebarWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return screenWidth * 0.45; // 80% of screen width on mobile
    } else if (screenWidth < 1200) {
      return 300.0; // Fixed width on tablet
    } else {
      return 350.0; // Larger fixed width on desktop
    }
  }

  // Helper method to determine layout orientation
  bool _isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 900;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    final parentContext = context;
    final isWideScreen = _isWideScreen(context);
    final responsivePadding = _getResponsivePadding(context);
    final sidebarWidth = _getSidebarWidth(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Use AppHeader with menu tap handler
              AppHeader(
                profileImagePath: _profileImagePath,
                onNotificationTap: _handleNotificationTap,
                onProfileTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(),
                    ),
                  );
                },
                // onMenuTap: _toggleSidebar,
              ),

              // Back button and Title
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: responsivePadding,
                  vertical: 8,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Color(0xFF0094FF)),
                        onPressed: () => Navigator.of(context).pop(),
                        iconSize: ResponsiveUtils.getIconSize(context),
                      ),
                    ),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleFontSize(context),
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0094FF),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Content
              Expanded(
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: isWideScreen ? 800 : double.infinity,
                  ),
                  margin: isWideScreen 
                      ? EdgeInsets.symmetric(horizontal: responsivePadding)
                      : EdgeInsets.zero,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(responsivePadding),
                    child: isWideScreen
                        ? _buildWideScreenLayout(context)
                        : _buildMobileLayout(context),
                  ),
                ),
              ),
            ],
          ),

          // Conditionally show the sidebar
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _isSidebarOpen ? 0 : -sidebarWidth,
            top: 0,
            bottom: 0,
            width: sidebarWidth,
            child: Container(
              
              child: Sidebar(
                onCollapse: _toggleSidebar,
                parentContext: parentContext,
              ),
            ),
          ),

          // Overlay when sidebar is open
          if (_isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: Container(
                  color: Colors.black.withOpacity(0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Wide screen layout (tablets and desktop)
  Widget _buildWideScreenLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter options in a grid layout
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Options',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0094FF),
                ),
              ),
              SizedBox(height: 24),
              
              // First row: Type and Category
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownSection(
                      'Type',
                      _categoryOptionsMap.keys.toList(),
                      _selectedCategory,
                      (value) {
                        setState(() {
                          _selectedCategory = value;
                          _updateSubCategoryOptions(value);
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 24),
                  Expanded(
                    child: _buildDropdownSection(
                      'Subcategory',
                      _currentSubCategoryOptions,
                      _selectedSubCategory,
                      (value) {
                        setState(() => _selectedSubCategory = value);
                      },
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Second row: Distance
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownSection(
                      'Distance',
                      _distanceOptions,
                      _selectedDistance,
                      (value) {
                        setState(() => _selectedDistance = value);
                      },
                    ),
                  ),
                  SizedBox(width: 24),
                  Expanded(child: Container()), // Empty space
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Sort by section
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort by:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0094FF),
                ),
              ),
              SizedBox(height: 16),
              _buildSortOptions(context),
            ],
          ),
        ),

        SizedBox(height: 32),

        // Action buttons
        _buildActionButtons(context),
      ],
    );
  }

  // Mobile layout
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Dropdown (was Type)
        _buildDropdownSection(
          'Category',
          _categoryOptionsMap.keys.toList(),
          _selectedCategory,
          (value) {
            setState(() {
              _selectedCategory = value;
              _updateSubCategoryOptions(value);
            });
          },
        ),

        // Subcategory Dropdown (was Category)
        _buildDropdownSection(
          'Subcategory',
          _currentSubCategoryOptions,
          _selectedSubCategory,
          (value) {
            setState(() => _selectedSubCategory = value);
          },
        ),

        // Distance Dropdown
        _buildDropdownSection(
          'Distance',
          _distanceOptions,
          _selectedDistance,
          (value) {
            setState(() => _selectedDistance = value);
          },
        ),

        // Sort By Section
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            'Sort by:',
            style: TextStyle(
              fontSize: ResponsiveUtils.getInputLabelFontSize(context) * 0.9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0094FF),
            ),
          ),
        ),

        _buildSortOptions(context),

        SizedBox(height: 32),

        // Action buttons
        _buildActionButtons(context),
      ],
    );
  }

  // Build sort options chips
  Widget _buildSortOptions(BuildContext context) {
    final isWideScreen = _isWideScreen(context);
    
    if (isWideScreen) {
      return Row(
        children: _sortByOptions.map((option) {
          bool isSelected = _selectedSortBy == option;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildSortChip(context, option, isSelected),
          );
        }).toList(),
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _sortByOptions.map((option) {
          bool isSelected = _selectedSortBy == option;
          return _buildSortChip(context, option, isSelected);
        }).toList(),
      );
    }
  }

  // Build individual sort chip
  Widget _buildSortChip(BuildContext context, String option, bool isSelected) {
    return FilterChip(
      label: Text(
        option,
        style: TextStyle(
          fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.9,
          color: isSelected ? Colors.white : Color(0xFF0094FF),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: Color(0xFF0094FF),
      backgroundColor: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: Color(0xFF0094FF),
          width: isSelected ? 2 : 1,
        ),
      ),
      onSelected: (selected) {
        setState(() => _selectedSortBy = option);
      },
      showCheckmark: false,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  // Build action buttons
  Widget _buildActionButtons(BuildContext context) {
    final isWideScreen = _isWideScreen(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16),
      child: isWideScreen
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDoneButton(context),
                SizedBox(width: 24),
                _buildClearButton(context),
              ],
            )
          : Column(
              children: [
                _buildDoneButton(context),
                SizedBox(height: 16),
                _buildClearButton(context),
              ],
            ),
    );
  }

  // Build done button
  Widget _buildDoneButton(BuildContext context) {
    final isWideScreen = _isWideScreen(context);
    
    return Container(
      width: isWideScreen ? 150 : double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0094FF),
            Color(0xFF05055A),
            Color(0xFF0094FF),
          ],
          stops: [0, 0.5, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0094FF).withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          String? distanceToSend = _selectedDistance;
          if (_selectedDistance == 'Custom...' && _customDistanceValue != null && _customDistanceValue!.isNotEmpty) {
            distanceToSend = _customDistanceValue! + ' km';
          }
          Navigator.of(context).pop({
            'category': _selectedCategory,
            'subcategory': _selectedSubCategory,
            'distance': distanceToSend,
            'sortBy': _selectedSortBy,
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          'Apply Filters',
          style: TextStyle(
            fontSize: ResponsiveUtils.getButtonFontSize(context),
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Build clear button
  Widget _buildClearButton(BuildContext context) {
    final isWideScreen = _isWideScreen(context);
    
    return Container(
      width: isWideScreen ? 150 : double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Color(0xFF0094FF), width: 2),
        color: Colors.white,
      ),
      child: TextButton(
        onPressed: _clearAllFilters,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          'Clear All',
          style: TextStyle(
            color: Color(0xFF0094FF),
            fontSize: ResponsiveUtils.getButtonFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSection(
    String title,
    List<String> options,
    String? selectedValue,
    Function(String?) onChanged,
  ) {
    // Special handling for Distance dropdown to allow custom value
    if (title == 'Distance') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                fontWeight: FontWeight.bold,
                color: Color(0xFF0094FF),
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF0094FF).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: selectedValue,
                onChanged: (value) {
                  if (value == 'Custom...') {
                    setState(() {
                      _selectedDistance = value;
                    });
                  } else {
                    setState(() {
                      _selectedDistance = value;
                      _customDistanceValue = null;
                    });
                  }
                  onChanged(value);
                },
                isExpanded: true,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: ResponsiveUtils.getInputTextFontSize(context),
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF0094FF),
                  size: 24,
                ),
                hint: Text(
                  'Select $title',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: ResponsiveUtils.getInputTextFontSize(context),
                  ),
                ),
                items: options.toSet().map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: ResponsiveUtils.getInputTextFontSize(context),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_selectedDistance == 'Custom...')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextFormField(
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Enter custom distance (km)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _customDistanceValue = value;
                    });
                  },
                ),
              ),
          ],
        ),
      );
    }

    // Special handling for category dropdowns to show loading states
    if (title == 'Type' || title == 'Category') {
      if (_isLoadingCategories) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0094FF),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF0094FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0094FF),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Loading categories...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: ResponsiveUtils.getInputTextFontSize(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      if (_categoriesError != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0094FF),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using fallback categories',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.9,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadCategories,
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          color: Color(0xFF0094FF),
                          fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.8,
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

      if (options.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0094FF),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Text(
                  'No categories available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: ResponsiveUtils.getInputTextFontSize(context),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveUtils.getInputLabelFontSize(context),
              fontWeight: FontWeight.bold,
              color: Color(0xFF0094FF),
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF0094FF).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: selectedValue,
              onChanged: onChanged,
              isExpanded: true,
              style: TextStyle(
                color: Colors.black,
                fontSize: ResponsiveUtils.getInputTextFontSize(context),
              ),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF0094FF),
                size: 24,
              ),
              hint: Text(
                'Select $title',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: ResponsiveUtils.getInputTextFontSize(context),
                ),
              ),
              items: options.toSet().map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(
                    option,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: ResponsiveUtils.getInputTextFontSize(context),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}