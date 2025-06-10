import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
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

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] ?? '',
      email: json['email'],
      displayName: json['displayName'],
      phoneNumber: json['phoneNumber'],
      photoURL: json['photoURL'],
    );
  }
}

class AuthService with ChangeNotifier {
  static const String _firebaseApiKey = "AIzaSyCjb85UwE7nrp2ENO-1TRZoBK6q6rdxb2s";
  static const String _firebaseAuthUrl = "https://identitytoolkit.googleapis.com/v1/accounts";

  AppUser? _user;
  GoogleSignIn? _googleSignIn;
  fb_auth.FirebaseAuth? _auth;
  StreamSubscription<fb_auth.User?>? _authStateSubscription;
  bool _isInitialized = false;
  String? _verificationId;
  String? _phoneNumber;

  bool get isAuthenticated => _user != null;
  AppUser? get currentUser => _user;
  bool get isInitialized => _isInitialized;

  AuthService() {
    _initializeAuth();
  }

  // Dans la méthode _initializeAuth()
  Future<void> _initializeAuth() async {
    try {
      if (Platform.isLinux) {
        // Mode Linux - Pas besoin de Firebase
        _isInitialized = true;
        notifyListeners();
        return;
      }

      // Initialiser Firebase Auth seulement si nécessaire
      if (_auth == null) {
        _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        _auth = fb_auth.FirebaseAuth.instance;
        _authStateSubscription = _auth!.authStateChanges().listen(_onAuthStateChanged);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Gestionnaire des changements d'état d'authentification
  void _onAuthStateChanged(fb_auth.User? user) {
    // Ne pas utiliser Provider.of ici, car nous n'avons pas accès au BuildContext
    // dans un service qui n'est pas un Widget

    if (user != null) {
      _user = AppUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        phoneNumber: user.phoneNumber,
        photoURL: user.photoURL,
      );
    } else {
      _user = null;
    }
    notifyListeners();
  }

  // Méthode commune pour créer un AppUser
  AppUser _createAppUserFromMap(Map<String, dynamic> userData) {
    _user = AppUser(
      uid: userData['localId'] ?? userData['uid'],
      email: userData['email'],
      displayName: userData['displayName'] ?? userData['email']?.split('@').first,
      phoneNumber: userData['phoneNumber'],
      photoURL: userData['photoUrl'] ?? userData['photoURL'],
    );
    notifyListeners();
    return _user!;
  }

  // ==================== EMAIL/PASSWORD AUTHENTICATION ====================

  // Email/Password - Version pour Linux (REST API)
  String? _linuxAuthToken;

  Future<AppUser?> _signInWithEmailAndPasswordLinux(
      String email,
      String password, {
        ConversationProvider? conversationProvider,
      }) async {
    try {
      final response = await http.post(
        Uri.parse('$_firebaseAuthUrl:signInWithPassword?key=$_firebaseApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error']['message'] ?? 'Échec de la connexion');
      }

      _linuxAuthToken = data['idToken']; // Stocker le token

      // Mettre à jour le ConversationProvider si fourni
      if (conversationProvider != null) {
        final user = fb_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          conversationProvider.setUserId(data['localId'], linuxAuthToken: _linuxAuthToken);
        }
      }

      return _createAppUserFromMap(data);
    } catch (e) {
      debugPrint('Linux SignIn Error: $e');
      rethrow;
    }
  }

  // Ajouter une méthode pour obtenir le token Linux
  String? get linuxAuthToken => _linuxAuthToken;

  // Email/Password - Version native
  Future<AppUser?> _signInWithEmailAndPasswordNative(String email, String password) async {
    try {
      final userCredential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _createAppUserFromMap({
        'uid': userCredential.user?.uid,
        'email': userCredential.user?.email,
        'displayName': userCredential.user?.displayName,
        'phoneNumber': userCredential.user?.phoneNumber,
        'photoURL': userCredential.user?.photoURL,
      });
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('SignIn Error: ${e.message}');
      rethrow;
    }
  }

  Future<AppUser?> signInWithEmailAndPassword(
      String email,
      String password, {
        ConversationProvider? conversationProvider,
      }) async {
    return Platform.isLinux
        ? await _signInWithEmailAndPasswordLinux(
        email, password,
        conversationProvider: conversationProvider)
        : await _signInWithEmailAndPasswordNative(email, password);
  }

  // Inscription - Version pour Linux (REST API)
  Future<AppUser?> _registerWithEmailAndPasswordLinux(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_firebaseAuthUrl:signUp?key=$_firebaseApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error']['message'] ?? 'Échec de l\'inscription');
      }

      return _createAppUserFromMap(data);
    } catch (e) {
      debugPrint('Linux Register Error: $e');
      rethrow;
    }
  }

  // Inscription - Version native
  Future<AppUser?> _registerWithEmailAndPasswordNative(String email, String password) async {
    try {
      final userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _createAppUserFromMap({
        'uid': userCredential.user?.uid,
        'email': userCredential.user?.email,
        'displayName': userCredential.user?.displayName,
        'phoneNumber': userCredential.user?.phoneNumber,
        'photoURL': userCredential.user?.photoURL,
      });
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Register Error: ${e.message}');
      rethrow;
    }
  }

  Future<AppUser?> registerWithEmailAndPassword(String email, String password) async {
    return Platform.isLinux
        ? await _registerWithEmailAndPasswordLinux(email, password)
        : await _registerWithEmailAndPasswordNative(email, password);
  }

  // ==================== PASSWORD RESET ====================

  // Réinitialisation mot de passe - Version Linux
  Future<void> _resetPasswordLinux(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_firebaseAuthUrl:sendOobCode?key=$_firebaseApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestType': 'PASSWORD_RESET',
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error']['message'] ?? 'Échec de la réinitialisation');
      }
    } catch (e) {
      debugPrint('Linux ResetPassword Error: $e');
      rethrow;
    }
  }

  // Réinitialisation mot de passe - Version native
  Future<void> _resetPasswordNative(String email) async {
    try {
      await _auth!.sendPasswordResetEmail(email: email);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('ResetPassword Error: ${e.message}');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    return Platform.isLinux
        ? await _resetPasswordLinux(email)
        : await _resetPasswordNative(email);
  }

  // ==================== GOOGLE SIGN IN ====================

  // Google Sign In - Version Linux (non supportée directement)
  Future<AppUser?> _signInWithGoogleLinux() async {
    throw Exception('Google Sign In n\'est pas supporté sur Linux. Utilisez l\'authentification par email/mot de passe.');
  }

  // Google Sign In - Version native
  Future<AppUser?> _signInWithGoogleNative() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        throw Exception('Connexion Google annulée');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      return _createAppUserFromMap({
        'uid': userCredential.user?.uid,
        'email': userCredential.user?.email,
        'displayName': userCredential.user?.displayName,
        'phoneNumber': userCredential.user?.phoneNumber,
        'photoURL': userCredential.user?.photoURL,
      });
    } catch (e) {
      debugPrint('Google SignIn Error: $e');
      rethrow;
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    return Platform.isLinux
        ? await _signInWithGoogleLinux()
        : await _signInWithGoogleNative();
  }

  // ==================== MICROSOFT SIGN IN ====================

  // Microsoft Sign In - Version Linux (non supportée directement)
  Future<AppUser?> _signInWithMicrosoftLinux() async {
    throw Exception('Microsoft Sign In n\'est pas supporté sur Linux. Utilisez l\'authentification par email/mot de passe.');
  }

  // Microsoft Sign In - Version native (nécessite le package microsoft_sign_in)
  Future<AppUser?> _signInWithMicrosoftNative() async {
    try {
      // Note: Cette implémentation nécessite le package microsoft_sign_in
      // Pour une implémentation complète, vous devriez ajouter:
      // microsoft_sign_in: ^0.1.0 dans pubspec.yaml

      throw Exception('Microsoft Sign In nécessite une configuration supplémentaire. Utilisez l\'authentification par email/mot de passe.');

      // Exemple d'implémentation avec microsoft_sign_in:
      /*
      final microsoftSignIn = MicrosoftSignIn();
      final result = await microsoftSignIn.signIn();

      if (result == null) {
        throw Exception('Connexion Microsoft annulée');
      }

      final credential = fb_auth.OAuthProvider('microsoft.com').credential(
        accessToken: result.accessToken,
        idToken: result.idToken,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      return _createAppUserFromMap({
        'uid': userCredential.user?.uid,
        'email': userCredential.user?.email,
        'displayName': userCredential.user?.displayName,
        'phoneNumber': userCredential.user?.phoneNumber,
        'photoURL': userCredential.user?.photoURL,
      });
      */
    } catch (e) {
      debugPrint('Microsoft SignIn Error: $e');
      rethrow;
    }
  }

  Future<AppUser?> signInWithMicrosoft() async {
    return Platform.isLinux
        ? await _signInWithMicrosoftLinux()
        : await _signInWithMicrosoftNative();
  }

  // ==================== PHONE AUTHENTICATION ====================

  // Vérification du numéro de téléphone - Version Linux
  Future<void> _verifyPhoneNumberLinux(String phoneNumber) async {
    // Sur Linux, nous ne pouvons pas utiliser la vérification SMS de Firebase
    // Cette fonctionnalité nécessite une implémentation personnalisée
    throw Exception('La vérification par téléphone n\'est pas supportée sur Linux.');
  }

  // Vérification du numéro de téléphone - Version native
  Future<void> _verifyPhoneNumberNative(String phoneNumber) async {
    try {
      await _auth!.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (fb_auth.PhoneAuthCredential credential) async {
          // Vérification automatique (Android uniquement)
          final userCredential = await _auth!.signInWithCredential(credential);
          _createAppUserFromMap({
            'uid': userCredential.user?.uid,
            'email': userCredential.user?.email,
            'displayName': userCredential.user?.displayName,
            'phoneNumber': userCredential.user?.phoneNumber,
            'photoURL': userCredential.user?.photoURL,
          });
        },
        verificationFailed: (fb_auth.FirebaseAuthException e) {
          debugPrint('Phone verification failed: ${e.message}');
          throw Exception('Échec de la vérification du téléphone: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _phoneNumber = phoneNumber;
          debugPrint('Code SMS envoyé');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          debugPrint('Timeout de récupération automatique du code');
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('Phone verification error: $e');
      rethrow;
    }
  }

  Future<void> verifyPhoneNumber(String phoneNumber) async {
    return Platform.isLinux
        ? await _verifyPhoneNumberLinux(phoneNumber)
        : await _verifyPhoneNumberNative(phoneNumber);
  }

  // Connexion avec le numéro de téléphone - Version Linux
  Future<AppUser?> _signInWithPhoneNumberLinux(String smsCode) async {
    throw Exception('La connexion par téléphone n\'est pas supportée sur Linux.');
  }

  // Connexion avec le numéro de téléphone - Version native
  Future<AppUser?> _signInWithPhoneNumberNative(String smsCode) async {
    try {
      if (_verificationId == null) {
        throw Exception('Aucune vérification en cours. Veuillez d\'abord vérifier votre numéro de téléphone.');
      }

      final credential = fb_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      return _createAppUserFromMap({
        'uid': userCredential.user?.uid,
        'email': userCredential.user?.email,
        'displayName': userCredential.user?.displayName ?? _phoneNumber,
        'phoneNumber': userCredential.user?.phoneNumber ?? _phoneNumber,
        'photoURL': userCredential.user?.photoURL,
      });
    } catch (e) {
      debugPrint('Phone SignIn Error: $e');
      rethrow;
    }
  }

  Future<AppUser?> signInWithPhoneNumber(String smsCode) async {
    return Platform.isLinux
        ? await _signInWithPhoneNumberLinux(smsCode)
        : await _signInWithPhoneNumberNative(smsCode);
  }

  // ==================== GENERAL METHODS ====================

  // Déconnexion
  Future<void> signOut() async {
    try {
      if (!Platform.isLinux) {
        await _googleSignIn?.signOut();
        await _auth?.signOut();
      }
      _user = null;
      _verificationId = null;
      _phoneNumber = null;
      notifyListeners();
    } catch (e) {
      debugPrint('SignOut Error: $e');
      _user = null;
      notifyListeners();
    }
  }

  // Vérification de l'authentification
  Future<void> checkAuthentication() async {
    if (Platform.isLinux) {
      // Sur Linux, on ne peut pas maintenir la session via REST API
      _user = null;
    } else {
      try {
        final current = _auth?.currentUser;
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
      } catch (e) {
        debugPrint('Auth check error: $e');
        _user = null;
      }
    }
    notifyListeners();
  }

  // Suppression du compte
  Future<void> deleteAccount() async {
    try {
      if (Platform.isLinux) {
        throw Exception('La suppression de compte n\'est pas supportée sur Linux.');
      } else {
        await _auth?.currentUser?.delete();
        _user = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Delete account error: $e');
      rethrow;
    }
  }

  // Mise à jour du profil utilisateur
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      if (Platform.isLinux) {
        throw Exception('La mise à jour du profil n\'est pas supportée sur Linux.');
      } else {
        await _auth?.currentUser?.updateDisplayName(displayName);
        await _auth?.currentUser?.updatePhotoURL(photoURL);

        if (_user != null) {
          _user = AppUser(
            uid: _user!.uid,
            email: _user!.email,
            displayName: displayName ?? _user!.displayName,
            phoneNumber: _user!.phoneNumber,
            photoURL: photoURL ?? _user!.photoURL,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
      rethrow;
    }
  }

  // Vérification de l'email
  Future<void> sendEmailVerification() async {
    try {
      if (Platform.isLinux) {
        throw Exception('La vérification d\'email n\'est pas supportée sur Linux.');
      } else {
        await _auth?.currentUser?.sendEmailVerification();
      }
    } catch (e) {
      debugPrint('Send email verification error: $e');
      rethrow;
    }
  }

  // Rechargement des données utilisateur
  Future<void> reloadUser() async {
    try {
      if (!Platform.isLinux) {
        await _auth?.currentUser?.reload();
        final current = _auth?.currentUser;
        if (current != null) {
          _user = AppUser(
            uid: current.uid,
            email: current.email,
            displayName: current.displayName,
            phoneNumber: current.phoneNumber,
            photoURL: current.photoURL,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Reload user error: $e');
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}