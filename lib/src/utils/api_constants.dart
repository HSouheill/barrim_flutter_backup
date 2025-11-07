// lib/utils/api_constants.dart
import 'package:barrim/src/services/api_service.dart';

class ApiConstants {
  // Base URL for your API
  static const String baseUrl = ApiService.baseUrl;  // Replace with your actual API base URL

  // Whish Money Payment API URLs
  // Note: These URLs are for backend configuration reference only
  // The frontend receives the payment URL (collectUrl) from the backend
  static const String whishApiBaseUrlProduction = 'https://whish.money/itel-service/api/';
  static const String whishApiBaseUrlSandbox = 'https://api.sandbox.whish.money/itel-service/api/';
  
  // Default to sandbox for testing
  static const String whishApiBaseUrl = whishApiBaseUrlSandbox;
  
  // Whish API Endpoints (for backend reference)
  static const String whishPaymentEndpoint = '/payment/whish';
  static const String whishPaymentStatusEndpoint = '/payment/collect/status';
  static const String whishBalanceEndpoint = '/payment/account/balance';
  static const String whishRateEndpoint = '/payment/whish/rate';

  // Whish Money API Headers (for backend configuration)
  // IMPORTANT: These headers must be added to ALL Whish API requests on the backend
  // Required headers format:
  //   channel: "10196975"
  //   secret: "024709627da343afbcd5278a5fea819e"
  //   websiteurl: "barrim.com" (NOTE: Use domain only, NOT "https://barrim.com")
  //   Content-Type: "application/json"
  //
  // TROUBLESHOOTING:
  // If you get "auth.session_not_exist" error:
  // 1. Verify credentials (channel, secret) are correct and active with Whish
  // 2. Ensure websiteurl is "barrim.com" (domain only, no protocol or path)
  // 3. Check if Whish account requires initial setup/activation
  // 4. Contact Whish support to verify account status and credentials
  static const String whishChannel = '10196975';
  static const String whishSecret = '024709627da343afbcd5278a5fea819e';
  static const String whishWebsiteUrl = 'barrim.com'; // Domain only, no https://

  /// Get Whish API headers (for backend reference/implementation)
  /// Returns a map of headers that should be included in all Whish API requests
  static Map<String, String> getWhishHeaders() {
    return {
      'channel': whishChannel,
      'secret': whishSecret,
      'websiteurl': whishWebsiteUrl,
      'Content-Type': 'application/json',
    };
  }

  // Endpoint paths
  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String googleAuthEndpoint = '/api/auth/google-auth-without-firebase';
  static const String companyDataEndpoint = '/api/companies/data';
  static const String companyProfileEndpoint = '/api/companies/profile';
  static const String companyLogoEndpoint = '/api/companies/logo';
  static const String branchesEndpoint = '/api/companies/branches';
  static const String serviceProviderCategoriesEndpoint = '/api/service-provider-categories';

  // Deep linking URLs for payment redirects (for backend configuration)
  // These URLs should be used in Whish payment success/failure redirect URLs
  // Format: barrim://payment-success?requestId={requestId}
  // Or: https://barrim.online/payment-success?requestId={requestId}
  // NOTE: The app scheme (barrim://) will redirect to the mobile app
  // The web URL (https://barrim.online) will also redirect to the app if installed
  
  /// Generate payment success redirect URL with app scheme
  /// Backend should use this in Whish payment redirect URL for successful payments
  static String getPaymentSuccessUrl(String requestId) {
    return 'barrim://payment-success?requestId=$requestId';
  }
  
  /// Generate payment failed redirect URL with app scheme
  /// Backend should use this in Whish payment redirect URL for failed payments
  static String getPaymentFailedUrl(String requestId) {
    return 'barrim://payment-failed?requestId=$requestId';
  }
  
  /// Generate payment success redirect URL with web scheme (fallback)
  /// Will also trigger deep link if app is installed
  static String getPaymentSuccessWebUrl(String requestId) {
    return 'https://barrim.online/payment-success?requestId=$requestId';
  }
  
  /// Generate payment failed redirect URL with web scheme (fallback)
  /// Will also trigger deep link if app is installed
  static String getPaymentFailedWebUrl(String requestId) {
    return 'https://barrim.online/payment-failed?requestId=$requestId';
  }
}