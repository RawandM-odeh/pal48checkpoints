import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/checkpoint.dart';

class CheckpointRepository {
  CheckpointRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('checkpoints');

  Stream<List<Checkpoint>> watchCheckpoints() {
    return _collection.snapshots().map(
          (QuerySnapshot<Map<String, dynamic>> snap) {
            final List<Checkpoint> list = snap.docs
                .map(Checkpoint.fromDocument)
                .toList(growable: false);
            list.sort(
              (Checkpoint a, Checkpoint b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
            return list;
          },
        );
  }

  Future<void> updateStatus({
    required String checkpointId,
    required String status,
  }) async {
    final String normalized = CheckpointStatus.normalize(status);
    await _collection.doc(checkpointId).update(<String, Object?>{
      'status': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addCheckpoint({
    required String name,
    required String location,
    required String status,
  }) async {
    final String normalized = CheckpointStatus.normalize(status);
    await _collection.add(<String, Object?>{
      'name': name.trim(),
      'location': location.trim(),
      'status': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCheckpoint(String checkpointId) async {
    await _collection.doc(checkpointId).delete();
  }
}
