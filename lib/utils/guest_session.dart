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

/// يخرج من وضع الضيف ويعيد المكدس إلى الشاشة الأولى حتى تظهر [LoginScreen].
Future<void> completeLoginPromptNavigation(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) {
    return;
  }
  await context.read<GuestBrowseProvider>().exitGuestBrowse();
  if (!context.mounted) {
    return;
  }
  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) {
    nav.popUntil((Route<dynamic> route) => route.isFirst);
  }
}

/// حوار تسجيل الدخول قبل إرسال تحديث أو تعديل حالة.
Future<void> showLoginRequiredDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'تسجيل الدخول مطلوب',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'يرجى تسجيل الدخول لإرسال تحديث عن حالة الحاجز.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await completeLoginPromptNavigation(context);
              },
              child: const Text('تسجيل الدخول'),
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

/// حوار العربية لصفحة المثبتة والعلامة على البطاقات.
Future<void> showSavedLoginRequiredDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'تسجيل الدخول مطلوب',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'يرجى تسجيل الدخول لحفظ الحواجز ومتابعتها.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await completeLoginPromptNavigation(context);
              },
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> ensureLoggedInForSaved(BuildContext context) async {
  if (canUserMakeCheckpointWrites) {
    return true;
  }
  await showSavedLoginRequiredDialog(context);
  return false;
}
