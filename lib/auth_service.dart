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

  // Add this getter
  bool get isAuthenticated => _user != null;

  AuthService() : _auth = fb_auth.FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(fb_auth.User? firebaseUser) {
    if (firebaseUser == null) {
      _user = null;
    } else {
      _user = AppUser(uid: firebaseUser.uid, email: firebaseUser.email);
    }
    notifyListeners();
  }

  // Connexion avec email/mot de passe
  Future<AppUser?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = AppUser(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email,
      );
      notifyListeners();
      return _user;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Erreur de connexion: ${e.message}');
      rethrow;
    }
  }

  // Inscription avec email/mot de passe
  Future<AppUser?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = AppUser(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email,
      );
      notifyListeners();
      return _user;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Erreur d\'inscription: ${e.message}');
      rethrow;
    }
  }

  // Réinitialisation de mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Erreur de réinitialisation: ${e.message}');
      rethrow;
    }
  }

  // Connexion Google (existant)
  Future<AppUser?> signInWithGoogle() async {
    try {
      fb_auth.UserCredential userCredential;

      if (Platform.isLinux) {
        final result = await LinuxAuthHelper.signInWithGoogle();
        if (result == null) {
          throw Exception('Échec de la connexion Google sur Linux');
        }
        userCredential = result;
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

        userCredential = await _auth.signInWithCredential(
          fb_auth.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );
      }

      _user = AppUser(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email,
      );
      notifyListeners();
      return _user;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!Platform.isLinux) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> checkAuthentication() async {
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