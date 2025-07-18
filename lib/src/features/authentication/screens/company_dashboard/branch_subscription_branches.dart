import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../headers/company_header.dart';
import 'subscription/company_subscription.dart';

class BranchSubscriptionBranchesPage extends StatefulWidget {
  final String token;
  final List<dynamic> initialBranches;
  final Map<String, dynamic> userData;
  final String? logoUrl;

  const BranchSubscriptionBranchesPage({
    Key? key,
    required this.token,
    required this.initialBranches,
    required this.userData,
    this.logoUrl,
  }) : super(key: key);

  @override
  State<BranchSubscriptionBranchesPage> createState() => _BranchSubscriptionBranchesPageState();
}

class _BranchSubscriptionBranchesPageState extends State<BranchSubscriptionBranchesPage> {
  List<dynamic> branches = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    branches = widget.initialBranches;
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      final token = widget.token;
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Authentication token not found. Please login again.';
        });
        return;
      }
      final fetchedBranches = await ApiService.getCompanyBranches(token);
      setState(() {
        branches = fetchedBranches;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load branches: ${e.toString()}';
      });
    }
  }

  String getImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    return '${ApiService.baseUrl}/$imagePath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CompanyAppHeader(
            logoUrl: widget.logoUrl,
            userData: widget.userData,
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.blue, width: 2.0),
              ),
            ),
            child: const Center(
              child: Text(
                'Select Branch for Subscription',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildBranchesList(),
          ),
        ],
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
        List<String> branchImages = [];
        if (branch['images'] != null) {
          branchImages = (branch['images'] as List).map((img) => img.toString()).toList();
        }
        print('Branch $index images: ${branch['images']}');
        final String firstImage = branchImages.isNotEmpty
            ? getImageUrl(branchImages.first)
            : 'assets/placeholder.png';
        print('Branch $index firstImage URL: $firstImage');
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
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanySubscriptionsPage(
                  userData: widget.userData,
                  logoUrl: widget.logoUrl,
                  branchId: branch['id']?.toString() ?? branch['_id']?.toString(),
                ),
              ),
            );
          },
          child: Container(
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
                  ],
                ),
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