// lib/utils/constants.dart
import 'package:barrim/src/services/api_service.dart';

class ApiConstants {
  // Base URL for your API
  static const String baseUrl = ApiService.baseUrl; // Replace with your actual API URL

  // API endpoints
  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String companyEndpoint = '/api/companies';
  static const String subscriptionEndpoint = '/api/companies/subscription-plans';

  // Subscription types
  static const String companySubscriptionType = 'company';
  static const String wholesalerSubscriptionType = 'wholesaler';
  static const String serviceProviderSubscriptionType = 'service_provider';

  // Subscription statuses
  static const String activeStatus = 'active';
  static const String expiredStatus = 'expired';
  static const String cancelledStatus = 'cancelled';
  static const String pendingStatus = 'pending';
  static const String approvedStatus = 'approved';
  static const String rejectedStatus = 'rejected';

  // File upload limits
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  // Request timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);
}

class StorageKeys {
  static const String authToken = 'auth_token';
  static const String userId = 'user_id';
  static const String userType = 'user_type';
  static const String companyId = 'company_id';
  static const String refreshToken = 'refresh_token';
}

class AppStrings {
  // Subscription related strings
  static const String subscriptionPlans = 'Subscription Plans';
  static const String currentSubscription = 'Current Subscription';
  static const String subscriptionHistory = 'Subscription History';
  static const String renewSubscription = 'Renew Subscription';
  static const String cancelSubscription = 'Cancel Subscription';
  static const String upgradeSubscription = 'Upgrade Subscription';

  // Status messages
  static const String subscriptionActive = 'Your subscription is active';
  static const String subscriptionExpired = 'Your subscription has expired';
  static const String subscriptionExpiringSoon = 'Your subscription is expiring soon';
  static const String noActiveSubscription = 'No active subscription';

  // Error messages
  static const String networkError = 'Network error occurred';
  static const String serverError = 'Server error occurred';
  static const String invalidCredentials = 'Invalid credentials';
  static const String sessionExpired = 'Session expired. Please login again';
  static const String fileUploadError = 'Failed to upload file';
  static const String invalidFileType = 'Invalid file type';
  static const String fileTooLarge = 'File size is too large';

  // Success messages
  static const String subscriptionCreated = 'Subscription request created successfully';
  static const String subscriptionCancelled = 'Subscription cancelled successfully';
  static const String profileUpdated = 'Profile updated successfully';
  static const String fileUploaded = 'File uploaded successfully';
}