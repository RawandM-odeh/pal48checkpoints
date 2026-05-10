import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/guest_browse_provider.dart';

/// Signed-in with a non-anonymous provider (e.g. Google). Can perform writes the app allows.
/// Local "Skip" guests have no Firebase user — they cannot write.
bool get canUserMakeCheckpointWrites {
  final User? u = FirebaseAuth.instance.currentUser;
  return u != null && !u.isAnonymous;
}

/// Shows login prompt; [Login] signs out so [AuthGate] returns to [LoginScreen].
Future<void> showLoginRequiredDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Please log in to continue.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  await context.read<GuestBrowseProvider>().exitGuestBrowse();
                }
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
    },
  );
}

/// Returns `true` if the user may perform checkpoint writes; otherwise shows dialog and `false`.
Future<bool> ensureCanMakeCheckpointChanges(BuildContext context) async {
  if (canUserMakeCheckpointWrites) {
    return true;
  }
  await showLoginRequiredDialog(context);
  return false;
}
