import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../components/secure_network_image.dart';
import '../../../../utils/authService.dart';
import '../user_dashboard/notification.dart';
import '../user_dashboard/home.dart';
import '../workers/worker_home.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import '../../screens/category/wholesaler_categories.dart';

class ServiceProviderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> provider;

  const ServiceProviderDetailsPage({
    Key? key,
    required this.provider,
  }) : super(key: key);

  @override
  _ServiceProviderDetailsPageState createState() => _ServiceProviderDetailsPageState();
}

class _ServiceProviderDetailsPageState extends State<ServiceProviderDetailsPage> {
  bool _isSidebarOpen = false;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData['profilePic'] != null) {
        setState(() {
          _profileImagePath = ApiService.getImageUrl(userData['profilePic']);
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
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
                  },
                ),
                ListTile(
                  leading: Icon(Icons.store, color: Colors.white),
                  title: Text('Wholesalers', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const WholesalerCategoriesPage()),
                      );
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.white),
                  title: Text('Service Providers', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _toggleSidebar();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const DriversGuidesPage()),
                      );
                    });
                  },
                ),
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
  Widget build(BuildContext context) {
    final fullName = _safeStringFromDynamic(widget.provider['fullName']);
    final businessName = _safeStringFromDynamic(widget.provider['businessName']);
    final name = fullName.isNotEmpty ? fullName : 
                 (businessName.isNotEmpty ? businessName : 'Unknown Provider');
    final serviceType = _safeStringFromDynamic(widget.provider['serviceType']);
    final finalServiceType = serviceType.isNotEmpty ? serviceType : 'Service Provider';
    final yearsExperience = widget.provider['yearsExperience'] ?? 0;
    final isVerified = widget.provider['isVerified'] ?? false;
    final rating = widget.provider['rating'] ?? 0.0;
    final description = _safeStringFromDynamic(widget.provider['description']);
    final availableHours = _safeStringFromDynamic(widget.provider['availableHours']);
    final availableDays = _safeStringFromDynamic(widget.provider['availableDays']);
    final contactInfo = widget.provider['contactInfo'] ?? {};

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Header
              ServiceProviderDetailsHeader(
                onBackPressed: () => Navigator.pop(context),
                onMenuTap: _toggleSidebar,
                profileImagePath: _profileImagePath,
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider info card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Profile image and basic info
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildProfileImage(),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isVerified)
                                              Icon(
                                                Icons.verified,
                                                color: Colors.blue,
                                                size: 24,
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          finalServiceType,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (rating > 0) ...[
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.star, size: 18, color: Colors.amber),
                                              SizedBox(width: 4),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Experience card
                      if (yearsExperience > 0)
                        _buildInfoCard(
                          icon: Icons.work,
                          title: 'Experience',
                          content: '$yearsExperience years of experience',
                        ),

                      // Available hours card
                      if (availableHours.isNotEmpty)
                        _buildInfoCard(
                          icon: Icons.access_time,
                          title: 'Available Hours',
                          content: availableHours,
                        ),

                      // Available days card
                      if (availableDays.isNotEmpty)
                        _buildInfoCard(
                          icon: Icons.calendar_today,
                          title: 'Available Days',
                          content: availableDays,
                        ),

                      // Description card
                      if (description.isNotEmpty)
                        _buildInfoCard(
                          icon: Icons.description,
                          title: 'About',
                          content: description,
                        ),

                      // Contact info card
                      if (contactInfo.isNotEmpty)
                        _buildInfoCard(
                          icon: Icons.contact_phone,
                          title: 'Contact Information',
                          content: _formatContactInfo(contactInfo),
                        ),

                      SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement contact functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Contact functionality coming soon')),
                                );
                              },
                              icon: Icon(Icons.phone),
                              label: Text('Contact'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement booking functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Booking functionality coming soon')),
                                );
                              },
                              icon: Icon(Icons.book_online),
                              label: Text('Book Service'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

  Widget _buildProfileImage() {
    final profilePic = widget.provider['profilePic'];
    
    if (profilePic != null && profilePic.toString().isNotEmpty) {
      final imageUrl = ApiService.getImageUrl(profilePic.toString());
      return SecureNetworkImage(
        imageUrl: imageUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: Container(
          width: 80,
          height: 80,
          color: Colors.grey[300],
          child: Icon(Icons.person, color: Colors.grey[600], size: 40),
        ),
        errorWidget: (context, url, error) => Container(
          width: 80,
          height: 80,
          color: Colors.grey[300],
          child: Icon(Icons.person, color: Colors.grey[600], size: 40),
        ),
      );
    }
    
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: Icon(Icons.person, color: Colors.grey[600], size: 40),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _safeStringFromDynamic(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) return value.join(', ');
    return value.toString();
  }

  String _formatContactInfo(Map<String, dynamic> contactInfo) {
    List<String> contactItems = [];
    
    // Handle phone - could be String or List
    if (contactInfo['phone'] != null) {
      final phone = contactInfo['phone'];
      if (phone is List) {
        contactItems.add('Phone: ${phone.join(', ')}');
      } else {
        contactItems.add('Phone: $phone');
      }
    }
    
    // Handle email - could be String or List
    if (contactInfo['email'] != null) {
      final email = contactInfo['email'];
      if (email is List) {
        contactItems.add('Email: ${email.join(', ')}');
      } else {
        contactItems.add('Email: $email');
      }
    }
    
    // Handle address - could be String or List
    if (contactInfo['address'] != null) {
      final address = contactInfo['address'];
      if (address is List) {
        contactItems.add('Address: ${address.join(', ')}');
      } else {
        contactItems.add('Address: $address');
      }
    }
    
    return contactItems.join('\n');
  }
}

class ServiceProviderDetailsHeader extends StatelessWidget {
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuTap;
  final String? profileImagePath;

  const ServiceProviderDetailsHeader({
    Key? key,
    this.onBackPressed,
    this.onMenuTap,
    this.profileImagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF2079C2),
            Color(0xFF1F4889),
            Color(0xFF10105D),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: onBackPressed,
          ),
          Image.asset('assets/logo/barrim_logo.png', height: 50, width: 40),
          Spacer(),
          CircleAvatar(
            backgroundColor: Colors.blue,
            backgroundImage: (profileImagePath != null && profileImagePath!.startsWith('http'))
                ? null
                : null,
            radius: 18,
            child: (profileImagePath != null && profileImagePath!.startsWith('http'))
                ? ClipOval(
                    child: SecureNetworkImage(
                      imageUrl: profileImagePath!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      placeholder: Icon(Icons.person, color: Colors.white),
                      errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.white),
                    ),
                  )
                : Icon(Icons.person, color: Colors.white),
          ),
          SizedBox(width: 12),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsPage(),
                ),
              );
            },
            child: Icon(
              Icons.notifications,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.menu,
              color: Colors.white,
              size: 28,
            ),
            onPressed: onMenuTap,
          ),
        ],
      ),
    );
  }
}
