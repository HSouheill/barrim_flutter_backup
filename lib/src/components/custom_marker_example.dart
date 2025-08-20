import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import '../utils/custom_marker_creator.dart';

class CustomMarkerExample extends StatefulWidget {
  const CustomMarkerExample({Key? key}) : super(key: key);

  @override
  State<CustomMarkerExample> createState() => _CustomMarkerExampleState();
}

class _CustomMarkerExampleState extends State<CustomMarkerExample> {
  List<google_maps.Marker> _markers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _createCustomMarkers();
  }

  Future<void> _createCustomMarkers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Create different types of custom markers
      final List<google_maps.Marker> markers = [];

      // 1. Simple colored marker with icon
      final restaurantMarker = await CustomMarkerCreator.createCustomMarker(
        backgroundColor: Colors.red,
        iconPath: 'assets/icons/restaurant.png',
        iconColor: Colors.white,
        size: 80.0,
        borderColor: Colors.white,
        borderWidth: 2.0,
      );

      markers.add(
        google_maps.Marker(
          markerId: google_maps.MarkerId('restaurant'),
          position: google_maps.LatLng(33.8938, 35.5018), // Beirut
          icon: restaurantMarker,
          infoWindow: google_maps.InfoWindow(title: 'Restaurant'),
        ),
      );

      // 2. Category-based marker
      final hotelMarker = await CustomMarkerCreator.createCategoryMarker(
        categoryName: 'Hotel',
        categoryColor: Colors.blue,
        categoryIconPath: 'assets/icons/hotel.png',
        size: 80.0,
      );

      markers.add(
        google_maps.Marker(
          markerId: google_maps.MarkerId('hotel'),
          position: google_maps.LatLng(33.9038, 35.5118), // Near Beirut
          icon: hotelMarker,
          infoWindow: google_maps.InfoWindow(title: 'Hotel'),
        ),
      );

      // 3. Business marker with brand colors
      final businessMarker = await CustomMarkerCreator.createBusinessMarker(
        brandColor: Colors.green,
        logoPath: 'assets/icons/business.png',
        size: 80.0,
      );

      markers.add(
        google_maps.Marker(
          markerId: google_maps.MarkerId('business'),
          position: google_maps.LatLng(33.8838, 35.4918), // Near Beirut
          icon: businessMarker,
          infoWindow: google_maps.InfoWindow(title: 'Business'),
        ),
      );

      // 4. Location marker with IconData
      final locationMarker = await CustomMarkerCreator.createLocationMarker(
        markerColor: Colors.orange,
        icon: Icons.local_gas_station,
        iconColor: Colors.white,
        size: 80.0,
      );

      markers.add(
        google_maps.Marker(
          markerId: google_maps.MarkerId('gas_station'),
          position: google_maps.LatLng(33.9138, 35.5218), // Near Beirut
          icon: locationMarker,
          infoWindow: google_maps.InfoWindow(title: 'Gas Station'),
        ),
      );

      // 5. Custom colored marker without icon
      final customColoredMarker = await CustomMarkerCreator.createCustomMarker(
        backgroundColor: Colors.purple,
        size: 80.0,
        borderColor: Colors.white,
        borderWidth: 3.0,
      );

      markers.add(
        google_maps.Marker(
          markerId: google_maps.MarkerId('custom'),
          position: google_maps.LatLng(33.8738, 35.4818), // Near Beirut
          icon: customColoredMarker,
          infoWindow: google_maps.InfoWindow(title: 'Custom Marker'),
        ),
      );

      setState(() {
        _markers = markers;
        _isLoading = false;
      });

      // Print cache statistics
      print('Marker cache stats: ${CustomMarkerCreator.getCacheStats()}');

    } catch (e) {
      print('Error creating custom markers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Custom Marker Examples'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _createCustomMarkers,
          ),
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: () {
              CustomMarkerCreator.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Marker cache cleared')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating custom markers...'),
                ],
              ),
            )
          : Column(
              children: [
                // Marker legend
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Markers Created:',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 8),
                      _buildMarkerLegend(),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: google_maps.GoogleMap(
                        initialCameraPosition: google_maps.CameraPosition(
                          target: google_maps.LatLng(33.8938, 35.5018), // Beirut
                          zoom: 12.0,
                        ),
                        markers: Set<google_maps.Marker>.from(_markers),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMarkerLegend() {
    return Column(
      children: [
        _buildLegendItem('Restaurant', Colors.red, Icons.restaurant),
        _buildLegendItem('Hotel', Colors.blue, Icons.hotel),
        _buildLegendItem('Business', Colors.green, Icons.business),
        _buildLegendItem('Gas Station', Colors.orange, Icons.local_gas_station),
        _buildLegendItem('Custom', Colors.purple, Icons.place),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
          SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
