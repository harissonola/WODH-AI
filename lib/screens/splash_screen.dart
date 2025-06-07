import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Controller avec une durée de 8 secondes
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    // Animation de taille qui oscille entre 0.9 et 1.1 de la taille originale
    _sizeAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Animation d'opacité légère pour un effet de "pulsation lumineuse"
    _opacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Récupération du service d'authentification
    final auth = Provider.of<AuthService>(context, listen: false);

    // Vérification de l'authentification
    await auth.checkAuthentication();

    // Attente de 3 secondes pour l'animation (au lieu de 8)
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        auth.isAuthenticated ? '/home' : '/auth',
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _sizeAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Image.asset(
                      'assets/logo.png',
                      height: 150,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Chargement...',
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
