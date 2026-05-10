import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addNewUser({
    required String uid,
    required String email,
    String role = 'user',
  }) async {
    await _db.collection('users').doc(uid).set({'email': email, 'role': role});
  }

  Future<String?> getUserRole(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return doc.data()?['role'] as String?;
  }

  Future<String> getOrCreateUserRole({
    required String uid,
    required String email,
  }) async {
    final User? authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != uid) {
      throw StateError('getOrCreateUserRole: no matching signed-in user');
    }
    final bool isAnonymous = authUser.isAnonymous;

    final DocumentReference<Map<String, dynamic>> userDoc = _db
        .collection('users')
        .doc(uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userDoc.get();

    if (!snapshot.exists) {
      final String role = isAnonymous ? 'guest' : 'user';
      await userDoc.set({'email': email, 'role': role});
      return role;
    }

    if (isAnonymous) {
      final String? existing = snapshot.data()?['role'] as String?;
      if (existing != 'guest') {
        await userDoc.update(<String, Object?>{'role': 'guest'});
      }
      return 'guest';
    }

    return snapshot.data()?['role'] as String? ?? 'user';
  }

  /// حواجز «المثبتة» المحفوظة في حساب المستخدم (`savedCheckpointIds`).
  Future<Set<String>> getSavedCheckpointIds(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) {
      return <String>{};
    }
    final Object? raw = doc.data()?['savedCheckpointIds'];
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }

  Future<void> setSavedCheckpointIds(String uid, Set<String> ids) async {
    final List<String> sorted = ids.toList()..sort();
    await _db.collection('users').doc(uid).set(<String, Object?>{
      'savedCheckpointIds': sorted,
    }, SetOptions(merge: true));
  }
}
