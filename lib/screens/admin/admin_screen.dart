import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'checkpoints_tab.dart';
import 'send_notification_tab.dart';

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

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Theme(
      data: CheckpointTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: _currentIndex == 1
                ? BackButton(
                    onPressed: () => setState(() => _currentIndex = 0),
                  )
                : null,
            title: Text(
              _currentIndex == 1 ? 'إرسال إشعار' : 'لوحة الإدارة',
            ),
            actions: <Widget>[
              IconButton(
                onPressed: authService.signOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: IndexedStack(index: _currentIndex, children: _tabs),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (int i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: '⚙️ إدارة الحواجز',
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
