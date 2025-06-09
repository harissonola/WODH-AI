import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'models/conversation.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
  });
}

class AuthService with ChangeNotifier {
  AppUser? _user;
  GoogleSignIn? _googleSignIn;
  fb_auth.FirebaseAuth? _auth;
  StreamSubscription<fb_auth.User?>? _authStateSubscription;
  bool _isInitialized = false;

  bool get isAuthenticated => _user != null;
  AppUser? get currentUser => _user;
  bool get isInitialized => _isInitialized;

  AuthService() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    if (!Platform.isLinux) {
      _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      _auth = fb_auth.FirebaseAuth.instance;
      _authStateSubscription = _auth!.authStateChanges().listen(_onAuthStateChanged);
    }
    _isInitialized = true;
    // Utiliser WidgetsBinding pour différer la notification après la construction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _onAuthStateChanged(fb_auth.User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
    } else {
      _user = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName,
        phoneNumber: firebaseUser.phoneNumber,
        photoURL: firebaseUser.photoURL,
      );
    }
    notifyListeners();
  }

  // Email/Password
  Future<AppUser?> signInWithEmailAndPassword(String email, String password) async {
    if (Platform.isLinux) {
      throw Exception('Firebase Auth n\'est pas disponible sur Linux. Veuillez utiliser une autre plateforme.');
    }

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
    if (Platform.isLinux) {
      throw Exception('Firebase Auth n\'est pas disponible sur Linux. Veuillez utiliser une autre plateforme.');
    }

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
      throw Exception('Firebase Auth n\'est pas disponible sur Linux. Veuillez utiliser une autre plateforme.');
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
    if (Platform.isLinux) {
      throw Exception('Firebase Auth n\'est pas disponible sur Linux. Veuillez utiliser une autre plateforme.');
    }

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
    if (Platform.isLinux) {
      throw Exception('Firebase Auth n\'est pas disponible sur Linux. Veuillez utiliser une autre plateforme.');
    }

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
    if (Platform.isLinux) {
      throw Exception('Firebase Auth n\'est pas disponible sur Linux. Veuillez utiliser une autre plateforme.');
    }

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
    if (Platform.isLinux) {
      throw Exception('Firebase Auth n\'est pas disponible sur Linux. Veuillez utiliser une autre plateforme.');
    }

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

  AppUser _createAppUser(fb_auth.User? firebaseUser) {
    if (firebaseUser == null) throw Exception('Firebase user is null');

    _user = AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      phoneNumber: firebaseUser.phoneNumber,
      photoURL: firebaseUser.photoURL,
    );

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
      // Sur Linux, on n'a pas d'utilisateur connecté par défaut
      _user = null;
      // Utiliser WidgetsBinding pour différer la notification
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return;
    }

    try {
      final current = _auth!.currentUser;
      if (current != null) {
        _user = AppUser(
          uid: current.uid,
          email: current.email,
          displayName: current.displayName,
          phoneNumber: current.phoneNumber,
          photoURL: current.photoURL,
        );
      } else {
        _user = null;
      }
      // Utiliser WidgetsBinding pour différer la notification
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Erreur vérification auth: $e');
      _user = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}