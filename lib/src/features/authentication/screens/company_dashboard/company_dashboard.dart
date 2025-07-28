import 'dart:io';
import 'package:barrim/src/features/authentication/screens/company_dashboard/subscription/company_subscription.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../../../services/api_service.dart';
import '../../headers/company_header.dart';
import './addbranch.dart';
import 'branches.dart';
import 'company_referral.dart';
import '../login_page.dart';
import 'package:flutter/foundation.dart';
import 'branch_subscription_branches.dart';

class CompanyDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CompanyDashboard({Key? key, required this.userData}) : super(key: key);

  @override
  State<CompanyDashboard> createState() => _CompanyDashboardState();
}

class _CompanyDashboardState extends State<CompanyDashboard> {
  String? industryType;
  String? subCategory;
  List<dynamic> branches = [];
  bool isLoading = true;
  String? logoUrl;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1. First, load the basic company data (industryType, subCategory, etc.)
      var data = await ApiService.getCompanyData(widget.userData['token']);
      if (!kReleaseMode) {
        print('Company data received: $data');
      }

      // 2. Then fetch the company contact details
      try {
        final userProfile = await ApiService.getUserProfile(widget.userData['token']);
        if (!kReleaseMode) {
          print('User profile data: $userProfile');
        }

        // Extract contact info and social media from the response
        final companyInfo = data['companyInfo'] ?? {};
        final contactInfo = companyInfo['contactInfo'] ?? {};
        final socialMedia = companyInfo['SocialMedia'] ?? {}; // Note capital S

        // Update the widget's userData with the fetched contact details
        setState(() {
          widget.userData['phone'] = contactInfo['phone'] ?? widget.userData['phone'];
          widget.userData['whatsapp'] = contactInfo['whatsap'] ?? widget.userData['whatsapp']; // Note 'whatsap' typo
          widget.userData['website'] = contactInfo['website'] ?? widget.userData['website'];
          widget.userData['facebook'] = socialMedia['facebook'] ?? widget.userData['facebook'];
          widget.userData['instagram'] = socialMedia['instagram'] ?? widget.userData['instagram'];
          logoUrl = companyInfo['logo'] != null && companyInfo['logo'].isNotEmpty
              ? companyInfo['logo']
              : null;
          if (!kReleaseMode) {
            print('CompanyDashboard: Setting logoUrl to: $logoUrl');
            print('CompanyDashboard: companyInfo: $companyInfo');
          }
        });

        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('company_contact_data', json.encode({
          'phone': widget.userData['phone'],
          'whatsapp': widget.userData['whatsapp'],
          'website': widget.userData['website'],
          'facebook': widget.userData['facebook'],
          'instagram': widget.userData['instagram'],
        }));
      } catch (e) {
        if (!kReleaseMode) {
          print('Error fetching company contact details: $e');
        }
        // If fetching fails, try to load from cache
        final prefs = await SharedPreferences.getInstance();
        final savedContactData = prefs.getString('company_contact_data');
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
      }

      // 3. Update the UI with all the fetched data
      setState(() {
        if (data['companyInfo'] != null) {
          industryType = data['companyInfo']['category'] ?? 'Not Available';
          subCategory = data['companyInfo']['subCategory'] ?? 'Not Available';
        }

        // Load branches
        if (data['companyInfo'] != null &&
            data['companyInfo']['branches'] != null &&
            data['companyInfo']['branches'] is List) {
          branches = data['companyInfo']['branches'];
        } else {
          loadBranchesFromApi();
        }

        isLoading = false;
      });

      // 4. Save company data to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('company_data', json.encode(data));

    } catch (error) {
      if (!kReleaseMode) {
        print('Error loading company data: $error');
      }
      // Try to load from cache if API fails
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('company_data');
      final savedContactData = prefs.getString('company_contact_data');

      if (savedData != null) {
        final parsedData = json.decode(savedData);
        setState(() {
          if (parsedData['companyInfo'] != null) {
            industryType = parsedData['companyInfo']['industryType'] ?? 'Not Available';
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

      setState(() {
        isLoading = false;
      });
      loadBranchesFromApi();
    }
  }

  Future<void> loadBranchesFromApi() async {
    try {
      final token = widget.userData['token'];
      if (token == null || token.toString().isEmpty) {
        print('Error: Token is null or empty');
        return;
      }
      
      var branchesData = await ApiService.getCompanyBranches(token.toString());
      setState(() {
        branches = branchesData;
      });
    } catch (error) {
      if (!kReleaseMode) {
        print('Error loading branches data: $error');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!kReleaseMode) {
      print('CompanyDashboard: Building with logoUrl: $logoUrl');
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top header with logo and notification
            CompanyAppHeader(
              logoUrl: logoUrl,
              userData: widget.userData,
            ),

            // Main content
            isLoading
                ? Center(child: CircularProgressIndicator())
                : Container(
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

                        // Details section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Details',
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
                                  color: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Contact details
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Phone numbers
                              Row(
                                children: [
                                  Icon(Icons.phone, color: Colors.blue, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    widget.userData['phone']?.toString() ?? 'Not provided',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Image.asset('assets/icons/whatsapp.png', width: 20, height: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    widget.userData['whatsapp']?.toString() ?? 'Not provided',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              // Social media
                              Row(
                                children: [
                                  Icon(Icons.facebook, color: Colors.blue, size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    widget.userData['facebook']?.toString() ?? 'Not provided',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Image.asset('assets/icons/instagram.png', width: 20, height: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    widget.userData['instagram']?.toString() ?? 'Not provided',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              // Website
                              Row(
                                children: [
                                  Icon(Icons.language, color: Colors.blue, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    widget.userData['website']?.toString() ?? 'Not provided',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              // Edit button
                              Container(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _showEditCompanyDialog,
                                  child: Text('Edit'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF0066B3),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons at bottom
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildActionButton('Reviews Checkup', Icons.arrow_forward_ios),
                        SizedBox(height: 12),
                        _buildActionButton('My Referrals', Icons.arrow_forward_ios),
                        SizedBox(height: 12),
                        _buildActionButton('Subscriptions', Icons.arrow_forward_ios),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchesSection() {
    String formatLocation(Map<String, dynamic> branch) {
      if (branch['location'] is String) {
        return branch['location'];
      }

      // Handle structured location data
      if (branch['location'] is Map) {
        final loc = branch['location'] as Map<String, dynamic>;
        return [
          loc['street'],
          loc['city'],
          loc['country']
        ].where((part) => part != null && part.isNotEmpty).join(', ');
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

              // Debug print to check video data
              if (!kReleaseMode) {
                print('Branch $index videos: ${branch['videos']}');
              }

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
                        branch['name']?.toString() ?? 'Branch ${index + 1}',
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
                  builder: (context) => AddBranchPage(token: widget.userData['token']),
                ),
              );

              if (result != null && result['refresh'] == true && result is Map<String, dynamic>) {
                setState(() {
                  branches.add(result);
                  loadBranchesFromApi();
                  if (!kReleaseMode) {
                    print("Added new branch with data: $result");
                  }
                });
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

  void _showEditCompanyDialog() {
    // Get current values from the user data
    final currentPhone = widget.userData['phone'] ?? '';
    final currentWhatsApp = widget.userData['whatsapp'] ?? '';
    final currentWebsite = widget.userData['website'] ?? '';
    final currentFacebook = widget.userData['facebook'] ?? '';
    final currentInstagram = widget.userData['instagram'] ?? '';

    // Controllers for text fields
    final phoneController = TextEditingController(text: currentPhone);
    final whatsappController = TextEditingController(text: currentWhatsApp);
    final websiteController = TextEditingController(text: currentWebsite);
    final facebookController = TextEditingController(text: currentFacebook);
    final instagramController = TextEditingController(text: currentInstagram);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit Company Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+961 1 234 567',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'WhatsApp Number',
                    hintText: '+961 1 234 567',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Image.asset(
                        'assets/icons/whatsapp.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Website URL',
                    hintText: 'https://www.example.com',
                    prefixIcon: Icon(Icons.language),
                  ),
                  controller: websiteController,
                  keyboardType: TextInputType.url,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Facebook URL',
                    hintText: 'https://facebook.com/yourpage',
                    prefixIcon: Icon(Icons.facebook),
                  ),
                  controller: facebookController,
                  keyboardType: TextInputType.url,
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Instagram URL',
                    hintText: 'https://instagram.com/yourpage',
                    prefixIcon: Icon(Icons.camera_alt),
                  ),
                  controller: instagramController,
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () {
                _updateCompanyData(
                  phone: phoneController.text,
                  whatsapp: whatsappController.text,
                  website: websiteController.text,
                  facebook: facebookController.text,
                  instagram: instagramController.text,
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

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

      // Use the API service method to update company data
      final success = await ApiService.updateCompanyData(widget.userData['token'], dataToUpdate);

      if (success) {
        // Success - update local data and shared preferences
        final prefs = await SharedPreferences.getInstance();
        final savedData = prefs.getString('company_data');
        Map<String, dynamic> companyData = {};

        if (savedData != null) {
          companyData = json.decode(savedData);
        }

        // Update the fields in memory
        setState(() {
          widget.userData['phone'] = phone;
          widget.userData['whatsapp'] = whatsapp;
          widget.userData['website'] = website;
          widget.userData['facebook'] = facebook;
          widget.userData['instagram'] = instagram;
        });

        // Save contact data to shared preferences
        await prefs.setString('company_contact_data', json.encode({
          'phone': phone,
          'whatsapp': whatsapp,
          'website': website,
          'facebook': facebook,
          'instagram': instagram,
        }));

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Company details updated successfully')),
        // );
      } else {
        throw Exception('Failed to update company data');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('Error updating company data: $e');
      }
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error updating company: ${e.toString()}')),
      // );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _navigateToEditBranch(Map<String, dynamic> branch) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBranchPage(
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
        if (!kReleaseMode) {
          print("Updated branch with data: $result");
        }
      });
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

  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    try {
      // Show loading indicator
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
      // Debug the branch we're trying to delete
      if (!kReleaseMode) {
        print('Attempting to delete branch: ${branch['name']} with ID: $branchId');
      }

      if (branchId == null) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Branch ID not found')),
        // );
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Call API to delete branch
      final success = await ApiService.deleteBranch(widget.userData['token'], branchId);

      if (success) {
        // Use a more precise approach for removing the branch from the local list
        // by checking both ID and name to ensure we're removing exactly the right branch
        setState(() {
          int indexToRemove = -1;
          for (int i = 0; i < branches.length; i++) {
            if (branches[i] is Map<String, dynamic> &&
                branches[i]['_id'] == branchId &&
                branches[i]['name'] == branch['name']) {
              indexToRemove = i;
              break;
            }
          }

          if (indexToRemove != -1) {
            branches.removeAt(indexToRemove);
          }

          isLoading = false;
        });

        // After deletion, refresh branch data from API to ensure UI matches backend
        loadBranchesFromApi();

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
        if (imagePath == null || imagePath is! String) {
          return Center(
            child: Icon(
              Icons.store,
              size: 40,
              color: Colors.grey[400],
            ),
          );
        }

        // Print for debugging
        if (!kReleaseMode) {
          print("Loading image from path: $imagePath");
        }

        if (imagePath.startsWith('http')) {
          // It's already a full URL
          return Image.network(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (!kReleaseMode) {
                print("Error loading network image: $error");
              }
              return Icon(Icons.image_not_supported, size: 40, color: Colors.grey[400]);
            },
          );
        } else {
          // It's a server-side path, convert it to a full URL
          final fullImageUrl = '${ApiService.baseUrl}/$imagePath';
          if (!kReleaseMode) {
            print("Converted to full URL: $fullImageUrl");
          }

          return Image.network(
            fullImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (!kReleaseMode) {
                print("Error loading network image: $error");
              }
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
      if (!kReleaseMode) {
        print("Exception while building branch image: $e");
      }
      return Center(
        child: Icon(
          Icons.error_outline,
          size: 40,
          color: Colors.red[400],
        ),
      );
    }
  }

  Widget _buildActionButton(String title, IconData icon) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0094FF),
            Color(0xFF05055A),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            // Handle button tap based on title
            if (title == 'Reviews Checkup') {
              _navigateToBranchesPage();
            }
            if (title == 'My Referrals') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReferralsPage(userData: widget.userData),
                ),
              );
            }
            if (title == 'Subscriptions') {
              final token = widget.userData['token'];
              if (token == null || (token is String && token.isEmpty)) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Error'),
                    content: Text('Authentication token not found. Please login again.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BranchSubscriptionBranchesPage(
                    token: token,
                    initialBranches: branches,
                    userData: widget.userData,
                    logoUrl: logoUrl,
                  ),
                ),
              );
            }
            // Add other button actions here as needed
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToBranchesPage() {
    final token = widget.userData['token'];
    if (token == null || token is! String || token.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Authentication token not found. Please login again.')),
      // );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BranchesPage(
          token: token,
          initialBranches: branches,
          userData: widget.userData,
        ),
      ),
    );
  }
}

