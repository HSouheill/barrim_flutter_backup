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
              errorWidget: (context, url, error) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: Center(child: Icon(Icons.error_outline, color: Colors.grey[600])),
              ),
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
              errorWidget: (context, url, error) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: Center(child: Icon(Icons.error_outline, color: Colors.grey[600])),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading image: $e');
      // Fall through to default image on any error
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/company_placeholder.png',
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      ),
    );
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
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place['address'] ?? ''),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                                (i) => Icon(
                              i < (place['rating'] ?? 4) ? Icons.star : Icons.star_border,
                              color: Colors.blue,
                              size: 18,
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
                          ),
                        ),
                      Text(
                        distance,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        category,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
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
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}