import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../../../../services/api_service.dart';
import '../../headers/company_header.dart';
import 'company_review.dart';

class BranchesPage extends StatefulWidget {
  final String token;
  final List<dynamic> initialBranches;
    final Map<String, dynamic> userData; // <-- Add this line


  const BranchesPage({
    Key? key,
    required this.token,
    required this.initialBranches,
      required this.userData, // <-- Add this line

  }) : super(key: key);

  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> {
  List<dynamic> branches = [];
  bool isLoading = true;
  String? errorMessage;
  String? logoUrl;

@override
void initState() {
  super.initState();
  print('BranchesPage token: ${widget.token}');
  branches = widget.initialBranches;
  _loadCompanyData();
  _fetchBranches(); 
}

  Future<void> _loadCompanyData() async {
    try {
      var data = await ApiService.getCompanyData(widget.token);
      if (data['companyInfo'] != null) {
        setState(() {
          logoUrl = data['companyInfo']['logo'];
        });
      }
    } catch (error) {
      print('Error loading company data: $error');
    }
  }

  Future<void> _fetchBranches() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Use the provided token or get from SharedPreferences
      final token = widget.token;

      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Authentication token not found. Please login again.';
        });
        return;
      }

      // Fetch branches from API
      final fetchedBranches = await ApiService.getCompanyBranches(token);

      setState(() {
        branches = fetchedBranches;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = kReleaseMode ? 'Failed to load branches.' : 'Failed to load branches: ${e.toString()}';
      });
    }
  }

  // Helper to build the image URL
  String getImageUrl(String imagePath) {
    // Check if the image path is already a full URL
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // Handle relative paths - assuming images are stored in "uploads" folder on backend
    return '${ApiService.baseUrl}/$imagePath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Company header
        CompanyAppHeader(
          logoUrl: logoUrl,
          userData: widget.userData,
        ),
          // Branches title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.blue, width: 2.0),
              ),
            ),
            child: const Center(
              child: Text(
                'Branches',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),

          // Branches list or loading indicator
          Expanded(
            child: _buildBranchesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add branch page
          // Navigator.push(context, MaterialPageRoute(builder: (context) => AddBranchPage()));
        },
        backgroundColor: const Color(0xFF2079C2),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBranchesList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchBranches,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (branches.isEmpty) {
      return const Center(
        child: Text('No branches found. Add your first branch!'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: branches.length,
      itemBuilder: (context, index) {
        final branch = branches[index];

        // Fixed: Properly handle the images array, which should be a list of strings
        List<String> branchImages = [];
        if (branch['images'] != null) {
          // Convert each item in the images array to a string
          branchImages = (branch['images'] as List).map((img) => img.toString()).toList();
        }

        final String firstImage = branchImages.isNotEmpty
            ? getImageUrl(branchImages.first)
            : 'assets/placeholder.png';

        // Safely extract location which is a nested object
        String locationText = 'Unknown Location';
        if (branch['location'] != null) {
          final location = branch['location'];
          if (location is Map) {
            final city = location['city']?.toString() ?? '';
            final street = location['street']?.toString() ?? '';
            locationText = city.isNotEmpty || street.isNotEmpty
                ? '$street, $city'.trim().replaceAll(RegExp(r', $'), '')
                : 'Unknown Location';
          }
        }

        return
          GestureDetector(
            // In your branches.dart file, update the onTap handler:
            onTap: () {
              final branchId = branch['id']?.toString(); // Make sure this matches your API's expected ID field
              if (branchId == null || branchId.isEmpty) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('Invalid branch ID')),
                // );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CompanyReviewsPage(
                    branchId: branchId,
                    branchName: branch['name']?.toString() ?? 'Branch',
                    userData: widget.userData,
                    logoUrl: logoUrl,
                  ),
                ),
              );
            },
        child:Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branch image with location overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    child: Image.network(
                      firstImage,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 50),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      color: Colors.black.withOpacity(0.7),
                      child: Text(
                        locationText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Image navigation dots
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        branchImages.length > 0 ? branchImages.length : 1,
                            (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == 0 ? Colors.white : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Branch details
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch['name']?.toString() ?? 'Unnamed Branch',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      branch['description']?.toString() ?? 'No description available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Star rating - handle numeric rating safely
                        ...List.generate(
                          5,
                              (i) {
                            // Safely convert rate to int
                            int rating = 0;
                            if (branch['rate'] != null) {
                              rating = (branch['rate'] is num)
                                  ? (branch['rate'] as num).floor()
                                  : int.tryParse(branch['rate'].toString()) ?? 0;
                            }
                            return Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // Reviews count - convert to string safely
                        Text(
                          '${branch['reviewsCount']?.toString() ?? '0'} Reviews',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      );
      },
    );
  }
}