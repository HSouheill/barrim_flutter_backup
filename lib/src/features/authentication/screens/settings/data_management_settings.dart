import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/data_management_service.dart';
import '../../../../utils/privacy_policy.dart';
import '../../../../utils/terms_of_service.dart';

class DataManagementSettings extends StatefulWidget {
  const DataManagementSettings({Key? key}) : super(key: key);

  @override
  State<DataManagementSettings> createState() => _DataManagementSettingsState();
}

class _DataManagementSettingsState extends State<DataManagementSettings> {
  bool _isLoading = false;
  Map<String, bool> _consentStatus = {};

  @override
  void initState() {
    super.initState();
    _loadConsentStatus();
  }

  Future<void> _loadConsentStatus() async {
    try {
      final status = await DataManagementService.getUserConsentStatus();
      setState(() {
        _consentStatus = status;
      });
    } catch (e) {
      print('Error loading consent status: $e');
    }
  }

  Future<void> _updateConsent(String consentType, bool value) async {
    try {
      await DataManagementService.updateUserConsent(consentType, value);
      await _loadConsentStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Consent updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update consent: $e')),
      );
    }
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await DataManagementService.exportUserData();
      
      // Show data export dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Your Data Export'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your data has been exported successfully.'),
                  const SizedBox(height: 16),
                  Text('Data includes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...data.entries.map((entry) => Text('• ${entry.key}')),
                  const SizedBox(height: 16),
                  Text('Export timestamp: ${data['export_timestamp']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete All Data'),
        content: Text(
          'This action will permanently delete all your data from this app. '
          'This action cannot be undone. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      try {
        await DataManagementService.requestDataDeletion();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('All data deleted successfully')),
          );
          
          // Navigate back to login screen
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete data: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Text(PrivacyPolicy.fullPrivacyPolicy),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terms of Service'),
        content: SingleChildScrollView(
          child: Text(TermsOfService.fullTermsOfService),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Management'),
        backgroundColor: const Color(0xFF05054F),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Privacy Policy & Terms
                  _buildSection(
                    'Legal Documents',
                    [
                      _buildListTile(
                        'Privacy Policy',
                        'View our complete privacy policy',
                        Icons.privacy_tip,
                        onTap: _showPrivacyPolicy,
                      ),
                      _buildListTile(
                        'Terms of Service',
                        'View our terms of service',
                        Icons.description,
                        onTap: _showTermsOfService,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Consent Management
                  _buildSection(
                    'Consent Management',
                    [
                      _buildSwitchTile(
                        'Terms Accepted',
                        'Accept terms of service',
                        _consentStatus['terms_accepted'] ?? false,
                        (value) => _updateConsent('terms_accepted', value),
                      ),
                      _buildSwitchTile(
                        'Privacy Policy Accepted',
                        'Accept privacy policy',
                        _consentStatus['privacy_policy_accepted'] ?? false,
                        (value) => _updateConsent('privacy_policy_accepted', value),
                      ),
                      _buildSwitchTile(
                        'Location Consent',
                        'Allow location access',
                        _consentStatus['location_consent'] ?? false,
                        (value) => _updateConsent('location_consent', value),
                      ),
                      _buildSwitchTile(
                        'Notification Consent',
                        'Allow notifications',
                        _consentStatus['notification_consent'] ?? false,
                        (value) => _updateConsent('notification_consent', value),
                      ),
                      _buildSwitchTile(
                        'Analytics Consent',
                        'Allow analytics collection',
                        _consentStatus['analytics_consent'] ?? false,
                        (value) => _updateConsent('analytics_consent', value),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Data Rights
                  _buildSection(
                    'Your Data Rights',
                    [
                      _buildListTile(
                        'Export My Data',
                        'Download all your data',
                        Icons.download,
                        onTap: _exportData,
                      ),
                      _buildListTile(
                        'Delete All Data',
                        'Permanently delete your data',
                        Icons.delete_forever,
                        onTap: _deleteData,
                        isDestructive: true,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Data Retention Info
                  _buildSection(
                    'Data Retention',
                    DataManagementService.getDataRetentionInfo().entries.map((entry) =>
                      _buildInfoTile(entry.key, entry.value)
                    ).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF05054F),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile(String title, String subtitle, IconData icon, {
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : const Color(0xFF05054F),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF05054F),
    );
  }

  Widget _buildInfoTile(String title, String info) {
    return ListTile(
      title: Text(
        title.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
      subtitle: Text(info),
      dense: true,
    );
  }
}
