#!/bin/bash

echo "========================================"
echo "Getting SHA-1 Fingerprints for Google Sign-In"
echo "========================================"
echo ""

echo "1. Getting DEBUG SHA-1 fingerprint..."
echo "----------------------------------------"
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep -A 1 "SHA1"
echo ""

echo "2. Getting RELEASE SHA-1 fingerprint..."
echo "----------------------------------------"
cd android/app
keytool -list -v -keystore upload-keystore.jks -alias upload -storepass "9Z9ZBarrim@&\$" -keypass "9Z9ZBarrim@&\$" | grep -A 1 "SHA1"
cd ../..
echo ""

echo "========================================"
echo "Instructions:"
echo "1. Copy the SHA-1 fingerprints above"
echo "2. Go to Firebase Console: https://console.firebase.google.com/"
echo "3. Select your project: barrim-93482"
echo "4. Go to Project Settings (gear icon)"
echo "5. Scroll to 'Your apps' section"
echo "6. Find your Android app (com.Barrim.AppBarrim)"
echo "7. Click 'Add fingerprint' and paste both SHA-1 values"
echo "8. Save and wait a few minutes for changes to propagate"
echo "========================================"
