import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../services/auth_service.dart';
import 'checkpoint_list.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final ThemeData theme = Theme.of(context);
    final NotificationProvider inbox =
        context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المستخدم'),
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'آخر الإشعارات',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...inbox.entries.take(3).map(
                            (String line) => Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('قائمة النقاط'),
            ),
          ),
          const Expanded(child: CheckpointList()),
        ],
      ),
    );
  }
}
