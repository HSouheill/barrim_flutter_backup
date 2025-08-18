import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/components/secure_network_image.dart';
import '../../headers/dashboard_headers.dart';
import '../user_dashboard/notification.dart' as notification;
import '../user_dashboard/home.dart';
import '../category/categories.dart';
import '../workers/worker_home.dart';
import '../booking/myboooking.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import 'package:barrim/src/utils/authService.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isSidebarOpen = false;

  String profileImagePath = ''; // Default image
  bool _isUsingNetworkImage = false;
  File? _selectedImage;

  bool _passwordChangeMode = false;
  bool _passwordObscured = true;
  String? _errorMessage;

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  Widget _buildSidebar() {
    return Container(
      width: 199,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2079C2),
            Color(0xFF1F4889),
            Color(0xFF10105D),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(5, 0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(top: 30),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset('assets/logo/sidebar_logo.png', width: 50, height: 50),
                      Text(
                        'Barrim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                ListTile(
                  leading: Icon(Icons.home, color: Colors.white),
                  title: Text('Home', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const UserDashboard(userData: {})),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.category, color: Colors.white),
                  title: Text('Categories', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const CategoriesPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.white),
                  title: Text('Workers', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const DriversGuidesPage()),
                      );
                    });
                  },
                ),
                // ListTile(
                //   leading: Icon(Icons.book_online, color: Colors.white),
                //   title: Text('Bookings', style: TextStyle(color: Colors.white)),
                //   onTap: () {
                //     _toggleSidebar();
                //     Future.delayed(const Duration(milliseconds: 300), () {
                //       Navigator.of(context).pushReplacement(
                //         MaterialPageRoute(builder: (context) => const MyBookingsPage()),
                //       );
                //     });
                //   },
                // ),
                ListTile(
                  leading: Icon(Icons.share, color: Colors.white),
                  title: Text('Referral', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const ReferralPointsPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.white),
                  title: Text('Settings', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.blue),
                      title: Text('Logout', style: TextStyle(color: Colors.blue)),
                      onTap: () async {
                        _toggleSidebar();
                        await AuthService().logout();
                        Future.delayed(const Duration(milliseconds: 300), () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    print('ProfileSettingsPage: initState called');
    // Load user data when component mounts
    _loadUserData().then((_) {
      print('ProfileSettingsPage: User data loaded successfully');
    }).catchError((error) {
      print('ProfileSettingsPage: Error loading user data: $error');
      setState(() {
        _errorMessage = 'Failed to load profile data';
      });
    });
  }

  Future<String?> _getToken() async {
    print('ProfileSettingsPage: Getting token from SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('ProfileSettingsPage: Token retrieved: ${token != null ? "exists" : "null"}');
    return token;
  }

  // Load user profile data
  Future<void> _loadUserData() async {
    print('ProfileSettingsPage: _loadUserData started');

    try {
      final userData = await ApiService.getUserData();
      print('ProfileSettingsPage: Received user data: $userData');

      setState(() {
        _nameController.text = userData['fullName'] ?? '';
        _emailController.text = userData['email'] ?? '';

        // Handle profile picture
        if (userData['profilePic'] != null && userData['profilePic'].toString().isNotEmpty) {
          String profilePic = userData['profilePic'];
          print('ProfileSettingsPage: Raw profilePic value: $profilePic');

          // Construct the full URL
          if (profilePic.startsWith('http')) {
            // Already a full URL
            profileImagePath = profilePic;
          } else {
            // Need to add base URL
            // Remove leading slash if present in both baseUrl and profilePic
            if (ApiService.baseUrl.endsWith('/') && profilePic.startsWith('/')) {
              profileImagePath = '${ApiService.baseUrl}${profilePic.substring(1)}';
            } else if (!ApiService.baseUrl.endsWith('/') && !profilePic.startsWith('/')) {
              profileImagePath = '${ApiService.baseUrl}/${profilePic}';
            } else {
              profileImagePath = '${ApiService.baseUrl}${profilePic}';
            }
          }

          print('ProfileSettingsPage: Constructed image URL: $profileImagePath');
          _isUsingNetworkImage = true;
        } else {
          print('ProfileSettingsPage: No profile image found, using default placeholder');
          _isUsingNetworkImage = false;
        }
      });
    } catch (e) {
      print('ProfileSettingsPage: Error in _loadUserData: $e');
      setState(() {
        _errorMessage = 'Failed to load profile data: ${e.toString()}';
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
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Name and email are required';
      });
      return;
    }

    if (_currentPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Current password is required to update profile';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      // First upload profile photo if selected
      if (_selectedImage != null) {
        await ApiService.uploadProfilePhoto(_selectedImage!);
      }

      // Then update profile info
      await ApiService.updateProfile(
        fullName: _nameController.text,
        email: _emailController.text,
        currentPassword: _currentPasswordController.text,
      );

      // Reload user data to get the updated profile picture URL

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      // Removed loading state
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (_newPasswordController.text.length < 8) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      await ApiService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      // Clear password fields and exit change mode
      setState(() {
        _passwordChangeMode = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to change password: ${e.toString()}';
      });
    } finally {
      // Removed loading state
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
    } else if (_isUsingNetworkImage) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade200,
        ),
        child: ClipOval(
          child: SecureNetworkImage(
            imageUrl: profileImagePath,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            placeholder: const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) {
              print('Error loading network image: $error');
              // Return a placeholder icon instead of an asset image
              return const Icon(
                Icons.person,
                size: 60,
                color: Colors.grey,
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
          Icons.person,
          size: 60,
          color: Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Use the AppHeader component
              AppHeader(
                profileImagePath: _isUsingNetworkImage ? profileImagePath : null,
                onNotificationTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => notification.NotificationsPage(),
                    ),
                  );
                },
                onProfileTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(),
                    ),
                  );
                },
                onMenuTap: _toggleSidebar,
              ),

              // Back button
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF2079C2),
                      size: 28,
                    ),
                  ),
                ),
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
                            'Change Profile Picture',
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

                        // Full Name
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Full Name',
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
                              'Email',
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
                                    onPressed: _changePassword,
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
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2079C2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

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
                                setState(() { _errorMessage = null; });
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

          // Semi-transparent overlay when sidebar is open
          if (_isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),

          // Sidebar
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _isSidebarOpen ? 0 : -250,
            top: 0,
            bottom: 0,
            child: _buildSidebar(),
          ),
        ],
      ),
    );
  }
}

