import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignin {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  String getUserEmail() => _firebaseAuth.currentUser?.email ?? "User";

Future<UserCredential?> signInWithApple() async {
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
    
    // Create the OAuth credential correctly
    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken, // Use identityToken, not authorizationCode
      accessToken: appleCredential.authorizationCode,
    );

    return await _firebaseAuth.signInWithCredential(oauthCredential);
  } catch (e) {
    print("Error during Sign in with Apple: $e");
    return null;
  }
}


  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}