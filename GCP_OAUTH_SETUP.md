# GCP OAuth 2.0 Setup Guide

This guide will help you set up Google Cloud Platform OAuth 2.0 authentication for your Flutter app, replacing the previous Firebase authentication.

## Prerequisites

1. A Google Cloud Platform account
2. A GCP project
3. Flutter development environment set up

## Step 1: Create GCP Project and Enable APIs

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Google+ API (for user profile information)
   - Google Identity API (for OAuth 2.0)

## Step 2: Create OAuth 2.0 Credentials

1. Navigate to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth 2.0 Client IDs**
3. Create credentials for each platform:

### Android Configuration
1. Select **Android** as the application type
2. Enter your package name: `com.Barrim.AppBarrim`
3. Get your SHA-1 fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Look for the SHA1 fingerprint in the debug keystore section
4. Enter the SHA-1 fingerprint
5. Click **Create**
6. Copy the generated Client ID

### iOS Configuration
1. Select **iOS** as the application type
2. Enter your bundle ID: `com.Barrim.AppBarrim`
3. Click **Create**
4. Copy the generated Client ID

### Web Configuration (Optional)
1. Select **Web application** as the application type
2. Add authorized redirect URIs if needed
3. Click **Create**
4. Copy the generated Client ID

## Step 3: Update Flutter Configuration

1. Open `lib/src/config/gcp_config.dart`
2. Replace the placeholder values with your actual client IDs:

```dart
class GCPConfig {
  static const String androidClientId = 'YOUR_ACTUAL_ANDROID_CLIENT_ID.apps.googleusercontent.com';
  static const String iosClientId = 'YOUR_ACTUAL_IOS_CLIENT_ID.apps.googleusercontent.com';
  static const String webClientId = 'YOUR_ACTUAL_WEB_CLIENT_ID.apps.googleusercontent.com';
  static const String projectId = 'YOUR_GCP_PROJECT_ID';
}
```

## Step 4: Update Android Configuration

1. Remove Firebase configuration files:
   - Delete `android/app/google-services.json`
   - Remove Firebase plugin from `android/app/build.gradle`

2. The Android configuration is already updated in `android/app/build.gradle` to use GCP OAuth instead of Firebase.

## Step 5: Update iOS Configuration

1. Remove Firebase configuration files:
   - Delete `ios/GoogleService-Info.plist`

2. Update `ios/Runner/Info.plist` to use GCP OAuth URLs:
   - Replace the Firebase URL scheme with your GCP OAuth URL scheme
   - The URL scheme should be: `com.googleusercontent.apps.YOUR_CLIENT_ID`

## Step 6: Test the Implementation

1. Run the app on Android/iOS
2. Try the Google Sign-In functionality
3. Check the logs for any configuration errors

## Troubleshooting

### Common Issues

1. **"DEVELOPER_ERROR"**: Usually means the client ID is incorrect or the SHA-1 fingerprint doesn't match
2. **"SIGN_IN_FAILED"**: Check that the OAuth consent screen is properly configured
3. **"Network error"**: Ensure the device has internet connectivity

### Debug Steps

1. Check that your client IDs are correctly set in `gcp_config.dart`
2. Verify the SHA-1 fingerprint matches what's configured in GCP Console
3. Ensure the package name/bundle ID matches exactly
4. Check the OAuth consent screen configuration in GCP Console

## Migration from Firebase

The migration from Firebase to GCP OAuth is complete. The main changes are:

1. ✅ Removed Firebase dependencies from `pubspec.yaml`
2. ✅ Removed Firebase initialization from `main.dart`
3. ✅ Created new GCP OAuth service (`gcp_google_auth_service.dart`)
4. ✅ Updated Android configuration to remove Firebase
5. ✅ Updated iOS configuration to remove Firebase
6. ✅ Updated login/signup pages to use new service

## Backend Integration

The backend integration remains the same. The app still sends the Google ID token to your existing endpoint:
- Endpoint: `/api/auth/google-auth-without-firebase`
- The backend can verify the token using Google's OAuth 2.0 token verification

## Security Notes

1. Keep your client IDs secure and don't commit them to public repositories
2. Use environment variables for sensitive configuration in production
3. Regularly rotate your OAuth credentials
4. Monitor OAuth usage in the GCP Console

## Support

If you encounter issues:
1. Check the GCP Console for any error messages
2. Review the Flutter logs for detailed error information
3. Ensure all configuration steps were followed correctly
