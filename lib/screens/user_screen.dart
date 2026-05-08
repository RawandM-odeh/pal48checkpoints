import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Screen'),
        actions: <Widget>[
          IconButton(
            onPressed: authService.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome User'),
      ),
    );
  }
}
