import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Screen'),
        actions: <Widget>[
          IconButton(
            onPressed: authService.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome Admin'),
      ),
    );
  }
}
