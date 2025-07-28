import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_branches.dart';
import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_dashboard2.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../services/api_service.dart';
import '../../../../services/wholesaler_service.dart';
import '../../headers/wholesaler_header.dart';
import 'addwholesaler_branch.dart';
import '../login_page.dart';
import 'package:flutter/foundation.dart';

class WholesalerDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const WholesalerDashboard({Key? key, required this.userData}) : super(key: key);

  @override
  State<WholesalerDashboard> createState() => _WholesalerDashboardState();
}

class _WholesalerDashboardState extends State<WholesalerDashboard> {
  String? industryType;
  String? subCategory;
  List<dynamic> branches = [];
  bool isLoading = true;
  bool isRefreshing = false;

  // Create an instance of WholesalerService
  final WholesalerService _wholesalerService = WholesalerService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load data in parallel for better performance
      await Future.wait([
        _loadWholesalerData(),
        _loadBranches(),
      ]);
    } catch (error) {
      print('Error initializing data: $error');
      // Try to load from cache if API fails
      await _loadDataFromCache();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Pull-to-refresh functionality
  Future<void> _refreshData() async {
    setState(() {
      isRefreshing = true;
    });

    try {
      await Future.wait([
        _loadWholesalerData(),
        _loadBranches(forceRefresh: true),
      ]);
    } catch (error) {
      print('Error refreshing data: $error');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to refresh data. Please try again.')),
      // );
    } finally {
      setState(() {
        isRefreshing = false;
      });
    }
  }

  Future<void> _loadWholesalerData() async {
    try {
      // 1. Fetch wholesaler data from the service
      final wholesalerData = await _wholesalerService.getWholesalerData();

      if (wholesalerData != null) {
        // 2. Update state with wholesaler data
        setState(() {
          industryType = wholesalerData.category ?? 'Not Available';
          subCategory = wholesalerData.subCategory ?? 'Not Available';

          // Update contact info in userData
          if (wholesalerData.contactInfo != null) {
            widget.userData['phone'] = wholesalerData.phone;
            widget.userData['whatsapp'] = wholesalerData.contactInfo.whatsApp;
            widget.userData['website'] = wholesalerData.contactInfo.website;
            widget.userData['facebook'] = wholesalerData.contactInfo.facebook;
          }

          // Update social media in userData
          if (wholesalerData.socialMedia != null) {
            widget.userData['facebook'] = wholesalerData.socialMedia.facebook;
            widget.userData['instagram'] = wholesalerData.socialMedia.instagram;
          }

          // Store logo URL in userData - convert to full URL if it's a relative path
          String? logoUrl = wholesalerData.logoUrl;
          if (logoUrl != null && logoUrl.isNotEmpty) {
            // If it's a relative path, convert to full URL
            if (logoUrl.startsWith('/') || logoUrl.startsWith('uploads/')) {
              logoUrl = '${ApiService.baseUrl}/$logoUrl';
            }
            // If it starts with file://, remove it and convert to full URL
            else if (logoUrl.startsWith('file://')) {
              logoUrl = logoUrl.replaceFirst('file://', '');
              if (logoUrl.startsWith('/')) {
                logoUrl = '${ApiService.baseUrl}$logoUrl';
              } else {
                logoUrl = '${ApiService.baseUrl}/$logoUrl';
              }
            }
          }
          widget.userData['logoUrl'] = logoUrl;
        });

        // Save to shared preferences
        await _saveContactDataToPrefs();
      }
    } catch (error) {
      print('Error loading wholesaler data: $error');
      throw error; // Let the caller handle the error
    }
  }

  Future<void> _saveContactDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_contact_data', json.encode({
      'phone': widget.userData['phone'],
      'whatsapp': widget.userData['whatsapp'],
      'website': widget.userData['website'],
      'facebook': widget.userData['facebook'],
      'instagram': widget.userData['instagram'],
    }));
  }

  Future<void> _loadDataFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('company_data');
    final savedContactData = prefs.getString('company_contact_data');
    final savedBranches = prefs.getString('branches_data');

    if (savedData != null) {
      final parsedData = json.decode(savedData);
      setState(() {
        if (parsedData['companyInfo'] != null) {
          industryType = parsedData['companyInfo']['category'] ?? 'Not Available';
          subCategory = parsedData['companyInfo']['subCategory'] ?? 'Not Available';
        }
      });
    }

    if (savedContactData != null) {
      final contactData = json.decode(savedContactData);
      setState(() {
        widget.userData['phone'] = contactData['phone'] ?? widget.userData['phone'];
        widget.userData['whatsapp'] = contactData['whatsapp'] ?? widget.userData['whatsapp'];
        widget.userData['website'] = contactData['website'] ?? widget.userData['website'];
        widget.userData['facebook'] = contactData['facebook'] ?? widget.userData['facebook'];
        widget.userData['instagram'] = contactData['instagram'] ?? widget.userData['instagram'];
      });
    }

    if (savedBranches != null) {
      setState(() {
        branches = json.decode(savedBranches);
      });
    }
  }

  Future<void> _loadBranches({bool forceRefresh = false}) async {
    try {
      // Load branches from API
      final branchList = await _wholesalerService.getWholesalerBranches();

      // Convert Branch objects to Map for UI rendering
      final branchesData = branchList.map((branch) => branch.toJson()).toList();

      setState(() {
        branches = branchesData;
      });

      // Cache the branches data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('branches_data', json.encode(branchesData));

    } catch (error) {
      if (!kReleaseMode) {
        print('Error loading branches data: $error');
      }
      if (forceRefresh) {
        throw error; // Re-throw for pull-to-refresh
      }
      // Otherwise, try to load from cache (handled in _initializeData)
    }
  }

  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get branch ID - Use _id as that's what's in your branch objects
      var branchId = branch['_id'];
      if (branchId is Map && branchId.containsKey("\$oid")) {
        branchId = branchId["\$oid"];
      } else if (branchId == null) {
        branchId = branch['id'];
      }

      if (!kReleaseMode) {
        print('Attempting to delete branch: ${branch['name']} with ID: $branchId');
      }

      // if (branchId == null) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Branch ID not found')),
      //   );
      //   setState(() {
      //     isLoading = false;
      //   });
      //   return;
      // }

      // Call service to delete branch
      final success = await _wholesalerService.deleteBranch(branchId);

      if (success) {
        setState(() {
          branches.removeWhere((b) =>
          (b['_id'] == branchId || b['id'] == branchId) &&
              b['name'] == branch['name']
          );
          isLoading = false;
        });

        // Update the cached branches
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('branches_data', json.encode(branches));

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Branch deleted successfully')),
        // );
      } else {
        setState(() {
          isLoading = false;
        });
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Failed to delete branch')),
        // );
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error deleting branch: $e');
      }
      setState(() {
        isLoading = false;
      });

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to delete branch: ${e.toString()}')),
      // );
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> branch) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Branch"),
          content: Text("Are you sure you want to delete this branch?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteBranch(branch);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBranchesSection() {
    String formatLocation(Map<String, dynamic> branch) {
      if (branch['location'] is String) {
        return branch['location']?.toString() ?? '';
      }

      // Handle structured location data
      if (branch['location'] is Map) {
        final loc = branch['location'] as Map<String, dynamic>;
        return [
          (loc['street']?.toString() ?? '').trim(),
          (loc['city']?.toString() ?? '').trim(),
          (loc['country']?.toString() ?? '').trim(),
        ].where((part) => part.isNotEmpty).join(', ');
      }

      return 'No location';
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Branches section as GridView
          branches.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                'No branches added yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          )
              : GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.0,
              mainAxisSpacing: 12.0,
              childAspectRatio: 0.8,
            ),
            itemCount: branches.length,
            itemBuilder: (context, index) {
              final branch = branches[index] as Map<String, dynamic>;

              return Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _buildBranchImage(branch),
                            ),
                            // Video indicator if videos exist
                            if (branch['videos'] != null &&
                                (branch['videos'] as List).isNotEmpty)
                              Positioned(
                                bottom: 5,
                                right: 5,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 5,
                              left: 5,
                              child: GestureDetector(
                                onTap: () => _navigateToEditBranch(branch),
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        branch['name']?.toString() ?? 'Branch  ${index + 1}',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        formatLocation(branch),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showDeleteConfirmation(branch),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 16),
          // Add button remains the same
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddWholeSalerBranchPage(token: widget.userData['token']),
                ),
              );

              if (result != null && result['refresh'] == true) {
                // Refresh the branches list after adding a new branch
                _loadBranches();
              }
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _navigateToEditBranch(Map<String, dynamic> branch) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWholeSalerBranchPage(
          token: widget.userData['token'],
          isEditMode: true,
          branchData: branch,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        // Find and update the branch in the list
        for (int i = 0; i < branches.length; i++) {
          // Get branch ID - Use _id as that's what's in your branch objects
          var branchId = branches[i]['_id'];
          if (branchId is Map && branchId.containsKey("\$oid")) {
            branchId = branchId["\$oid"];
          } else if (branchId == null) {
            branchId = branches[i]['id'];
          }

          var resultId = result['_id'];
          if (resultId is Map && resultId.containsKey("\$oid")) {
            resultId = resultId["\$oid"];
          }

          if (branchId == resultId) {
            branches[i] = result;
            break;
          }
        }
        print("Updated branch with data: $result");
      });
    }
  }

  Widget _buildBranchImage(Map<String, dynamic> branch) {
    try {
      // Check if branch has images
      final images = branch['images'];
      if (images == null ||
          (images is List && images.isEmpty) ||
          (images is bool)) {
        return Center(
          child: Icon(
            Icons.store,
            size: 40,
            color: Colors.grey[400],
          ),
        );
      }

      final videos = branch['videos'];
      if ((videos != null && videos is List && videos.isNotEmpty) &&
          (branch['images'] == null ||
              (branch['images'] is List && (branch['images'] as List).isEmpty))) {
        return Stack(
          children: [
            Center(
              child: Icon(
                Icons.videocam,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            // You could also use a video thumbnail here if available
          ],
        );
      }

      // Handle both URL and file path cases
      if (images is List && images.isNotEmpty) {
        final imagePath = images[0];
        if (imagePath == null || imagePath is! String || imagePath.isEmpty) {
          return Center(
            child: Icon(
              Icons.store,
              size: 40,
              color: Colors.grey[400],
            ),
          );
        }

        // Print for debugging
        print("Loading image from path: $imagePath");

        if (imagePath.startsWith('http')) {
          // It's already a full URL
          return Image.network(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print("Error loading network image: $error");
              return Icon(Icons.image_not_supported, size: 40, color: Colors.grey[400]);
            },
          );
        } else {
          // It's a server-side path, convert it to a full URL
          final fullImageUrl = '${ApiService.baseUrl}/$imagePath';
          print("Converted to full URL: $fullImageUrl");

          return Image.network(
            fullImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print("Error loading network image: $error");
              return Icon(Icons.image_not_supported, size: 40, color: Colors.grey[400]);
            },
          );
        }
      }

      return Center(
        child: Icon(
          Icons.store,
          size: 40,
          color: Colors.grey[400],
        ),
      );
    } catch (e) {
      print("Exception while building branch image: $e");
      return Center(
        child: Icon(
          Icons.error_outline,
          size: 40,
          color: Colors.red[400],
        ),
      );
    }
  }

  void _navigateToBranchesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WholesalerBranches(
          token: widget.userData['token'],
          initialBranches: branches,
        ),
      ),
    ).then((value) {
      // Refresh branches when returning from branches page
      if (value == true) {
        _loadBranches();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top header with logo and notification
          WholesalerHeader(
            logoUrl: widget.userData['logoUrl'],
            userData: widget.userData,
          ),

          // Main content
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Container(
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      // Profile card
                      Container(
                        margin: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category and subcategory
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Category',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            industryType ?? 'Loading...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Sub Category',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            subCategory ?? 'Loading...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Locations section
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'Locations',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Dynamic Branches Section
                            _buildBranchesSection(),

                            // Hand over to the social details component
                            WholesalerSocialActions(
                              userData: widget.userData,
                              updateCompanyData: _updateCompanyData,
                              navigateToBranchesPage: _navigateToBranchesPage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to be used by the WholesalerSocialActions widget
  Future<void> _updateCompanyData({
    required String phone,
    required String whatsapp,
    required String website,
    required String facebook,
    required String instagram,
  }) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Prepare the data to send with the correct nested structure
      final dataToUpdate = {
        'contactInfo': {
          'phone': phone,
          'whatsapp': whatsapp,
          'website': website,
        },
        'socialMedia': {
          'facebook': facebook,
          'instagram': instagram,
        }
      };

      // Use the service to update wholesaler data
      final success = await _wholesalerService.updateWholesalerData(dataToUpdate);

      if (success) {
        // Update the fields in memory
        setState(() {
          widget.userData['phone'] = phone;
          widget.userData['whatsapp'] = whatsapp;
          widget.userData['website'] = website;
          widget.userData['facebook'] = facebook;
          widget.userData['instagram'] = instagram;
        });

        // Save to shared preferences
        await _saveContactDataToPrefs();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wholesaler details updated successfully')),
        );
      } else {
        throw Exception('Failed to update wholesaler data');
      }
    } catch (e) {
      print('Error updating wholesaler data: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error updating wholesaler: ${e.toString()}')),
      // );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}