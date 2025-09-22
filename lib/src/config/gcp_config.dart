/// GCP OAuth 2.0 Configuration
/// 
/// This file contains the configuration for Google Cloud Platform OAuth 2.0
/// authentication. Replace the placeholder values with your actual GCP OAuth
/// client IDs from the Google Cloud Console.
class GCPConfig {
  // GCP OAuth 2.0 Client IDs
  // Get these from: https://console.cloud.google.com/apis/credentials
  
  /// Android OAuth 2.0 Client ID
  /// Format: YOUR_CLIENT_ID.apps.googleusercontent.com
  static const String androidClientId = '307776183600-p4ra4n80v0tajt573n8q5t4a684c0sn6.apps.googleusercontent.com';
  
  /// iOS OAuth 2.0 Client ID  
  /// Format: YOUR_CLIENT_ID.apps.googleusercontent.com
  static const String iosClientId = '307776183600-aoags2ect1p5i6rmebgsltb9ipsfin86.apps.googleusercontent.com';
  
  /// Web OAuth 2.0 Client ID (if needed)
  /// Format: YOUR_CLIENT_ID.apps.googleusercontent.com
  static const String webClientId = '307776183600-d8bs7uhqt4g5dar0u48hnmrpbc4ke8ft.apps.googleusercontent.com';
  
  /// GCP Project ID
  static const String projectId = 'barrim-3b45a';
  
  /// OAuth 2.0 Scopes
  static const List<String> scopes = [
    'email',
    'profile',
    'openid',
  ];
  
  /// Get the appropriate client ID for the current platform
  static String getClientId() {
    // This will be determined at runtime based on the platform
    // The actual client ID will be set in the GCPGoogleSignInProvider
    return 'PLATFORM_SPECIFIC_CLIENT_ID';
  }
}
