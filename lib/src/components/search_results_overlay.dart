import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class SearchResultsOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> searchResults;
  final Function(Map<String, dynamic>) onResultTap;
  final Function() onClose;
  static const String baseUrl = ApiService.baseUrl;

  const SearchResultsOverlay({
    Key? key,
    required this.searchResults,
    required this.onResultTap,
    required this.onClose,
  }) : super(key: key);

  Widget _buildImageWidget(Map<String, dynamic> place) {
    try {
      if (place['images'] != null &&
          place['images'] is List &&
          (place['images'] as List).isNotEmpty) {
        // Extract the image path and ensure it's a string
        var imagePath = (place['images'] as List)[0];
        String imagePathString = imagePath.toString();

        // Check if the image path is already a full URL
        if (imagePathString.startsWith('http')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SecureNetworkImage(
              imageUrl: imagePathString,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => _buildCategoryIcon(place),
            ),
          );
        } else {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SecureNetworkImage(
              imageUrl: '$baseUrl/$imagePathString',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => _buildCategoryIcon(place),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading image: $e');
      // Fall through to category icon on any error
    }
    return _buildCategoryIcon(place);
  }

  Widget _buildCategoryIcon(Map<String, dynamic> place) {
    final category = place['category']?.toString().toLowerCase() ?? '';
    final type = place['type']?.toString().toLowerCase() ?? '';
    
    // Check for restaurant categories
    if (_isRestaurantCategory(category) || _isRestaurantCategory(type)) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.restaurant,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    }
    
    // Check for hotel categories
    if (_isHotelCategory(category) || _isHotelCategory(type)) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.hotel,
            color: Colors.blue,
            size: 40,
          ),
        ),
      );
    }
    
    // Check for wholesaler
    if (type == 'wholesaler' || category.contains('wholesaler')) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.store,
            color: Colors.green,
            size: 40,
          ),
        ),
      );
    }
    
    // Default business icon
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.business,
          color: Colors.grey[600],
          size: 40,
        ),
      ),
    );
  }

  // Helper method to check if a category is restaurant-related
  bool _isRestaurantCategory(String category) {
    if (category.isEmpty) return false;
    
    final categoryLower = category.toLowerCase().trim();
    
    // Check for various restaurant-related category values
    return categoryLower == 'restaurant' ||
           categoryLower == 'food_dining' ||
           categoryLower == 'food & dining' ||
           categoryLower == 'food and dining' ||
           categoryLower == 'dining' ||
           categoryLower == 'cafe' ||
           categoryLower == 'fast food' ||
           categoryLower == 'fine dining' ||
           categoryLower == 'casual dining' ||
           categoryLower == 'bistro' ||
           categoryLower == 'bakery' ||
           categoryLower == 'dessert';
  }

  // Helper method to check if a category is hotel-related
  bool _isHotelCategory(String category) {
    if (category.isEmpty) return false;
    
    final categoryLower = category.toLowerCase().trim();
    
    // Check for various hotel-related category values
    return categoryLower == 'hotel' ||
           categoryLower == 'hotels' ||
           categoryLower == 'hospitality' ||
           categoryLower == 'accommodation' ||
           categoryLower == 'lodging' ||
           categoryLower == 'resort' ||
           categoryLower == 'motel' ||
           categoryLower == 'inn' ||
           categoryLower == 'guesthouse' ||
           categoryLower == 'bed and breakfast' ||
           categoryLower == 'bnb';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 120, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: 350,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: searchResults.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final place = searchResults[index];
                final distance = place['distance'] != null
                    ? place['distance'] < 1
                    ? '(${(place['distance'] * 60).round()} min away)'
                    : '(${place['distance'].round()} hr away)'
                    : '';
                final price = place['price'] ?? '';
                final category = place['category'] ?? 'Unknown';

                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 80,
                    height: 80,
                    child: _buildImageWidget(place),
                  ),
                  title: Text(
                    place['name'] ?? 'Unknown Place',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place['address'] ?? '',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                                (i) => Icon(
                              i < (place['rating'] ?? 4) ? Icons.star : Icons.star_border,
                              color: Colors.blue,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (price.isNotEmpty)
                        Text(
                          '\$$price',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      Text(
                        distance,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        category,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => onResultTap(place),
                );
              },
            ),
          ),
          Divider(height: 1),
          TextButton(
            onPressed: onClose,
            child: Text(
              'Close',
              style: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}