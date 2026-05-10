import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';

/// Persists favorites for signed-in non-anonymous users (local + Firestore).
/// Guests and Firebase anonymous sessions cannot toggle; [isFavorite] stays false until then.
final class FavoriteCheckpointsProvider extends ChangeNotifier {
  FavoriteCheckpointsProvider(this._prefs, this._firestore) {
    final List<String> raw =
        _prefs.getStringList(_kPrefsKey) ?? const <String>[];
    if (raw.isNotEmpty) {
      _ids = raw.toSet();
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  static const String _kPrefsKey = 'favorite_checkpoint_ids';

  final SharedPreferences _prefs;
  final FirestoreService _firestore;
  StreamSubscription<User?>? _authSub;

  Set<String> _ids = <String>{};

  Set<String> get ids => Set<String>.unmodifiable(_ids);

  bool get _mayManageFavorites {
    final User? u = FirebaseAuth.instance.currentUser;
    return u != null && !u.isAnonymous;
  }

  /// Guests / anonymous users never see a filled favorite (stored ids are ignored until they sign in).
  bool isFavorite(String checkpointId) {
    if (!_mayManageFavorites) {
      return false;
    }
    return _ids.contains(checkpointId);
  }

  void toggle(String checkpointId) {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null || u.isAnonymous) {
      return;
    }
    final String id = checkpointId.trim();
    if (id.isEmpty) {
      return;
    }
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    unawaited(_saveLocal());
    notifyListeners();
    unawaited(_pushCloudIfEligible());
  }

  Future<void> _saveLocal() async {
    final List<String> sorted = _ids.toList()..sort();
    await _prefs.setStringList(_kPrefsKey, sorted);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user != null && !user.isAnonymous) {
      await _mergeWithCloud(user.uid);
    }
    notifyListeners();
  }

  Future<void> _mergeWithCloud(String uid) async {
    try {
      final Set<String> cloud = await _firestore.getFavoriteCheckpointIds(uid);
      final Set<String> merged = {..._ids, ...cloud};
      if (!setEquals(merged, _ids)) {
        _ids = merged;
        await _prefs.setStringList(_kPrefsKey, merged.toList()..sort());
      }
      await _firestore.setFavoriteCheckpointIds(uid, _ids);
    } catch (_) {
      // Offline or rules: keep local favorites.
    }
  }

  Future<void> _pushCloudIfEligible() async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u != null && !u.isAnonymous) {
      try {
        await _firestore.setFavoriteCheckpointIds(u.uid, _ids);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    final StreamSubscription<User?>? s = _authSub;
    _authSub = null;
    unawaited(s?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
