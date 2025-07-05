import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../models/service_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/service_provider_services.dart';
import '../../headers/service_provider_header.dart';
import '../login_page.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class SPProfileSettings extends StatefulWidget {
  const SPProfileSettings({Key? key}) : super(key: key);

  @override
  State<SPProfileSettings> createState() => _SPProfileSettingsState();
}

class _SPProfileSettingsState extends State<SPProfileSettings> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final ServiceProviderService _serviceProviderService = ServiceProviderService();
  final AuthService _authService = AuthService();

  ServiceProvider? _serviceProviderData;
  bool _isLoading = true;
  bool _isSaving = false;

  String? _logoUrl;
  bool _isUsingNetworkImage = false;
  File? _selectedImage;
  bool _passwordChangeMode = false;
  bool _passwordObscured = true;
  String? _errorMessage;

  // Base URL for API and assets
  final String _baseUrl = ApiService.baseUrl;

  @override
  void initState() {
    super.initState();
    print('SPProfileSettings: initState called');
    _fetchServiceProviderData();
  }

  // Fetch service provider data from the backend
  Future<void> _fetchServiceProviderData() async {
    print('SPProfileSettings: Fetching service provider data');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('SPProfileSettings: Calling service provider service');
      // Fetch service provider data
      final serviceProvider = await _serviceProviderService.getServiceProviderData();
      print('SPProfileSettings: Service provider data fetched: ${serviceProvider.fullName}');

      // Fetch user email separately since it might not be in the service provider model
      print('SPProfileSettings: Fetching user email');
      final userEmail = await _authService.getUserEmail();
      print('SPProfileSettings: User email fetched: $userEmail');

      setState(() {
        _serviceProviderData = serviceProvider;
        _logoUrl = serviceProvider.logoPath;
        print('SPProfileSettings: Logo URL: $_logoUrl');
        _isUsingNetworkImage = _logoUrl != null && _logoUrl!.isNotEmpty;

        // Populate form fields with service provider data
        _nameController.text = serviceProvider.fullName;
        print('SPProfileSettings: Business name set: ${_nameController.text}');
        _emailController.text = userEmail;
        print('SPProfileSettings: Email set: ${_emailController.text}');
      });
    } catch (e) {
      print('SPProfileSettings: Error fetching data: $e');
      setState(() {
        _errorMessage = 'Failed to load service provider data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
        print('SPProfileSettings: Loading complete, isLoading = $_isLoading');
      });
    }
  }

  // Save updated service provider information
  Future<void> _saveServiceProviderData() async {
    // Validate form data
    if (_nameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Service provider name cannot be empty';
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
        await _serviceProviderService.updateServiceProviderProfileWithLogo(
          businessName: _nameController.text,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
          currentPassword: _passwordChangeMode ? _currentPasswordController.text : null,
          newPassword: _passwordChangeMode ? _newPasswordController.text : null,
          logoFile: _selectedImage!,
        );
      } else {
        // Update profile without changing logo
        await _serviceProviderService.updateServiceProviderProfile(
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
      await _fetchServiceProviderData();

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

  // Get full image URL
  String _getFullImageUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    } else {
      // Ensure exactly one slash between baseUrl and path
      if (path.startsWith('/')) {
        return '$_baseUrl$path';
      } else {
        return '$_baseUrl/$path';
      }
    }
  }

  Widget _buildProfileImage() {
    if (_selectedImage != null) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: FileImage(_selectedImage!),
      );
    } else if (_isUsingNetworkImage && _logoUrl != null) {
      // Use the full URL for network images
      final fullImageUrl = _getFullImageUrl(_logoUrl!);
      print('SPProfileSettings: Using network image with URL: $fullImageUrl');
      return CircleAvatar(
        radius: 60,
        backgroundImage: null,
        child: ClipOval(
          child: SecureNetworkImage(
            imageUrl: fullImageUrl,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            placeholder: Container(
              width: 120,
              height: 120,
              color: Colors.grey.shade200,
              child: Icon(Icons.business, size: 60, color: Colors.grey),
            ),
            errorWidget: (context, url, error) {
              print('SPProfileSettings: Error loading image: $error');
              return Container(
                width: 120,
                height: 120,
                color: Colors.grey.shade200,
                child: Icon(Icons.business, size: 60, color: Colors.grey),
              );
            },
          ),
        ),
      );
    } else {
      // Default placeholder when no image is available
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(
          Icons.business,
          size: 60,
          color: Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ServiceProviderHeader(
            serviceProvider: _serviceProviderData,
            isLoading: _isLoading,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button and title
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.blue),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'Profile Settings',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Profile Image Section
                    Center(
                      child: Stack(
                        children: [
                          _buildProfileImage(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.camera_alt, color: Colors.white),
                                onPressed: _selectProfileImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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
                          'Your Name',
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
                          'Email Address',
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

                                  _saveServiceProviderData();
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

                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 286,
                            height: 66,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveServiceProviderData,
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
                          const SizedBox(height: 20),
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
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Account deleted.')),
                                        );
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(builder: (context) => const LoginPage()),
                                          (route) => false,
                                        );
                                      }
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
                        ],
                      ),
                    ),
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