import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addNewUser({
    required String uid,
    required String email,
    String role = 'user',
  }) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'role': role,
    });
  }

  Future<String?> getUserRole(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['role'] as String?;
  }

  Future<String> getOrCreateUserRole({
    required String uid,
    required String email,
  }) async {
    final DocumentReference<Map<String, dynamic>> userDoc =
        _db.collection('users').doc(uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'email': email,
        'role': 'user',
      });
      return 'user';
    }

    return snapshot.data()?['role'] as String? ?? 'user';
  }
}
