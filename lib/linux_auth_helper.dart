import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class LinuxAuthHelper {
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.app == null) {
        debugPrint('Firebase app not initialized');
        return null;
      }

      final googleProvider = GoogleAuthProvider();
      return await auth.signInWithPopup(googleProvider);
    } catch (e, stack) {
      debugPrint('Google Sign-In Error: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }
}