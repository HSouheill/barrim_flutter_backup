// lib/utils/api_constants.dart
import 'package:barrim/src/services/api_service.dart';

class ApiConstants {
  // Base URL for your API
  static const String baseUrl = ApiService.baseUrl;  // Replace with your actual API base URL

  // Endpoint paths
  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String googleAuthEndpoint = '/api/auth/google-auth-without-firebase';
  static const String companyDataEndpoint = '/api/companies/data';
  static const String companyProfileEndpoint = '/api/companies/profile';
  static const String companyLogoEndpoint = '/api/companies/logo';
  static const String branchesEndpoint = '/api/companies/branches';
  static const String serviceProviderCategoriesEndpoint = '/api/service-provider-categories';
}