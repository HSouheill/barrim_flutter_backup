import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class EnvConfig {
  // Google Maps API Key
  static String get googleMapsApiKey {
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'YOUR_API_KEY_HERE';
  }

  // Firebase Project ID
  static String get firebaseProjectId {
    return dotenv.env['FIREBASE_PROJECT_ID'] ?? 'barrim-3b45a';
  }

  // API Base URL
  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'https://barrim.online';
  }

  // Production flag
  static bool get isProduction {
    return dotenv.env['IS_PRODUCTION']?.toLowerCase() == 'true';
  }

  // Debug logging flag
  static bool get enableDebugLogging {
    return dotenv.env['ENABLE_DEBUG_LOGGING']?.toLowerCase() == 'true';
  }

  static String get whishApiBaseUrl {
//https://api.sandbox.whish.money/itel-service/api
//https://whish.money/itel-service/api/
    return dotenv.env['WHISH_API_BASE_URL'] ?? 'https://api.sandbox.whish.money/itel-service/api';
  }

  // Whish API Credentials (for backend configuration reference)
  static String get whishChannel => dotenv.env['WHISH_CHANNEL'] ?? '10196975';
  static String get whishSecret => dotenv.env['WHISH_SECRET'] ?? '024709627da343afbcd5278a5fea819e';
  static String get whishWebsiteUrl => dotenv.env['WHISH_WEBSITE_URL'] ?? 'barrim.com';

  // Validate that required environment variables are set
  static bool validateConfig() {
    final requiredVars = ['GOOGLE_MAPS_API_KEY'];
    
    for (final varName in requiredVars) {
      if (dotenv.env[varName] == null || dotenv.env[varName]!.isEmpty) {
        if (!kReleaseMode) {
          print('Warning: Required environment variable $varName is not set');
        }
        return false;
      }
    }
    
    return true;
  }
}
