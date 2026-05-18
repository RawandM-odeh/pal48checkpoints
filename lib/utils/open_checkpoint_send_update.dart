import 'package:flutter/material.dart';

import '../models/checkpoint.dart';
import '../screens/user/checkpoint_detail_screen.dart';
import 'guest_session.dart';

/// يفتح تبويب «أرسل تحديث» بعد التحقق من تسجيل الدخول.
Future<void> openCheckpointSendUpdate(
  BuildContext context,
  Checkpoint checkpoint,
) async {
  if (!await ensureCanMakeCheckpointChanges(context)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => CheckpointDetailScreen(
        initialCheckpoint: checkpoint,
        initialTabIndex: 1,
      ),
    ),
  );
}
