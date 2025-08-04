import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../../models/company_model.dart';
import '../../../../services/company_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../utils/token_manager.dart';
import '../../headers/company_header.dart';
import '../../../../services/api_service.dart';
import '../login_page.dart'; // Adjust the path as needed
import 'package:barrim/src/components/secure_network_image.dart';

class CompanyProfileSettings extends StatefulWidget {
   final Map<String, dynamic> userData;
  const CompanyProfileSettings({Key? key, required this.userData}) : super(key: key);

  @override
  State<CompanyProfileSettings> createState() => _CompanyProfileSettingsState();
}

class _CompanyProfileSettingsState extends State<CompanyProfileSettings> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final CompanyService _companyService = CompanyService();
  final AuthService _authService = AuthService();

  Company? _companyData;
  bool _isLoading = true;
  bool _isSaving = false;

  String? _logoUrl;
  bool _isUsingNetworkImage = false;
  File? _selectedImage;
  bool _passwordChangeMode = false;
  bool _passwordObscured = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('CompanyProfileSettings: initState called');
    _fetchCompanyData();
  }

  // Fetch company data from the backend
  Future<void> _fetchCompanyData() async {
    print('CompanyProfileSettings: Fetching company data');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('CompanyProfileSettings: Calling company service');
      // Fetch company data
      final company = await _companyService.getCompanyData();
      print('CompanyProfileSettings: Company data fetched: ${company.businessName}');
      print('CompanyProfileSettings: Raw company data: ${company.toJson()}');

      // Get user email from the company data response
      print('CompanyProfileSettings: Getting user email from company data');
      String userEmail = '';
      
      // Try to get email from the raw company data response
      try {
        // Get the raw response from the company service to access additional fields
        final tokenManager = TokenManager();
        final token = await tokenManager.getToken();
        final url = '${ApiService.baseUrl}/api/companies/data';
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          print('CompanyProfileSettings: Raw company response: $responseData');
          
          // Check if email is in the response data
          userEmail = responseData['data']?['email'] ?? 
                     responseData['data']?['user']?['email'] ?? 
                     responseData['data']?['companyInfo']?['email'] ?? '';
          
          print('CompanyProfileSettings: User email from company data: $userEmail');
          
          // If email is still empty, try to get it from the user profile
          if (userEmail.isEmpty) {
            print('CompanyProfileSettings: Email not found in company data, trying user profile');
            try {
              final userProfile = await ApiService.getUserProfile(token);
              userEmail = userProfile['email'] ?? '';
              print('CompanyProfileSettings: User email from user profile: $userEmail');
            } catch (profileError) {
              print('CompanyProfileSettings: Error getting user profile: $profileError');
            }
          }
        }
      } catch (e) {
        print('CompanyProfileSettings: Error getting email from company data: $e');
        userEmail = '';
      }

      setState(() {
        _companyData = company;
        // Update to use the correct logo field from API response
        _logoUrl = company.logo != null && company.logo!.isNotEmpty
            ? '${ApiService.baseUrl}/${company.logo}'
            : null;
        print('CompanyProfileSettings: Logo field from company: ${company.logo}');
        print('CompanyProfileSettings: _logoUrl set to: $_logoUrl');
        _isUsingNetworkImage = _logoUrl != null && _logoUrl!.isNotEmpty;
        print('CompanyProfileSettings: _isUsingNetworkImage: $_isUsingNetworkImage');

        // Populate form fields with company data
        _nameController.text = company.businessName;
        print('CompanyProfileSettings: Business name set: ${_nameController.text}');
        _emailController.text = userEmail;
        print('CompanyProfileSettings: Email set: ${_emailController.text}');
      });
    } catch (e) {
      print('CompanyProfileSettings: Error fetching data: $e');
      setState(() {
        _errorMessage = 'Failed to load company data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
        print('CompanyProfileSettings: Loading complete, isLoading = $_isLoading');
      });
    }
  }

  // Save updated company information
  Future<void> _saveCompanyData() async {
    // Validate form data
    if (_nameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Business name cannot be empty';
      });
      return;
    }

    if (_passwordChangeMode) {
      if (_currentPasswordController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Current password is required to change password';
        });
        return;
      }

      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'New passwords do not match';
        });
        return;
      }

      if (_newPasswordController.text.length < 6) {
        setState(() {
          _errorMessage = 'New password must be at least 6 characters';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_selectedImage != null) {
        // Update profile with new logo
        await _companyService.updateCompanyProfileWithLogo(
          businessName: _nameController.text,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          currentPassword: _passwordChangeMode ? _currentPasswordController.text : null,
          newPassword: _passwordChangeMode ? _newPasswordController.text : null,
          logoFile: _selectedImage,
        );
      } else {
        // Update profile without changing logo
        await _companyService.updateCompanyProfile(
          businessName: _nameController.text,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          currentPassword: _passwordChangeMode ? _currentPasswordController.text : null,
          newPassword: _passwordChangeMode ? _newPasswordController.text : null,
        );
      }

      // Show success message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Profile updated successfully'),
      //     backgroundColor: Colors.green,
      //   ),
      // );

      // Refresh data
      await _fetchCompanyData();

      // Reset password fields
      if (_passwordChangeMode) {
        setState(() {
          _passwordChangeMode = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }


  Future<void> _selectProfileImage() async {
    final ImagePicker picker = ImagePicker();

    // Show dialog for image source selection
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Text('Take a Picture'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(source: ImageSource.camera);
                    _processSelectedImage(image);
                  },
                ),
                const Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    _processSelectedImage(image);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _processSelectedImage(XFile? image) {
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _isUsingNetworkImage = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildProfileImage() {
    final fullLogoUrl = _logoUrl != null ? '${ApiService.baseUrl}/$_logoUrl' : null;

    if (_selectedImage != null) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: FileImage(_selectedImage!),
      );
    } else if (_isUsingNetworkImage && _logoUrl != null) {
      return ClipOval(
        child: Image.network(
          _logoUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('CompanyProfileSettings: Error loading avatar image: $error');
            return Image.asset(
              'assets/logo/barrim_logo1.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            );
          },
        ),
      );
    } else {
      // Default placeholder when no image is available
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey.shade200,
        child: Image.asset(
          'assets/logo/barrim_logo1.png',
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Company Header
          CompanyAppHeader(
            logoUrl: _logoUrl,
            userData: widget.userData,
          ),

          // Profile settings content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),

                    // Profile picture
                    GestureDetector(
                      onTap: _selectProfileImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildProfileImage(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFF2079C2),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Change profile picture text
                    GestureDetector(
                      onTap: _selectProfileImage,
                      child: const Text(
                        'Change Company Logo',
                        style: TextStyle(
                          color: Color(0xFF2079C2),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Display error message if any
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // Business Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Company Name',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Email
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Company Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Current Password field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              TextField(
                                controller: _currentPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  hintText: '••••••••••••••••',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _passwordChangeMode = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2079C2),
                                    minimumSize: const Size(80, 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (!_passwordChangeMode)
                      const SizedBox(height: 24),
                    // Password change section
                    if (_passwordChangeMode)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // New password
                          const Text(
                            'New Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _newPasswordController,
                              obscureText: _passwordObscured,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordObscured
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _passwordObscured = !_passwordObscured;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Confirm new password
                          const Text(
                            'Confirm New Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _confirmPasswordController,
                              obscureText: _passwordObscured,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Password buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _passwordChangeMode = false;
                                    _currentPasswordController.clear();
                                    _newPasswordController.clear();
                                    _confirmPasswordController.clear();
                                    _errorMessage = null;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade300,
                                  minimumSize: const Size(120, 40),
                                ),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () {
                                  // Only update password
                                  if (_currentPasswordController.text.isEmpty) {
                                    setState(() {
                                      _errorMessage = 'Please enter your current password';
                                    });
                                    return;
                                  }

                                  if (_newPasswordController.text != _confirmPasswordController.text) {
                                    setState(() {
                                      _errorMessage = 'New passwords do not match';
                                    });
                                    return;
                                  }

                                  _saveCompanyData();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2079C2),
                                  minimumSize: const Size(120, 40),
                                ),
                                child: const Text(
                                  'Update Password',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                        ],
                      ),

                    const SizedBox(height: 40),

                    // Save button
                    SizedBox(
                      width: 286,
                      height: 66,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveCompanyData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2079C2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),
                    

                    // Delete Account Button
                    SizedBox(
                      width: 286,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Account'),
                              content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            setState(() { _isSaving = true; _errorMessage = null; });
                            try {
                              final success = await ApiService.deleteUserAccount();
                              if (success) {
                                if (mounted) {
                                  // ScaffoldMessenger.of(context).showSnackBar(
                                  //   const SnackBar(content: Text('Account deleted successfully.')),
                                  // );
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const LoginPage()),
                                  (route) => false,
                                );                                }
                              }
                            } catch (e) {
                              setState(() { _errorMessage = e.toString(); });
                            } finally {
                              setState(() { _isSaving = false; });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}