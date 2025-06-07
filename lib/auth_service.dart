import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'linux_auth_helper.dart';

class AppUser {
  final String uid;
  final String? email;
  AppUser({required this.uid, this.email});
}

class AuthService with ChangeNotifier {
  AppUser? _user;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final fb_auth.FirebaseAuth _auth;

  bool get isAuthenticated => _user != null;

  AuthService() : _auth = fb_auth.FirebaseAuth.instance {
    if (!Platform.isLinux) {
      _auth.authStateChanges().listen(_onAuthStateChanged);
    } else {
      // Pour Linux, on initialise directement avec un mock user
      _user = AppUser(uid: 'mock_uid_linux', email: 'mockuser@linux.dev');
    }
  }

  void _onAuthStateChanged(fb_auth.User? firebaseUser) {
    if (firebaseUser == null) {
      _user = null;
    } else {
      _user = AppUser(uid: firebaseUser.uid, email: firebaseUser.email);
    }
    notifyListeners();
  }

  Future<AppUser?> signInWithEmailAndPassword(
      String email, String password) async {
    if (Platform.isLinux) {
      return _mockUser();
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _createAppUser(userCredential.user);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Erreur de connexion: ${e.message}');
      rethrow;
    }
  }

  Future<AppUser?> registerWithEmailAndPassword(
      String email, String password) async {
    if (Platform.isLinux) {
      return _mockUser();
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
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
      await _auth.sendPasswordResetEmail(email: email);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Erreur de réinitialisation: ${e.message}');
      rethrow;
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    if (Platform.isLinux) {
      return _mockUser();
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final userCredential = await _auth.signInWithCredential(
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

  AppUser _createAppUser(fb_auth.User? firebaseUser) {
    if (firebaseUser == null) {
      throw Exception('Firebase user is null');
    }

    _user = AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
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
      await _googleSignIn.signOut();
      await _auth.signOut();
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
      final fb_auth.User? current = _auth.currentUser;
      _user = current != null
          ? AppUser(uid: current.uid, email: current.email)
          : null;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur vérification auth: $e');
      _user = null;
      notifyListeners();
    }
  }
}