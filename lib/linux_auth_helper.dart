import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LinuxAuthHelper {
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Utilisez google_sign_in même sur Linux
      final googleSignIn = GoogleSignIn(
        clientId: 'VOTRE_CLIENT_ID', // À obtenir depuis la console Google Cloud
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      return await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        ),
      );
    } catch (e, stack) {
      debugPrint('Google Sign-In Error: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }
}