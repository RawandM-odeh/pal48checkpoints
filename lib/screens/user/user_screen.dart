import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../services/auth_service.dart';
import 'checkpoint_list.dart';

/// خلفية وثيم شبيه بالمرجع لشاشة المستخدم فقط.
abstract final class _UserLightChrome {
  static const Color pageBg = Color(0xFFF0F4F8);
  static const Color navy = Color(0xFF163E6C);
}

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  ThemeData _lightUserTheme(BuildContext base) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _UserLightChrome.pageBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A90D9),
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        foregroundColor: _UserLightChrome.navy,
        titleTextStyle: const TextStyle(
          color: _UserLightChrome.navy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final NotificationProvider inbox =
        context.watch<NotificationProvider>();

    return Theme(
      data: _lightUserTheme(context),
      child: Builder(
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);

          return Scaffold(
            appBar: AppBar(
              title: const Text('مداخل رئيسية'),
              actions: <Widget>[
                IconButton(
                  tooltip: 'مسح السجل',
                  onPressed: inbox.entries.isEmpty
                      ? null
                      : () {
                          context.read<NotificationProvider>().clear();
                        },
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
                IconButton(
                  onPressed: authService.signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (inbox.entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              'آخر الإشعارات',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _UserLightChrome.navy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...inbox.entries.take(3).map(
                                  (String line) => Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        line,
                                        textAlign: TextAlign.right,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Expanded(child: CheckpointList()),
              ],
            ),
          );
        },
      ),
    );
  }
}
