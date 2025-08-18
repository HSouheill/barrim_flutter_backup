import 'package:barrim/src/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../../models/notification_model.dart';
import '../../headers/dashboard_headers.dart';
import '../user_dashboard/home.dart';
import '../category/categories.dart';
import '../workers/worker_home.dart';
import '../booking/myboooking.dart';
import '../referrals/user_referral.dart';
import '../settings/settings.dart';
import '../login_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isSidebarOpen = false;
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      setState(() {
        if (userData['profilePic'] != null && userData['profilePic'].toString().isNotEmpty) {
          String profilePic = userData['profilePic'];
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
          print('Profile Image Path: $_profileImagePath');
        } else {
          _profileImagePath = null;
          print('No profile picture available');
        }
      });
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _profileImagePath = null;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final notifications = await ApiService.fetchNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
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
                      onTap: () {
                        _toggleSidebar();
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
              // Use the AppHeader with profile image path
              AppHeader(
                profileImagePath: _profileImagePath,
                onNotificationTap: () {},
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

              // Title section with centered text and blue lines
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.blue, width: 1),
                    bottom: BorderSide(color: Colors.blue, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.blue,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
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

              // Notifications list
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                    ? Center(child: Text('No notifications'))
                    : _buildNotificationsList(),
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

  Widget _buildNotificationsList() {
    // Group notifications by time period
    Map<String, List<NotificationModel>> groupedNotifications = _groupNotificationsByPeriod(_notifications);

    return ListView(
      children: groupedNotifications.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(entry.key),
            ...entry.value.map((notification) => _buildNotificationItem(notification)).toList(),
          ],
        );
      }).toList(),
    );
  }

  Map<String, List<NotificationModel>> _groupNotificationsByPeriod(List<NotificationModel> notifications) {
    final now = DateTime.now();
    Map<String, List<NotificationModel>> grouped = {
      'Today': [],
      'Yesterday': [],
      'This week': [],
      'Earlier': [],
    };

    for (var notification in notifications) {
      final diff = now.difference(notification.createdAt);

      if (diff.inDays == 0) {
        grouped['Today']!.add(notification);
      } else if (diff.inDays == 1) {
        grouped['Yesterday']!.add(notification);
      } else if (diff.inDays <= 7) {
        grouped['This week']!.add(notification);
      } else {
        grouped['Earlier']!.add(notification);
      }
    }

    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Profile image (placeholder for now)
          CircleAvatar(
            backgroundColor: Colors.blue,
            radius: 24,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),

          // Notification content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  notification.message,
                  style: TextStyle(
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Time ago
          Text(
            _formatTimeAgo(notification.createdAt),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return '1d ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }
}