#!/bin/bash

echo "Getting SHA-1 fingerprints for Google Sign-In configuration..."
echo "=============================================================="

# Check if keytool is available
if ! command -v keytool &> /dev/null; then
    echo "Error: keytool not found. Please make sure Java JDK is installed."
    exit 1
fi

# Get debug keystore SHA-1
echo "1. Debug Keystore SHA-1:"
echo "-----------------------"
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep "SHA1:"

echo ""
echo "2. Release Keystore SHA-1 (if exists):"
echo "--------------------------------------"
if [ -f "android/key.properties" ]; then
    echo "Release keystore found. Getting SHA-1..."
    # Extract keystore path from key.properties
    KEYSTORE_PATH=$(grep "storeFile" android/key.properties | cut -d'=' -f2 | tr -d ' ')
    if [ -f "$KEYSTORE_PATH" ]; then
        echo "Release keystore SHA-1:"
        keytool -list -v -keystore "$KEYSTORE_PATH" -alias $(grep "keyAlias" android/key.properties | cut -d'=' -f2 | tr -d ' ') -storepass $(grep "storePassword" android/key.properties | cut -d'=' -f2 | tr -d ' ') -keypass $(grep "keyPassword" android/key.properties | cut -d'=' -f2 | tr -d ' ') | grep "SHA1:"
    else
        echo "Release keystore file not found at: $KEYSTORE_PATH"
    fi
else
    echo "No release keystore configuration found."
fi

echo ""
echo "3. Instructions:"
echo "==============="
echo "1. Copy the SHA-1 fingerprints above"
echo "2. Go to Firebase Console: https://console.firebase.google.com/"
echo "3. Select your project: barrim-3b45a"
echo "4. Go to Project Settings > General"
echo "5. Scroll down to 'Your apps' section"
echo "6. Find your Android app: com.Barrim.AppBarrim"
echo "7. Click 'Add fingerprint' and paste the SHA-1 values"
echo "8. Save the changes"
echo ""
echo "Note: You need to add BOTH debug and release SHA-1 fingerprints"
echo "for Google Sign-In to work in both development and production."
