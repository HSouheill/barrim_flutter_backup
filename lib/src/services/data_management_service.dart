import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/privacy_policy.dart';
import '../utils/terms_of_service.dart';

class DataManagementService {
  static final DataManagementService _instance = DataManagementService._internal();
  factory DataManagementService() => _instance;
  DataManagementService._internal();

  /// Export all user data (GDPR compliance)
  static Future<Map<String, dynamic>> exportUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final userData = {
        'personal_info': {
          'full_name': prefs.getString('full_name'),
          'email': prefs.getString('email'),
          'phone': prefs.getString('phone'),
          'date_of_birth': prefs.getString('date_of_birth'),
          'gender': prefs.getString('gender'),
        },
        'account_info': {
          'user_type': prefs.getString('user_type'),
          'created_at': prefs.getString('account_created_at'),
          'last_login': prefs.getString('last_login'),
        },
        'location_data': {
          'saved_locations': prefs.getString('saved_locations'),
          'location_preferences': prefs.getString('location_preferences'),
        },
        'app_preferences': {
          'notification_settings': prefs.getString('notification_settings'),
          'language': prefs.getString('language'),
          'theme': prefs.getString('theme'),
        },
        'export_timestamp': DateTime.now().toIso8601String(),
      };

      return userData;
    } catch (e) {
      throw Exception('Failed to export user data: $e');
    }
  }

  /// Delete all user data (GDPR compliance)
  static Future<bool> deleteAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // List of all keys to remove
      final keysToRemove = [
        'auth_token',
        'full_name',
        'email',
        'phone',
        'date_of_birth',
        'gender',
        'user_type',
        'account_created_at',
        'last_login',
        'saved_locations',
        'location_preferences',
        'notification_settings',
        'language',
        'theme',
        'user_data',
        'company_data',
        'wholesaler_info',
        'service_provider_info',
        'service_provider_data',
      ];

      // Remove all user data
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      return true;
    } catch (e) {
      throw Exception('Failed to delete user data: $e');
    }
  }

  /// Get data retention information
  static Map<String, dynamic> getDataRetentionInfo() {
    return {
      'account_data': 'Retained while account is active, deleted 30 days after account deletion',
      'location_data': 'Retained for 2 years, then anonymized',
      'usage_data': 'Retained for 1 year, then aggregated',
      'payment_data': 'Retained for 7 years (legal requirement)',
      'communication_data': 'Retained for 2 years',
    };
  }

  /// Get user consent status
  static Future<Map<String, bool>> getUserConsentStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'terms_accepted': prefs.getBool('terms_accepted') ?? false,
        'privacy_policy_accepted': prefs.getBool('privacy_policy_accepted') ?? false,
        'location_consent': prefs.getBool('location_consent') ?? false,
        'notification_consent': prefs.getBool('notification_consent') ?? false,
        'analytics_consent': prefs.getBool('analytics_consent') ?? false,
      };
    } catch (e) {
      throw Exception('Failed to get consent status: $e');
    }
  }

  /// Update user consent
  static Future<bool> updateUserConsent(String consentType, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(consentType, value);
      
      // Log consent update
      await prefs.setString('${consentType}_updated_at', DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      throw Exception('Failed to update consent: $e');
    }
  }

  /// Get privacy policy text
  static String getPrivacyPolicy() {
    return PrivacyPolicy.fullPrivacyPolicy;
  }

  /// Get terms of service text
  static String getTermsOfService() {
    return TermsOfService.fullTermsOfService;
  }

  /// Check if user has accepted all required consents
  static Future<bool> hasRequiredConsents() async {
    try {
      final consentStatus = await getUserConsentStatus();
      
      return consentStatus['terms_accepted'] == true &&
             consentStatus['privacy_policy_accepted'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Request data deletion (GDPR right to be forgotten)
  static Future<bool> requestDataDeletion() async {
    try {
      // First, delete local data
      await deleteAllUserData();
      
      // TODO: Implement server-side data deletion
      // This should call your backend API to delete user data from the server
      
      return true;
    } catch (e) {
      throw Exception('Failed to request data deletion: $e');
    }
  }

  /// Get data processing information
  static Map<String, dynamic> getDataProcessingInfo() {
    return {
      'legal_basis': [
        'Consent (for optional features)',
        'Contract performance (for core services)',
        'Legitimate interests (for app improvement)',
        'Legal obligations (for compliance)'
      ],
      'data_categories': [
        'Personal identification data',
        'Contact information',
        'Location data',
        'Usage analytics',
        'Device information'
      ],
      'third_party_services': [
        'Firebase (analytics and notifications)',
        'Google Maps (location services)',
        'Payment processors (if applicable)'
      ]
    };
  }
}
