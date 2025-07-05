import 'package:flutter/material.dart';
import '../../headers/company_header.dart';
import '../../headers/dashboard_headers.dart';
import '../../headers/sidebar.dart';
import '../user_dashboard/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/api_service.dart';

class CompanyNotificationSettingsPage extends StatefulWidget {
    final Map<String, dynamic> userData;

  const CompanyNotificationSettingsPage({Key? key, required this.userData}) : super(key: key);

  @override
  State<CompanyNotificationSettingsPage> createState() => _CompanyNotificationSettingsPageState();
}

class _CompanyNotificationSettingsPageState extends State<CompanyNotificationSettingsPage> {
  bool _generalNotifications = true;
  bool _activitiesNearYou = true;
  bool _bookingNotifications = true;
  bool _referralsNotifications = true;
  bool _directMessages = true;
  bool _isSidebarVisible = false;
  late SharedPreferences _preferences;
  String? logoUrl;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadCompanyData();
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

  Future<void> _loadCompanyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        var data = await ApiService.getCompanyData(token);
        if (data['companyInfo'] != null) {
          setState(() {
            logoUrl = data['companyInfo']['logo'];
          });
        }
      }
    } catch (error) {
      print('Error loading company data: $error');
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    await _preferences.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // App Header
            CompanyAppHeader(
              logoUrl: logoUrl,
              userData: widget.userData,
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
                            });
                          }
                      ),
                      _buildNotificationToggle(
                          'Booking notifications',
                          _bookingNotifications,
                              (value) {
                            setState(() {
                              _bookingNotifications = value;
                            });
                          }
                      ),
                      _buildNotificationToggle(
                          'Referrals notifications',
                          _referralsNotifications,
                              (value) {
                            setState(() {
                              _referralsNotifications = value;
                            });
                          }
                      ),
                      _buildNotificationToggle(
                          'Direct Messages',
                          _directMessages,
                              (value) {
                            setState(() {
                              _directMessages = value;
                            });
                          }
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sidebar with animation
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _isSidebarVisible ? 0 : -220,
            top: 0,
            bottom: 0,
            width: 220,
            child: Sidebar(
              onCollapse: _toggleSidebar,
              parentContext: context,
            ),
          ),

          // Overlay to close sidebar when tapping outside
          if (_isSidebarVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSidebar,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
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