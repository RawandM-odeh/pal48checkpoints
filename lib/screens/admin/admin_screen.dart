import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'checkpoints_tab.dart';
import 'send_notification_tab.dart';

/// ثيم داكن للإدارة يقترب من لوحة المستخدم الرئيسية.
abstract final class _AdminTheme {
  static const Color pageBg = Color(0xFF1A1C23);
  static const Color surface = Color(0xFF2C2F38);
  static const Color primaryBlue = Color(0xFF2196F3);
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const <Widget>[
    CheckpointsTab(),
    SendNotificationTab(),
  ];

  ThemeData _adminDarkTheme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _AdminTheme.primaryBlue,
      brightness: Brightness.dark,
      surface: _AdminTheme.surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _AdminTheme.pageBg,
      colorScheme: scheme.copyWith(
        surface: _AdminTheme.surface,
        primary: _AdminTheme.primaryBlue,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _AdminTheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _AdminTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _AdminTheme.pageBg,
        selectedItemColor: _AdminTheme.primaryBlue,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _AdminTheme.surface,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _AdminTheme.primaryBlue, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Theme(
      data: _adminDarkTheme(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('لوحة الإدارة'),
            actions: <Widget>[
              IconButton(
                onPressed: authService.signOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (int i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: '🗺️ إدارة الحواجز',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.campaign_outlined),
                activeIcon: Icon(Icons.campaign),
                label: '📢 إرسال إشعار',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
