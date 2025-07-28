import 'package:flutter/material.dart';
import '../../headers/company_header.dart';
import '../../headers/dashboard_headers.dart';
import '../../headers/sidebar.dart';
import '../user_dashboard/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../headers/wholesaler_header.dart';
import '../../../../services/wholesaler_service.dart';
import '../../../../services/api_service.dart';

class WholesalerNotificationSettingsPage extends StatefulWidget {
  const WholesalerNotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<WholesalerNotificationSettingsPage> createState() => _WholesalerNotificationSettingsPageState();
}

class _WholesalerNotificationSettingsPageState extends State<WholesalerNotificationSettingsPage> {
  bool _generalNotifications = true;
  bool _activitiesNearYou = true;
  bool _bookingNotifications = true;
  bool _referralsNotifications = true;
  bool _directMessages = true;
  bool _isSidebarVisible = false;
  late SharedPreferences _preferences;
  String? _logoUrl;
  final WholesalerService _wholesalerService = WholesalerService();


  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadWholesalerLogo();
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

  Future<void> _loadWholesalerLogo() async {
    try {
      final wholesalerData = await _wholesalerService.getWholesalerData();
      if (wholesalerData != null && mounted) {
        // Convert logo URL to full URL if it's a relative path
        String? logoUrl = wholesalerData.logoUrl;
        if (logoUrl != null && logoUrl.isNotEmpty) {
          // If it's a relative path, convert to full URL
          if (logoUrl.startsWith('/') || logoUrl.startsWith('uploads/')) {
            logoUrl = '${ApiService.baseUrl}/$logoUrl';
          }
          // If it starts with file://, remove it and convert to full URL
          else if (logoUrl.startsWith('file://')) {
            logoUrl = logoUrl.replaceFirst('file://', '');
            if (logoUrl.startsWith('/')) {
              logoUrl = '${ApiService.baseUrl}$logoUrl';
            } else {
              logoUrl = '${ApiService.baseUrl}/$logoUrl';
            }
          }
        }
        setState(() {
          _logoUrl = logoUrl;
        });
      }
    } catch (e) {
      print('Error loading wholesaler logo: $e');
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
            WholesalerHeader(logoUrl: _logoUrl, userData: {}),


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