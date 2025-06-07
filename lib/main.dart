import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wodh_ai/screens/auth_screen.dart';
import 'package:wodh_ai/screens/home_screen.dart';

import 'auth_service.dart';
import 'models/conversation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Firebase avec gestion d'erreur améliorée
  await _initializeFirebase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        StreamProvider<List<ConnectivityResult>>(
          create: (_) => Connectivity().onConnectivityChanged,
          initialData: [ConnectivityResult.none],
        ),
      ],
      child: const WodhAIApp(),
    ),
  );
}

Future<void> _initializeFirebase() async {
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCjb85UwE7nrp2ENO-1TRZoBK6q6rdxb2s",
          authDomain: "wodh-ai.firebaseapp.com",
          projectId: "wodh-ai",
          storageBucket: "wodh-ai.firebasestorage.app",
          messagingSenderId: "36323799698",
          appId: "1:36323799698:web:3f895dec9b1e82e1e8ec4b",
        ),
      );
    } else if (Platform.isLinux) {
      // Solution spécifique pour Linux
      await _initializeFirebaseForLinux();
    } else {
      await Firebase.initializeApp();
    }
  } catch (e, stack) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Stack trace: $stack');
    // Fallback pour Linux
    if (Platform.isLinux) {
      await _initializeFirebaseForLinux(fallback: true);
    }
  }
}

Future<void> _initializeFirebaseForLinux({bool fallback = false}) async {
  try {
    if (!fallback) {
      await Firebase.initializeApp(
        name: 'LinuxApp',
        options: const FirebaseOptions(
          apiKey: "AIzaSyCjb85UwE7nrp2ENO-1TRZoBK6q6rdxb2s",
          authDomain: "wodh-ai.firebaseapp.com",
          projectId: "wodh-ai",
          storageBucket: "wodh-ai.firebasestorage.app",
          messagingSenderId: "36323799698",
          appId: "1:36323799698:web:3f895dec9b1e82e1e8ec4b",
        ),
      );
    } else {
      // Fallback ultra simple
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Linux Firebase init error: $e');
  }
}

class WodhAIApp extends StatelessWidget {
  const WodhAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wodh AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.deepPurple),
          titleTextStyle: TextStyle(
            color: Colors.deepPurple,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isAuthenticated) {
          return const ConnectivityWrapper(child: HomeScreen());
        }
        return const ConnectivityWrapper(child: AuthScreen());
      },
    );
  }
}

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isConnected = true;
  bool _showConnectionBanner = false;
  Timer? _connectionBannerTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
  }

  @override
  void dispose() {
    _connectionBannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final isConnected = results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);

    if (isConnected != _isConnected) {
      setState(() {
        _isConnected = isConnected;
        _showConnectionBanner = true;
      });

      _connectionBannerTimer?.cancel();
      _connectionBannerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showConnectionBanner = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivityResults = Provider.of<List<ConnectivityResult>>(context);

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          if (_showConnectionBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: _isConnected ? Colors.green : Colors.red,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _isConnected
                        ? 'Connexion internet rétablie'
                        : 'Pas de connexion internet',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}