import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignin {
  /// Get Apple Sign-In credential for backend authentication
  Future<Map<String, dynamic>?> getAppleCredential() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      // Check if identityToken is present
      if (appleCredential.identityToken == null) {
        print("Apple Sign-In failed: identityToken is null");
        return null;
      }
      
      // Return credential data for backend
      return {
        'identityToken': appleCredential.identityToken,
        'email': appleCredential.email,
        'fullName': appleCredential.givenName != null && appleCredential.familyName != null
            ? '${appleCredential.givenName} ${appleCredential.familyName}'
            : null,
        'authorizationCode': appleCredential.authorizationCode,
      };
    } catch (e) {
      print("Error during Sign in with Apple: $e");
      return null;
    }
  }
} 