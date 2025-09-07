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
