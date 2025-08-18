import 'package:flutter/material.dart';
import '../../headers/dashboard_headers.dart';
import '../user_dashboard/notification.dart' as notification;
import '../user_dashboard/home.dart';
import '../category/categories.dart';
import '../workers/worker_home.dart';
import '../booking/myboooking.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/api_service.dart';
import 'package:barrim/src/utils/authService.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _generalNotifications = true;
  bool _activitiesNearYou = true;
  bool _bookingNotifications = true;
  bool _referralsNotifications = true;
  bool _directMessages = true;
  bool _isSidebarOpen = false;
  late SharedPreferences _preferences;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadUserProfileImage();
  }

  Future<void> _loadPreferences() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _generalNotifications = _preferences.getBool('general_notifications') ?? true;
      _activitiesNearYou = _preferences.getBool('activities_near_you') ?? true;
      _bookingNotifications = _preferences.getBool('booking_notifications') ?? true;
      _referralsNotifications = _preferences.getBool('referrals_notifications') ?? true;
      _directMessages = _preferences.getBool('direct_messages') ?? true;
    });
  }

  Future<void> _loadUserProfileImage() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData['profilePic'] != null && userData['profilePic'].toString().isNotEmpty) {
        String profilePic = userData['profilePic'];
        // Construct the full URL
        if (profilePic.startsWith('http')) {
          _profileImagePath = profilePic;
        } else {
          if (ApiService.baseUrl.endsWith('/') && profilePic.startsWith('/')) {
            _profileImagePath = '${ApiService.baseUrl}${profilePic.substring(1)}';
          } else if (!ApiService.baseUrl.endsWith('/') && !profilePic.startsWith('/')) {
            _profileImagePath = '${ApiService.baseUrl}/$profilePic';
          } else {
            _profileImagePath = '${ApiService.baseUrl}$profilePic';
          }
        }
      }
    } catch (e) {
      print('Error loading user profile image: $e');
    }
    setState(() {});
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    await _preferences.setBool(key, value);
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // App Header
              AppHeader(
                profileImagePath: _profileImagePath ?? '',
                onMenuTap: _toggleSidebar,
                onNotificationTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => notification.NotificationsPage(),
                    ),
                  );
                },
              ),

              // Back button and page title
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.arrow_back, color: Color(0xFF2079C2)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10105D),
                      ),
                    ),
                  ],
                ),
              ),

              // Notification Settings Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildNotificationToggle(
                          'General Notifications',
                          _generalNotifications,
                              (value) {
                            setState(() {
                              _generalNotifications = value;
                              _savePreference('general_notifications', value);
                            });
                          }
                      ),
                      _buildNotificationToggle(
                          'Activities near you',
                          _activitiesNearYou,
                              (value) {
                            setState(() {
                              _activitiesNearYou = value;
                              _savePreference('activities_near_you', value);
                            });
                          }
                      ),
                      _buildNotificationToggle(
                          'Booking notifications',
                          _bookingNotifications,
                              (value) {
                            setState(() {
                              _bookingNotifications = value;
                              _savePreference('booking_notifications', value);
                            });
                          }
                      ),
                      _buildNotificationToggle(
                          'Referrals notifications',
                          _referralsNotifications,
                              (value) {
                            setState(() {
                              _referralsNotifications = value;
                              _savePreference('referrals_notifications', value);
                            });
                          }
                      ),
                      _buildNotificationToggle(
                          'Direct Messages',
                          _directMessages,
                              (value) {
                            setState(() {
                              _directMessages = value;
                              _savePreference('direct_messages', value);
                            });
                          }
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

  Widget _buildNotificationToggle(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.blue,
          ),
        ],
      ),
    );
  }
}