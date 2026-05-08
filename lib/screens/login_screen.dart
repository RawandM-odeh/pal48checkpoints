import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/auth_error_message.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorText;

  Future<void> _onGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _authService.signInWithGoogle();
    } catch (error) {
      setState(() {
        _errorText = authErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Pal48Checkpoints',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _onGoogleSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                ),
              if (_errorText != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
