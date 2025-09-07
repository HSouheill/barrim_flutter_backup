# Security Configuration Guide

## Environment Variables Required

Create a `.env` file in the project root with the following variables:

```bash
# Google Maps API Key
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here

# Firebase Configuration  
FIREBASE_PROJECT_ID=your_firebase_project_id_here

# API Configuration
API_BASE_URL=https://barrim.online

# Security Configuration
CERTIFICATE_PIN_SHA256=your_certificate_pin_here

# Development/Production flags
IS_PRODUCTION=false
ENABLE_DEBUG_LOGGING=false
```

## Android Configuration

1. Update `android/app/build.gradle` to use environment variables:
```gradle
android {
    defaultConfig {
        buildConfigField "String", "GOOGLE_MAPS_API_KEY", "\"${System.getenv('GOOGLE_MAPS_API_KEY')}\""
    }
}
```

2. Update `android/app/src/main/res/values/config.xml`:
```xml
<string name="google_maps_api_key">${GOOGLE_MAPS_API_KEY}</string>
```

## iOS Configuration

1. Update `ios/Runner/Config.plist`:
```xml
<key>GoogleMapsAPIKey</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

## Certificate Pinning

1. Generate your server's certificate pin:
```bash
openssl s_client -servername barrim.online -connect barrim.online:443 | openssl x509 -pubkey -noout | openssl rsa -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
```

2. Update `android/app/src/main/res/xml/network_security_config.xml` with the generated pin.

## Security Checklist

- [ ] Remove hardcoded API keys from config files
- [ ] Implement certificate pinning
- [ ] Remove sensitive data from debug logs
- [ ] Add input validation to all API endpoints
- [ ] Implement proper token validation
- [ ] Use environment variables for sensitive configuration
- [ ] Enable network security config
- [ ] Remove debug information from production builds
