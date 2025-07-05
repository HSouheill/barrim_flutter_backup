import 'package:flutter/material.dart';
import '../../headers/dashboard_headers.dart';  // Update with actual path

enum SortOption {
  highToLow,
  lowToHigh,
  closest,
  emergency,
}

class ServiceProviderFilters {
  final List<String> selectedSkills;
  final SortOption? sortOption;
  final bool emergencyOnly;

  ServiceProviderFilters({
    this.selectedSkills = const [],
    this.sortOption,
    this.emergencyOnly = false,
  });

  // Create a copy with updated values
  ServiceProviderFilters copyWith({
    List<String>? selectedSkills,
    SortOption? sortOption,
    bool? emergencyOnly,
  }) {
    return ServiceProviderFilters(
      selectedSkills: selectedSkills ?? this.selectedSkills,
      sortOption: sortOption ?? this.sortOption,
      emergencyOnly: emergencyOnly ?? this.emergencyOnly,
    );
  }

  // Add toJson method for debugging
  Map<String, dynamic> toJson() {
    return {
      'selectedSkills': selectedSkills,
      'sortOption': sortOption?.toString(),
      'emergencyOnly': emergencyOnly,
    };
  }
}

class FilterPage extends StatefulWidget {
  final ServiceProviderFilters initialFilters;
  final Function(ServiceProviderFilters) onApplyFilters;

  const FilterPage({
    Key? key,
    required this.initialFilters,
    required this.onApplyFilters,
  }) : super(key: key);

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  late ServiceProviderFilters _filters;

  // All available skills
  final List<String> _availableSkills = [
    'Driver',
    'Guide',
    'Cleaning',
    'Maintenance',
    'Security',
    'Transportation',
    'IT Services',
    'Consulting',
    'Education',
    'Healthcare',
    'Legal Services',
    'Financial Services',
    'Real Estate',
    'Event Planning',
    'Marketing',
    'Construction',
    'Repair Services'
  ];

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  // Toggle skill selection
  void _toggleSkill(String skill) {
    setState(() {
      if (_filters.selectedSkills.contains(skill)) {
        _filters = _filters.copyWith(
          selectedSkills: _filters.selectedSkills.where((s) => s != skill).toList(),
        );
      } else {
        _filters = _filters.copyWith(
          selectedSkills: [..._filters.selectedSkills, skill],
        );
      }
    });
  }

  // Set sort option
  void _setSortOption(SortOption option) {
    setState(() {
      _filters = _filters.copyWith(sortOption: option);
    });
  }

  // Toggle emergency only
  void _toggleEmergency() {
    setState(() {
      _filters = _filters.copyWith(emergencyOnly: !_filters.emergencyOnly);
    });
  }

  // Clear all filters
  void _clearAll() {
    setState(() {
      _filters = ServiceProviderFilters();
    });
  }

  // Apply filters and return to previous screen
  void _applyFilters() {
    widget.onApplyFilters(_filters);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // App Header
          AppHeader(
            onMenuTap: () {
              Navigator.of(context).pop();
            },
          ),

          // Back button and title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Color(0xFF2079C2)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2079C2),
                  ),
                ),
              ],
            ),
          ),

          // Filter options
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skills section
                  Text(
                    'Skills:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSkills.map((skill) => _buildFilterChip(
                      label: skill,
                      isSelected: _filters.selectedSkills.contains(skill),
                      onTap: () => _toggleSkill(skill),
                    )).toList(),
                  ),

                  SizedBox(height: 24),

                  // Rating section
                  Text(
                    'Sort by:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterChip(
                          label: 'High to Low',
                          isSelected: _filters.sortOption == SortOption.highToLow,
                          onTap: () => _setSortOption(SortOption.highToLow),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip(
                          label: 'Low to High',
                          isSelected: _filters.sortOption == SortOption.lowToHigh,
                          onTap: () => _setSortOption(SortOption.lowToHigh),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Others section
                  Text(
                    'Others:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterChip(
                          label: 'Closest to',
                          isSelected: _filters.sortOption == SortOption.closest,
                          onTap: () => _setSortOption(SortOption.closest),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip(
                          label: 'Emergency',
                          isSelected: _filters.emergencyOnly,
                          onTap: _toggleEmergency,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2079C2),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                TextButton(
                  onPressed: _clearAll,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
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

  // Helper method to create filter chips
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF2079C2).withOpacity(0.2) : Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? Border.all(color: Color(0xFF2079C2)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Color(0xFF2079C2) : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}