import 'package:flutter/material.dart';

import '../../../../services/api_service.dart';
import '../../headers/dashboard_headers.dart';
import '../../headers/sidebar.dart';


class FilterOptions {
  final String priceSort; // 'highToLow', 'lowToHigh', or 'none'
  final RangeValues priceRange; // min and max price values
  final String ratingSort; // 'highToLow', 'lowToHigh', or 'none'
  final bool openNow;
  final bool closest;

  FilterOptions({
    required this.priceSort,
    required this.priceRange,
    required this.ratingSort,
    required this.openNow,
    required this.closest,
  });

  // Method to create a copy with some fields changed
  FilterOptions copyWith({
    String? priceSort,
    RangeValues? priceRange,
    String? ratingSort,
    bool? openNow,
    bool? closest,
  }) {
    return FilterOptions(
      priceSort: priceSort ?? this.priceSort,
      priceRange: priceRange ?? this.priceRange,
      ratingSort: ratingSort ?? this.ratingSort,
      openNow: openNow ?? this.openNow,
      closest: closest ?? this.closest,
    );
  }
}

class FiltersPage extends StatefulWidget {
  final FilterOptions initialFilters;
  final Function(FilterOptions) onApplyFilters;

  const FiltersPage({
    Key? key,
    required this.initialFilters,
    required this.onApplyFilters,
  }) : super(key: key);

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  // Variables for managing filter state
  late bool _isSidebarOpen;
  late RangeValues _priceRange;
  late String _priceSort;
  late String _ratingSort;
  late bool _openNow;
  late bool _closest;
  String? _profileImagePath;


  @override
  void initState() {
    super.initState();
    // Initialize filter values from widget parameters
    _isSidebarOpen = false;
    _priceRange = widget.initialFilters.priceRange;
    _priceSort = widget.initialFilters.priceSort;
    _ratingSort = widget.initialFilters.ratingSort;
    _openNow = widget.initialFilters.openNow;
    _closest = widget.initialFilters.closest;
    _fetchUserData();
  }

  // Create a method to gather current filter values
  FilterOptions _getCurrentFilters() {
    return FilterOptions(
      priceSort: _priceSort,
      priceRange: _priceRange,
      ratingSort: _ratingSort,
      openNow: _openNow,
      closest: _closest,
    );
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      setState(() {
        _profileImagePath = ApiService.getImageUrl(userData['profilePic']);
        print('Profile Image Path: $_profileImagePath');
      });
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              // App Header
              AppHeader(
                profileImagePath: _profileImagePath,
                onMenuTap: () {
                  setState(() {
                    _isSidebarOpen = true;
                  });
                },
              ),

              // Back Button and Title
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Color(0xFF1F4889)),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F4889),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48), // Balance the back button width
                  ],
                ),
              ),

              // Filter Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10),
                        // Sort by Text
                        Text(
                          'Sort by:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 10),

                        // Cost per Person Section
                        Text(
                          'Cost per Person:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 10),

                        // Price Sort Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildSortButton(
                                  'High to low',
                                  _priceSort == 'highToLow',
                                      () {
                                    setState(() {
                                      _priceSort = 'highToLow';
                                    });
                                  }
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _buildSortButton(
                                  'Low to High',
                                  _priceSort == 'lowToHigh',
                                      () {
                                    setState(() {
                                      _priceSort = 'lowToHigh';
                                    });
                                  }
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),

                        // Price Range Slider
                        RangeSlider(
                          activeColor: Color(0xFF2079C2),
                          inactiveColor: Colors.blue.withOpacity(0.2),
                          values: _priceRange,
                          min: 0,
                          max: 1000,
                          onChanged: (RangeValues values) {
                            setState(() {
                              _priceRange = values;
                            });
                          },
                        ),

                        // Cost Range Values
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('\$0'),
                              Text('\$1000'),
                            ],
                          ),
                        ),
                        SizedBox(height: 15),

                        // Cost Input Fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildPriceInput(_priceRange.start.round().toString()),
                            SizedBox(width: 10),
                            Container(
                              width: 20,
                              height: 2,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 10),
                            _buildPriceInput(_priceRange.end.round().toString()),
                          ],
                        ),
                        SizedBox(height: 25),

                        // Rating Section
                        Text(
                          'Rating:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 10),

                        // Rating Sort Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildSortButton(
                                  'High to low',
                                  _ratingSort == 'highToLow',
                                      () {
                                    setState(() {
                                      _ratingSort = 'highToLow';
                                    });
                                  }
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _buildSortButton(
                                  'Low to High',
                                  _ratingSort == 'lowToHigh',
                                      () {
                                    setState(() {
                                      _ratingSort = 'lowToHigh';
                                    });
                                  }
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 25),

                        // Others Section
                        Text(
                          'Others:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 10),

                        // Other Filter Options
                        Row(
                          children: [
                            Expanded(
                              child: _buildSortButton(
                                  'Open Now',
                                  _openNow,
                                      () {
                                    setState(() {
                                      _openNow = !_openNow;
                                    });
                                  }
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _buildSortButton(
                                  'Closest to',
                                  _closest,
                                      () {
                                    setState(() {
                                      _closest = !_closest;
                                    });
                                  }
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 50),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  widget.onApplyFilters(_getCurrentFilters());
                                  Navigator.pop(context);
                                  // Apply filters and go back
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF1F4889),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('Done'),
                              ),
                            ),
                            SizedBox(width: 20),
                            TextButton(
                              onPressed: () {
                                // Reset all filters
                                setState(() {
                                  _priceRange = RangeValues(0, 1000);
                                  _priceSort = "none";
                                  _ratingSort = "none";
                                  _openNow = false;
                                  _closest = false;
                                });
                              },
                              child: Text(
                                'Clear all',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Sidebar Overlay
          if (_isSidebarOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSidebarOpen = false;
                });
              },
              child: Container(
                color: Colors.black54,
              ),
            ),

          // Sidebar
          if (_isSidebarOpen)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Sidebar(
                onCollapse: () {
                  setState(() {
                    _isSidebarOpen = false;
                  });
                },
                parentContext: context,
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to build sort buttons
  Widget _buildSortButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Color(0xFF2079C2),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build price input fields
  Widget _buildPriceInput(String value) {
    return Container(
      width: 70,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          '\$$value',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }

}



