import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/firestore_service.dart';

/// «المثبتة»: حواجز يثبّتها المستخدم المسجَّل — تُحمَّل وتُكتب إلى Firestore فقط (بدون prefs).
final class SavedCheckpointsProvider extends ChangeNotifier {
  SavedCheckpointsProvider(this._firestore) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  final FirestoreService _firestore;
  StreamSubscription<User?>? _authSub;

  Set<String> _ids = <String>{};

  Set<String> get ids => Set<String>.unmodifiable(_ids);

  bool get _mayManageSaved {
    final User? u = FirebaseAuth.instance.currentUser;
    return u != null && !u.isAnonymous;
  }

  /// ضيف / مجهول: لا يُعرض أي حاجز كمُثبَّت.
  bool isSaved(String checkpointId) {
    if (!_mayManageSaved) {
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
    notifyListeners();
    unawaited(_pushCloud(u.uid));
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user != null && !user.isAnonymous) {
      await _reloadFromCloud(user.uid);
    } else {
      _ids.clear();
    }
    notifyListeners();
  }

  Future<void> _reloadFromCloud(String uid) async {
    try {
      final Set<String> cloud = await _firestore.getSavedCheckpointIds(uid);
      _ids = cloud;
    } catch (_) {
      // قواعد أو انقطاع: إفراغ قائمة المعروضة حتى لا نُضلِّل عن السحابة.
      _ids = <String>{};
    }
  }

  Future<void> _pushCloud(String uid) async {
    try {
      await _firestore.setSavedCheckpointIds(uid, _ids);
    } catch (_) {
      await _reloadFromCloud(uid);
      notifyListeners();
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
