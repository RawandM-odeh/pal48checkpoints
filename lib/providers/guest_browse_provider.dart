import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browse without Firebase ("Skip for later"). Persists across restarts.
///
/// Used when [FirebaseAuth] anonymous sign-in is unavailable
/// (`admin-restricted-operation` in some projects).
final class GuestBrowseProvider extends ChangeNotifier {
  GuestBrowseProvider(SharedPreferences prefs)
      : _prefs = prefs,
        _guest = prefs.getBool(_kKey) ?? false;

  static const String _kKey = 'guest_browse_mode';

  final SharedPreferences _prefs;
  bool _guest;
  bool _scheduledClearStale = false;

  bool get isGuestBrowsing => _guest;

  /// If prefs still say "guest" but Firebase already restored a signed-in user.
  void scheduleExitGuestIfStale() {
    if (!_guest || _scheduledClearStale) {
      return;
    }
    _scheduledClearStale = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await exitGuestBrowse();
      } finally {
        _scheduledClearStale = false;
      }
    });
  }

  void enterGuestBrowse() {
    if (_guest) {
      return;
    }
    _guest = true;
    notifyListeners();
    unawaited(_prefs.setBool(_kKey, true));
  }

  Future<void> exitGuestBrowse() async {
    if (!_guest) {
      return;
    }
    _guest = false;
    notifyListeners();
    await _prefs.remove(_kKey);
  }
}
