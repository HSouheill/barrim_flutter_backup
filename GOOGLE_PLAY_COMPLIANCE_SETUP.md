# Google Play Store Compliance Setup Guide

## 🚨 **CRITICAL: Before Publishing**

This guide will help you make your Barrim app compliant with Google Play Store policies. Follow these steps carefully to avoid rejection.

## 🔐 **Step 1: Secure Your API Keys**

### 1.1 Update Configuration Files

**Android (`android/app/src/main/res/values/config.xml`):**
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Replace with your actual Google Maps API key -->
    <string name="google_maps_api_key">YOUR_ACTUAL_API_KEY_HERE</string>
    
    <!-- Replace with your actual Firebase project ID -->
    <string name="firebase_project_id">YOUR_PROJECT_ID_HERE</string>
</resources>
```

**iOS (`ios/Runner/Config.plist`):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Replace with your actual Google Maps API key -->
    <key>GoogleMapsAPIKey</key>
    <string>YOUR_ACTUAL_API_KEY_HERE</string>
    
    <!-- Replace with your actual Firebase project ID -->
    <key>FirebaseProjectID</key>
    <string>YOUR_PROJECT_ID_HERE</string>
</dict>
</plist>
```

### 1.2 Get Your API Keys

1. **Google Maps API Key:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing
   - Enable Maps SDK for Android/iOS
   - Create credentials (API key)
   - Restrict the key to your app's package name

2. **Firebase Project ID:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or select existing
   - Note the project ID from project settings

### 1.3 Update Your Backend

Ensure your backend API (`barrim.online`) uses HTTPS and has proper security measures.

## 🛡️ **Step 2: Update Privacy Policy & Terms**

### 2.1 Customize Privacy Policy

Edit `lib/src/utils/privacy_policy.dart` and update:
- Your business address
- Contact phone number
- Specific data collection practices
- Data retention periods

### 2.2 Customize Terms of Service

Edit `lib/src/utils/terms_of_service.dart` and update:
- Your jurisdiction
- Business address
- Contact information
- Specific service terms

### 2.3 Create Privacy Policy Web Page

Create a public webpage with your privacy policy accessible at:
`https://barrim.online/privacy-policy`

## 📱 **Step 3: Test Your App**

### 3.1 Test Data Export/Deletion

1. Build and install your app
2. Navigate to Settings → Data Management
3. Test "Export My Data" functionality
4. Test "Delete All Data" functionality
5. Verify consent management works

### 3.2 Test Location Permissions

1. Ensure background location is NOT requested
2. Test location access only when app is in use
3. Verify location permission dialogs are clear

### 3.3 Test Network Security

1. Verify all API calls use HTTPS
2. Test that HTTP requests are blocked
3. Verify API key security

## 📋 **Step 4: Google Play Console Setup**

### 4.1 App Content Rating

Answer the content rating questionnaire honestly:
- **Violence:** No
- **Sexual Content:** No  
- **Language:** No
- **Controlled Substances:** No
- **User Generated Content:** Yes (reviews, comments)

### 4.2 Privacy Policy

1. Upload your privacy policy document
2. Ensure it covers all data collection
3. Include GDPR compliance information
4. Add data deletion instructions

### 4.3 App Permissions

Justify each permission:
- **Location:** "Used to show nearby businesses and provide location-based services"
- **Camera:** "Used to take photos for company logos and profile pictures"
- **Storage:** "Used to save app data and user preferences"
- **Internet:** "Required for app functionality and API communication"

### 4.4 Target Audience

- **Content Rating:** 3+ (Everyone)
- **Target Age:** 13+
- **Content Descriptors:** None

## 🔒 **Step 5: Data Protection**

### 5.1 GDPR Compliance

Your app now includes:
- ✅ Data export functionality
- ✅ Data deletion functionality  
- ✅ Consent management
- ✅ Clear privacy policy
- ✅ Terms of service

### 5.2 Data Minimization

- Only collect necessary data
- Implement data retention policies
- Provide user control over data

## 📝 **Step 6: Final Checklist**

Before submitting to Google Play:

- [ ] API keys are secured and not hardcoded
- [ ] All network traffic uses HTTPS
- [ ] Background location permission removed
- [ ] Privacy policy is comprehensive and accessible
- [ ] Terms of service are clear and complete
- [ ] Data export/deletion functionality works
- [ ] Consent management is implemented
- [ ] App has been tested thoroughly
- [ ] Content rating questionnaire completed
- [ ] All permissions are justified

## 🚀 **Step 7: Publishing**

### 7.1 Internal Testing

1. Upload APK/AAB to internal testing
2. Test with internal testers
3. Fix any issues found

### 7.2 Closed Testing

1. Upload to closed testing
2. Invite external testers
3. Gather feedback and fix issues

### 7.3 Production Release

1. Upload to production
2. Set release notes
3. Submit for review

## ⚠️ **Common Rejection Reasons**

1. **Missing Privacy Policy**
2. **Incomplete Terms of Service**
3. **Unjustified Permissions**
4. **Security Issues (exposed API keys)**
5. **Data Collection Without Consent**
6. **Background Location Without Justification**

## 📞 **Support**

If you encounter issues:

1. Check [Google Play Console Help](https://support.google.com/googleplay/android-developer)
2. Review [Google Play Policy Center](https://play.google.com/about/developer-content-policy/)
3. Contact Google Play support through console

## 🔄 **Maintenance**

After publishing:

1. Monitor app performance
2. Respond to user feedback
3. Keep privacy policy updated
4. Monitor for policy changes
5. Regular security audits

---

**Remember:** Google Play Store compliance is an ongoing process. Stay updated with policy changes and maintain your app's security and privacy standards.
