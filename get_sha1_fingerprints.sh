#!/bin/bash

echo "🔍 Getting SHA-1 Fingerprints for Google Sign-In..."
echo ""

echo "📱 Debug SHA-1 Fingerprint:"
cd android
./gradlew signingReport | grep -A 1 "Variant: debug" | grep "SHA1:" | head -1
echo ""

echo "📱 Release SHA-1 Fingerprint:"
./gradlew signingReport | grep -A 1 "Variant: release" | grep "SHA1:" | head -1
echo ""

echo "📋 Instructions:"
echo "1. Copy the SHA-1 fingerprints above"
echo "2. Go to Firebase Console: https://console.firebase.google.com/"
echo "3. Select project: barrim-3b45a"
echo "4. Go to Project Settings > General"
echo "5. Find Android app: com.Barrim.AppBarrim"
echo "6. Add both SHA-1 fingerprints"
echo "7. Download updated google-services.json"
echo "8. Replace android/app/google-services.json"
echo ""

cd ..