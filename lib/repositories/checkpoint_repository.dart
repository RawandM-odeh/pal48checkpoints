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

  static Map<String, dynamic> toMap({
    required String name,
    required String location,
    required String entranceStatus,
    required String exitStatus,
  }) {
    return <String, dynamic>{
      'name': name.trim(),
      'location': location.trim(),
      'entranceStatus': CheckpointStatus.normalize(entranceStatus),
      'exitStatus': CheckpointStatus.normalize(exitStatus),
    };
  }

  static Checkpoint fromMap(String id, Map<String, dynamic> map) {
    return Checkpoint.fromMap(id, map);
  }

  /// [direction] is `"entrance"` or `"exit"`; [status] is `open` | `closed` | `crowded`.
  Future<void> updateStatus(
    String id,
    String direction,
    String status,
  ) async {
    final String dir = direction.toLowerCase().trim();
    if (dir != 'entrance' && dir != 'exit') {
      throw ArgumentError('direction must be "entrance" or "exit"');
    }
    final String ns = CheckpointStatus.normalize(status);
    final DocumentReference<Map<String, dynamic>> docRef =
        _collection.doc(id);

    await _firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await txn.get(docRef);
      if (!snap.exists) {
        throw StateError('Checkpoint not found');
      }
      final Map<String, dynamic> d = snap.data()!;
      final ({String entrance, String exit}) dirs = Checkpoint.readDirections(d);
      final String ne = dir == 'entrance' ? ns : dirs.entrance;
      final String nx = dir == 'exit' ? ns : dirs.exit;

      final Map<String, Object?> patch = <String, Object?>{
        'entranceStatus': ne,
        'exitStatus': nx,
      };
      if (dir == 'entrance') {
        patch['entranceUpdatedAt'] = FieldValue.serverTimestamp();
      } else {
        patch['exitUpdatedAt'] = FieldValue.serverTimestamp();
      }
      txn.update(docRef, patch);
    });
  }

  Future<void> addCheckpoint({
    required String name,
    required String location,
    String entranceStatus = CheckpointStatus.open,
    String exitStatus = CheckpointStatus.open,
  }) async {
    final Map<String, dynamic> base = toMap(
      name: name,
      location: location,
      entranceStatus: entranceStatus,
      exitStatus: exitStatus,
    );
    final FieldValue ts = FieldValue.serverTimestamp();
    await _collection.add(<String, Object?>{
      ...base,
      'entranceUpdatedAt': ts,
      'exitUpdatedAt': ts,
    });
  }

  Future<void> deleteCheckpoint(String checkpointId) async {
    await _collection.doc(checkpointId).delete();
  }
}
