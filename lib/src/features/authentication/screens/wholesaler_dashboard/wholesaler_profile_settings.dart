import 'dart:io';
import 'package:barrim/src/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/wholesaler_service.dart';
import '../login_page.dart';
import 'package:barrim/src/components/secure_network_image.dart';
import '../../headers/wholesaler_header.dart';

class WholesalerProfileSettings extends StatefulWidget {
  const WholesalerProfileSettings({Key? key}) : super(key: key);

  @override
  State<WholesalerProfileSettings> createState() => _WholesalerProfileSettingsState();
}

class _WholesalerProfileSettingsState extends State<WholesalerProfileSettings> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final WholesalerService _wholesalerService = WholesalerService();

  bool _isLoading = true;
  bool _isSaving = false;

  String? _logoUrl;
  String? _headerLogoUrl;
  bool _isUsingNetworkImage = false;
  File? _selectedImage;
  bool _passwordChangeMode = false;
  bool _passwordObscured = true;
  String? _errorMessage;

  // Base URL for accessing uploaded files
  final String _baseImageUrl = ApiService.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadWholesalerData();
  }

  Future<void> _loadWholesalerData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final wholesaler = await _wholesalerService.getWholesalerData();
      if (wholesaler != null) {
        setState(() {
          _nameController.text = wholesaler.name ?? '';
          _emailController.text = wholesaler.email ?? '';

          if (wholesaler.logoUrl != null && wholesaler.logoUrl!.isNotEmpty) {
            // If logo path is relative, prepend the base URL
            if (wholesaler.logoUrl!.startsWith('uploads/')) {
              _logoUrl = '$_baseImageUrl/${wholesaler.logoUrl}';
            } else {
              _logoUrl = wholesaler.logoUrl;
            }
            _isUsingNetworkImage = true;
          }

          // Load header logo URL
          _loadHeaderLogoUrl(wholesaler.logoUrl);
        });
      }
    } catch (e) {
      _setError('Failed to load wholesaler data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHeaderLogoUrl(String? logoUrl) async {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      // Convert logo URL to full URL if it's a relative path
      String? processedLogoUrl = logoUrl;
      
      // If it starts with file://, remove it and convert to full URL
      if (processedLogoUrl.startsWith('file://')) {
        processedLogoUrl = processedLogoUrl.replaceFirst('file://', '');
        // Remove leading slash if present
        if (processedLogoUrl.startsWith('/')) {
          processedLogoUrl = processedLogoUrl.substring(1);
        }
        processedLogoUrl = '${ApiService.baseUrl}/$processedLogoUrl';
      }
      // If it's a relative path, convert to full URL
      else if (processedLogoUrl.startsWith('/') || processedLogoUrl.startsWith('uploads/')) {
        processedLogoUrl = '${ApiService.baseUrl}/$processedLogoUrl';
      }
      
      setState(() {
        _headerLogoUrl = processedLogoUrl;
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

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
    });
    // Auto-clear error after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  Future<void> _saveProfileChanges() async {
    // Validate current password
    if (_currentPasswordController.text.isEmpty) {
      _setError('Current password is required to make changes');
      return;
    }

    // Validate password confirmation
    if (_passwordChangeMode &&
        _newPasswordController.text != _confirmPasswordController.text) {
      _setError('New passwords do not match');
      return;
    }

    try {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      final result = await _wholesalerService.changeWholesalerDetails(
        currentPassword: _currentPasswordController.text,
        newPassword: _passwordChangeMode ? _newPasswordController.text : null,
        email: _emailController.text,
        logoFile: _selectedImage,
      );

      if (result != null) {
        // If logo URL was updated, update the local state
        if (result['logoUrl'] != null) {
          setState(() {
            String logoUrl = result['logoUrl'];
            // If logo path is relative, prepend the base URL
            if (logoUrl.startsWith('uploads/')) {
              _logoUrl = '$_baseImageUrl/$logoUrl';
            } else {
              _logoUrl = logoUrl;
            }
            _isUsingNetworkImage = true;
            _selectedImage = null; // Clear selected image as it's been uploaded
          });
        }

        // If password was changed, reset password fields and exit password change mode
        if (_passwordChangeMode) {
          setState(() {
            _passwordChangeMode = false;
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
          });
        } else {
          // Just clear the current password field
          _currentPasswordController.clear();
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      _setError('Failed to update profile: $e');
    } finally {
      setState(() {
        _isSaving = false;
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
    if (_selectedImage != null) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: FileImage(_selectedImage!),
      );
    } else if (_isUsingNetworkImage && _logoUrl != null) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: null,
        child: ClipOval(
          child: SecureNetworkImage(
            imageUrl: _logoUrl!,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            placeholder: Container(
              width: 120,
              height: 120,
              color: Colors.grey.shade200,
              child: Icon(Icons.business, size: 60, color: Colors.grey),
            ),
            errorWidget: (context, url, error) => Container(
              width: 120,
              height: 120,
              color: Colors.grey.shade200,
              child: Icon(Icons.business, size: 60, color: Colors.grey),
            ),
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
          // Wholesaler header
          WholesalerHeader(
            onLogoTap: () {
              Navigator.pop(context);
            },
            logoUrl: _headerLogoUrl,
          ),
          
          // Back button and title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2079C2)),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
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
                        'Change wholesaler Logo',
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
                          'Wholesaler Name',
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
                            enabled: false, // Making this read-only as name update is not implemented in backend
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
                          'Wholesaler Email',
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
                                onPressed: _saveProfileChanges,
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
                              onPressed: _isSaving ? null : _saveProfileChanges,
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
                                          const SnackBar(content: Text('Account deleted successfully.')),
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