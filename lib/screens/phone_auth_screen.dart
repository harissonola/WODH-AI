import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _codeSent = false;
  String _phoneNumber = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un numéro de téléphone';
    }

    // Supprimer tous les espaces et caractères spéciaux sauf +
    String cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');

    // Vérifier le format basique
    if (!cleaned.startsWith('+')) {
      return 'Le numéro doit commencer par + (ex: +33612345678)';
    }

    if (cleaned.length < 10 || cleaned.length > 15) {
      return 'Numéro de téléphone invalide';
    }

    return null;
  }

  String? _validateSmsCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer le code de vérification';
    }

    if (value.length != 6) {
      return 'Le code doit contenir 6 chiffres';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Le code ne doit contenir que des chiffres';
    }

    return null;
  }

  Future<void> _verifyPhoneNumber() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      _phoneNumber = _phoneController.text.trim();

      await auth.verifyPhoneNumber(_phoneNumber);

      setState(() {
        _codeSent = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code de vérification envoyé par SMS'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = 'Erreur lors de l\'envoi du code';

      // Gestion des erreurs spécifiques
      if (e.toString().contains('Linux')) {
        errorMessage = 'L\'authentification par téléphone n\'est pas disponible sur cette plateforme';
      } else if (e.toString().contains('invalid-phone-number')) {
        errorMessage = 'Numéro de téléphone invalide';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard';
      } else if (e.toString().contains('quota-exceeded')) {
        errorMessage = 'Quota de SMS dépassé. Veuillez réessayer plus tard';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = await auth.signInWithPhoneNumber(_codeController.text.trim());

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion réussie !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        throw Exception('Échec de la connexion');
      }
    } catch (e) {
      String errorMessage = 'Code de vérification incorrect';

      // Gestion des erreurs spécifiques
      if (e.toString().contains('invalid-verification-code')) {
        errorMessage = 'Code de vérification invalide';
      } else if (e.toString().contains('session-expired')) {
        errorMessage = 'Session expirée. Veuillez recommencer';
      } else if (e.toString().contains('Aucune vérification en cours')) {
        errorMessage = 'Aucune vérification en cours. Veuillez d\'abord demander un code';
        setState(() => _codeSent = false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resendCode() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.verifyPhoneNumber(_phoneNumber);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nouveau code envoyé'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du renvoi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    setState(() {
      _codeSent = false;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_codeSent ? 'Vérification du code' : 'Connexion par téléphone'),
        leading: _codeSent
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : _goBack,
        )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_codeSent) ...[
                const Icon(
                  Icons.phone,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Entrez votre numéro de téléphone',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nous vous enverrons un code de vérification par SMS',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '+33612345678',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _validatePhoneNumber,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Envoyer le code',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.sms,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Vérification du code',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Un code de vérification a été envoyé au numéro $_phoneNumber',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Code de vérification',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.verified_user),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateSmsCode,
                  enabled: !_isLoading,
                  maxLength: 6,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Vérifier le code',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: const Text('Renvoyer le code'),
                ),
              ],
              const Spacer(),
              if (!_codeSent)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour à la connexion'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}