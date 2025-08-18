import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../headers/dashboard_headers.dart';
import '../user_dashboard/notification.dart' as notification;
import '../user_dashboard/home.dart';
import '../category/categories.dart';
import '../workers/worker_home.dart';
import '../booking/myboooking.dart';
import '../referrals/user_referral.dart';
import '../login_page.dart';
import 'settings.dart';
import 'package:barrim/src/utils/authService.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() => _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  bool _isSidebarOpen = false;
  String _selectedGender = 'Male';
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  String? _profileImagePath;
  bool _isUsingNetworkImage = false;

  // Controllers for editable fields
  final TextEditingController _phoneController = TextEditingController(text: '+961 01 234 567');
  final TextEditingController _locationController = TextEditingController(text: 'Beirut');
  final TextEditingController _referralCodeController = TextEditingController(text: '123456');
  final TextEditingController _cityController = TextEditingController(text: 'Beirut');
  final TextEditingController _postalCodeController = TextEditingController(text: '1234');
  final TextEditingController _dobController = TextEditingController(text: '12/12/2000');
  final TextEditingController _dealsController = TextEditingController(text: 'Example Business');

  // Gender options
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load user profile data
  Future<void> _loadUserData() async {
    print('PersonalInformationPage: _loadUserData started');

    try {
      final userData = await ApiService.getUserData();
      print('PersonalInformationPage: Received user data: $userData');

      setState(() {
        // Handle profile picture
        if (userData['profilePic'] != null && userData['profilePic'].toString().isNotEmpty) {
          String profilePic = userData['profilePic'];
          print('PersonalInformationPage: Raw profilePic value: $profilePic');

          // Construct the full URL
          if (profilePic.startsWith('http')) {
            // Already a full URL
            _profileImagePath = profilePic;
          } else {
            // Need to add base URL
            // Remove leading slash if present in both baseUrl and profilePic
            if (ApiService.baseUrl.endsWith('/') && profilePic.startsWith('/')) {
              _profileImagePath = '${ApiService.baseUrl}${profilePic.substring(1)}';
            } else if (!ApiService.baseUrl.endsWith('/') && !profilePic.startsWith('/')) {
              _profileImagePath = '${ApiService.baseUrl}/${profilePic}';
            } else {
              _profileImagePath = '${ApiService.baseUrl}${profilePic}';
            }
          }

          print('PersonalInformationPage: Constructed image URL: $_profileImagePath');
          _isUsingNetworkImage = true;
        } else {
          print('PersonalInformationPage: No profile image found, using default placeholder');
          _isUsingNetworkImage = false;
        }

        // Load user data into form fields if available
        if (userData['phone'] != null) {
          _phoneController.text = userData['phone'];
        }
        if (userData['location'] != null && userData['location'] is Map) {
          final location = userData['location'] as Map;
          if (location['city'] != null) {
            _cityController.text = location['city'];
          }
          if (location['street'] != null) {
            _locationController.text = location['street'];
          }
          if (location['postalCode'] != null) {
            _postalCodeController.text = location['postalCode'];
          }
        }
        if (userData['dateOfBirth'] != null) {
          _dobController.text = userData['dateOfBirth'];
        }
        if (userData['gender'] != null) {
          _selectedGender = userData['gender'];
        }
      });
    } catch (e) {
      print('PersonalInformationPage: Error in _loadUserData: $e');
      setState(() {
        _errorMessage = 'Failed to load profile data: ${e.toString()}';
      });
    }
  }

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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _locationController.dispose();
    _referralCodeController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _dobController.dispose();
    _dealsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              AppHeader(
                onMenuTap: _toggleSidebar,
                profileImagePath: _isUsingNetworkImage ? _profileImagePath : null,
                onNotificationTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => notification.NotificationsPage(),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              // Display error message if any
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Phone Number
                          _buildLabel('Phone Number'),
                          _buildEditableField(_phoneController, 'Enter phone number'),
                          const SizedBox(height: 16),

                          // Location and Referral Code
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Location'),
                                    _buildEditableField(_locationController, 'Enter location'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Referral Code'),
                                    _buildEditableField(_referralCodeController, 'Enter referral code'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // City and Postal Code
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('City'),
                                    _buildEditableField(_cityController, 'Enter city'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Postal Code'),
                                    _buildEditableField(_postalCodeController, 'Enter postal code'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Gender and DOB
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Gender'),
                                    _buildGenderDropdown(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('DOB'),
                                    _buildDateField(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Type of deals
                          _buildLabel('Type of deals'),
                          _buildEditableField(_dealsController, 'Enter deal types'),
                          const SizedBox(height: 24),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    await ApiService.updatePersonalInformation(
                                      phone: _phoneController.text,
                                      dateOfBirth: _dobController.text,
                                      gender: _selectedGender,
                                      location: {
                                        'city': _cityController.text,
                                        'country': 'Lebanon', // Set default or get from user
                                        'district': '', // Add if available
                                        'street': _locationController.text, // Use location field as street
                                        'postalCode': _postalCodeController.text,
                                        'lat': 0.0, // Add actual coordinates if available
                                        'lng': 0.0, // Add actual coordinates if available
                                      },
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Personal information updated successfully')),
                                    );
                                  } catch (e) {
                                    // ScaffoldMessenger.of(context).showSnackBar(
                                    //   SnackBar(content: Text('Error: ${e.toString()}')),
                                    // );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0086D6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEditableField(TextEditingController controller, String hintText) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintText: hintText,
      ),
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: _genderOptions.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedGender = newValue!;
        });
      },
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dobController,
      readOnly: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 18, color: Colors.black54),
          onPressed: () => _selectDate(context),
        ),
      ),
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      onTap: () => _selectDate(context),
    );
  }
}