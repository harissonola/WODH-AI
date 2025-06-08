import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/src/widgets/framework.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';

import 'models/conversation.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? phoneNumber;

  AppUser({required this.uid, this.email, this.phoneNumber});
}

class AuthService with ChangeNotifier {
  AppUser? _user;
  GoogleSignIn? _googleSignIn;
  fb_auth.FirebaseAuth? _auth;

  bool get isAuthenticated => _user != null;

  AuthService() {
    if (!Platform.isLinux) {
      _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      _auth = fb_auth.FirebaseAuth.instance;
      _auth!.authStateChanges().listen(_onAuthStateChanged);
    } else {
      // Mode mock pour Linux
      _user = AppUser(uid: 'mock_uid_linux', email: 'mockuser@linux.dev');
    }
  }

  void _onAuthStateChanged(fb_auth.User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      // Clear conversations when user signs out
      final conversationProvider = Provider.of<ConversationProvider>(context as BuildContext, listen: false);
      conversationProvider.setUserId('');
    } else {
      _user = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        phoneNumber: firebaseUser.phoneNumber,
      );
      // Set user ID in conversation provider
      final conversationProvider = Provider.of<ConversationProvider>(context as BuildContext, listen: false);
      conversationProvider.setUserId(firebaseUser.uid);
    }
    notifyListeners();
  }

  // Email/Password
  Future<AppUser?> signInWithEmailAndPassword(String email, String password) async {
    if (Platform.isLinux) return _mockUser();

    try {
      final userCredential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _createAppUser(userCredential.user);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Erreur de connexion: ${e.message}');
      rethrow;
    }
  }

  Future<AppUser?> registerWithEmailAndPassword(String email, String password) async {
    if (Platform.isLinux) return _mockUser();

    try {
      final userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _createAppUser(userCredential.user);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Erreur d\'inscription: ${e.message}');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    if (Platform.isLinux) {
      debugPrint('Mock: Email de réinitialisation envoyé à $email');
      return;
    }

    try {
      await _auth!.sendPasswordResetEmail(email: email);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Erreur de réinitialisation: ${e.message}');
      rethrow;
    }
  }

  // Google
  Future<AppUser?> signInWithGoogle() async {
    if (Platform.isLinux) return _mockUser();

    try {
      final googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final userCredential = await _auth!.signInWithCredential(
        fb_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );

      return _createAppUser(userCredential.user);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  // Microsoft
  Future<AppUser?> signInWithMicrosoft() async {
    if (Platform.isLinux) return _mockUser();

    try {
      final userCredential = await _auth!.signInWithProvider(
        fb_auth.OAuthProvider('microsoft.com'),
      );
      return _createAppUser(userCredential.user);
    } catch (e) {
      debugPrint('Microsoft Sign-In Error: $e');
      rethrow;
    }
  }

  // Phone
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(fb_auth.FirebaseAuthException) onVerificationFailed,
    required Function(fb_auth.PhoneAuthCredential) onVerificationCompleted,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    if (Platform.isLinux) return;

    await _auth!.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: (verificationId, forceResendingToken) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  Future<AppUser?> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    if (Platform.isLinux) return _mockUser();

    try {
      final credential = fb_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth!.signInWithCredential(credential);
      return _createAppUser(userCredential.user);
    } catch (e) {
      debugPrint('Phone Sign-In Error: $e');
      rethrow;
    }
  }

  // Utilitaires
  AppUser _createAppUser(fb_auth.User? firebaseUser) {
    if (firebaseUser == null) throw Exception('Firebase user is null');
    _user = AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      phoneNumber: firebaseUser.phoneNumber,
    );
    notifyListeners();
    return _user!;
  }

  AppUser _mockUser() {
    _user = AppUser(uid: 'mock_uid_linux', email: 'mockuser@linux.dev');
    notifyListeners();
    return _user!;
  }

  Future<void> signOut() async {
    if (!Platform.isLinux) {
      await _googleSignIn?.signOut();
      await _auth!.signOut();
    }
    _user = null;
    notifyListeners();
  }

  Future<void> checkAuthentication() async {
    if (Platform.isLinux) {
      _user = AppUser(uid: 'mock_uid_linux', email: 'mockuser@linux.dev');
      notifyListeners();
      return;
    }

    try {
      final current = _auth!.currentUser;
      if (current != null) {
        _user = AppUser(
          uid: current.uid,
          email: current.email,
          phoneNumber: current.phoneNumber,
        );
      } else {
        _user = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur vérification auth: $e');
      _user = null;
      notifyListeners();
    }
  }
}