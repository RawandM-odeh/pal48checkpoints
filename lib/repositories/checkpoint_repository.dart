import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/checkpoint.dart';

class CheckpointRepository {
  CheckpointRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int _maxStatusHistory = 6;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('checkpoints');

  /// مصدر التحديث في الوثيقة — `app` لمستخدم التطبيق، `admin` للوحة الإدارة.
  /// لا يُستخدم `FieldValue.serverTimestamp()` داخل عناصر المصفوفة؛ بعض عملاء Firestore يرفضون ذلك فيعمل الكتابة بالكامل.
  static String _sourceKey(CheckpointUpdateSource source) =>
      source == CheckpointUpdateSource.admin ? 'admin' : 'app';

  /// يضيف صفاً في بداية `status_history` ويقلّص الطول إلى [_maxStatusHistory].
  static List<dynamic> _nextStatusHistory({
    required Map<String, dynamic> previousDoc,
    required String entrance,
    required String exit,
    required CheckpointUpdateSource source,
  }) {
    final Object? raw = previousDoc['status_history'];
    final List<dynamic> existing = raw is List
        ? List<dynamic>.from(raw)
        : <dynamic>[];
    final Map<String, Object?> head = <String, Object?>{
      'at': Timestamp.fromDate(DateTime.now().toUtc()),
      'entrance_status': entrance,
      'exit_status': exit,
      'source': _sourceKey(source),
    };
    final List<dynamic> next = <dynamic>[head, ...existing];
    if (next.length > _maxStatusHistory) {
      next.removeRange(_maxStatusHistory, next.length);
    }
    return next;
  }

  Stream<List<Checkpoint>> watchCheckpoints() {
    return _collection.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snap,
    ) {
      final List<Checkpoint> list = snap.docs
          .map(Checkpoint.fromDocument)
          .toList(growable: false);
      list.sort(
        (Checkpoint a, Checkpoint b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    });
  }

  /// Deduped list: non-empty [nameAr], [nameEn], then tokens from [extraRaw]
  /// split by newline or comma (Arabic or ASCII).
  static List<String> mergeAliases({
    required String nameAr,
    required String nameEn,
    String extraRaw = '',
  }) {
    final List<String> out = <String>[];
    void take(String s) {
      final String t = s.trim();
      if (t.isEmpty) {
        return;
      }
      if (!out.contains(t)) {
        out.add(t);
      }
    }

    take(nameAr);
    take(nameEn);
    for (final String part in extraRaw.split(RegExp(r'[\r\n,،]'))) {
      take(part);
    }
    return out;
  }

  static Checkpoint fromMap(String id, Map<String, dynamic> map) {
    return Checkpoint.fromMap(id, map);
  }

  /// [direction] is `"entrance"` or `"exit"`; [status] is a [CheckpointStatus] value.
  /// When [tags] is non-null, writes `reportTags` (normalized); when null, leaves field unchanged.
  Future<void> updateStatus(
    String id,
    String direction,
    String status, {
    CheckpointUpdateSource source = CheckpointUpdateSource.user,
    List<String>? tags,
  }) async {
    final String dir = direction.toLowerCase().trim();
    if (dir != 'entrance' && dir != 'exit') {
      throw ArgumentError('direction must be "entrance" or "exit"');
    }
    final String ns = CheckpointStatus.normalize(status);
    final DocumentReference<Map<String, dynamic>> docRef = _collection.doc(id);

    await _firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await txn.get(docRef);
      if (!snap.exists) {
        throw StateError('Checkpoint not found');
      }
      final Map<String, dynamic> d = snap.data()!;
      final ({String entrance, String exit}) dirs = Checkpoint.readDirections(
        d,
      );
      final String ne = dir == 'entrance' ? ns : dirs.entrance;
      final String nx = dir == 'exit' ? ns : dirs.exit;

      final Map<String, Object?> patch = <String, Object?>{
        'entrance_status': ne,
        'exit_status': nx,
        if (dir == 'entrance') ...<String, Object?>{
          'entrance_updated_at': FieldValue.serverTimestamp(),
          'entrance_source': _sourceKey(source),
        },
        if (dir == 'exit') ...<String, Object?>{
          'exit_updated_at': FieldValue.serverTimestamp(),
          'exit_source': _sourceKey(source),
        },
        'status_history': _nextStatusHistory(
          previousDoc: d,
          entrance: ne,
          exit: nx,
          source: source,
        ),
        'entranceStatus': FieldValue.delete(),
        'exitStatus': FieldValue.delete(),
        'entranceUpdatedAt': FieldValue.delete(),
        'exitUpdatedAt': FieldValue.delete(),
      };
      if (tags != null) {
        patch['reportTags'] = List<String>.from(
          CheckpointReportTag.normalizeList(tags),
        );
      }
      txn.update(docRef, patch);
    });
  }

  /// تحديث الاتجاهين في معاملة واحدة وسجل تاريخ واحد (مناسب لمستخدم التطبيق).
  Future<void> updateBothStatuses(
    String id, {
    required String entranceStatus,
    required String exitStatus,
    CheckpointUpdateSource source = CheckpointUpdateSource.user,
    List<String>? tags,
  }) async {
    final String ne = CheckpointStatus.normalize(entranceStatus);
    final String nx = CheckpointStatus.normalize(exitStatus);
    final DocumentReference<Map<String, dynamic>> docRef = _collection.doc(id);

    await _firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await txn.get(docRef);
      if (!snap.exists) {
        throw StateError('Checkpoint not found');
      }
      final Map<String, dynamic> d = snap.data()!;
      final Map<String, Object?> patch = <String, Object?>{
        'entrance_status': ne,
        'exit_status': nx,
        'entrance_updated_at': FieldValue.serverTimestamp(),
        'exit_updated_at': FieldValue.serverTimestamp(),
        'entrance_source': _sourceKey(source),
        'exit_source': _sourceKey(source),
        'status_history': _nextStatusHistory(
          previousDoc: d,
          entrance: ne,
          exit: nx,
          source: source,
        ),
        'entranceStatus': FieldValue.delete(),
        'exitStatus': FieldValue.delete(),
        'entranceUpdatedAt': FieldValue.delete(),
        'exitUpdatedAt': FieldValue.delete(),
      };
      if (tags != null) {
        patch['reportTags'] = List<String>.from(
          CheckpointReportTag.normalizeList(tags),
        );
      }
      txn.update(docRef, patch);
    });
  }

  /// Doc ID = trimmed [nameAr]. Does not write legacy `name` / `location`.
  Future<void> addCheckpoint({
    required String nameAr,
    required String nameEn,
    required double latitude,
    required double longitude,
    String city = '',
    String extraAliases = '',
    String entranceStatus = CheckpointStatus.open,
    String exitStatus = CheckpointStatus.open,
  }) async {
    final String docId = nameAr.trim();
    if (docId.isEmpty) {
      throw ArgumentError('اسم الحاجز بالعربي مطلوب');
    }
    if (docId.contains('/')) {
      throw ArgumentError('لا يُسمح بالرمز «/» في الاسم العربي');
    }

    final DocumentReference<Map<String, dynamic>> docRef = _collection.doc(
      docId,
    );
    final DocumentSnapshot<Map<String, dynamic>> existing = await docRef.get();
    if (existing.exists) {
      throw StateError('يوجد حاجز بنفس الاسم العربي (معرّف الوثيقة)');
    }

    final FieldValue ts = FieldValue.serverTimestamp();
    final List<String> aliases = mergeAliases(
      nameAr: docId,
      nameEn: nameEn.trim(),
      extraRaw: extraAliases,
    );

    await docRef.set(<String, Object?>{
      'name_ar': docId,
      'name_en': nameEn.trim(),
      'city': city.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'aliases': aliases,
      'entrance_status': CheckpointStatus.normalize(entranceStatus),
      'exit_status': CheckpointStatus.normalize(exitStatus),
      'entrance_updated_at': ts,
      'exit_updated_at': ts,
      'entrance_source': 'admin',
      'exit_source': 'admin',
      'priority': 1,
      'type': 'main_checkpoint',
    });
  }

  Future<void> deleteCheckpoint(String checkpointId) async {
    await _collection.doc(checkpointId).delete();
  }

  /// قراءة بيانات الوثيقة الخام (لتعبئة نموذج التعديل).
  Future<Map<String, dynamic>> getCheckpointDocument(String checkpointId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _collection.doc(checkpointId).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Checkpoint not found');
    }
    return snap.data()!;
  }

  /// تحديث حقول تعريف الحاجز دون تغيير معرّف الوثيقة ([documentId] = الاسم العربي الحالي).
  Future<void> updateCheckpointMeta({
    required String documentId,
    required String nameEn,
    required double latitude,
    required double longitude,
    required String city,
    required String extraAliases,
  }) async {
    final String docId = documentId.trim();
    if (docId.isEmpty) {
      throw ArgumentError('معرّف الحاجز فارغ');
    }
    final List<String> aliases = mergeAliases(
      nameAr: docId,
      nameEn: nameEn.trim(),
      extraRaw: extraAliases,
    );
    await _collection.doc(docId).update(<String, Object?>{
      'name_en': nameEn.trim(),
      'city': city.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'aliases': aliases,
    });
  }

  /// نقل الوثيقة إلى معرّف جديد عند تغيير الاسم العربي؛ يُحافظ على باقي الحقول (حالة، سجل، …).
  Future<void> migrateCheckpointDocument({
    required String oldDocumentId,
    required String newNameAr,
    required String nameEn,
    required double latitude,
    required double longitude,
    required String city,
    required String extraAliases,
  }) async {
    final String oldId = oldDocumentId.trim();
    final String newId = newNameAr.trim();
    if (oldId.isEmpty || newId.isEmpty) {
      throw ArgumentError('اسم الحاجز بالعربي مطلوب');
    }
    if (newId.contains('/')) {
      throw ArgumentError('لا يُسمح بالرمز «/» في الاسم العربي');
    }
    if (newId == oldId) {
      await updateCheckpointMeta(
        documentId: oldId,
        nameEn: nameEn,
        latitude: latitude,
        longitude: longitude,
        city: city,
        extraAliases: extraAliases,
      );
      return;
    }

    final DocumentReference<Map<String, dynamic>> oldRef =
        _collection.doc(oldId);
    final DocumentReference<Map<String, dynamic>> newRef =
        _collection.doc(newId);

    await _firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> oldSnap =
          await txn.get(oldRef);
      if (!oldSnap.exists || oldSnap.data() == null) {
        throw StateError('Checkpoint not found');
      }
      final DocumentSnapshot<Map<String, dynamic>> dupSnap =
          await txn.get(newRef);
      if (dupSnap.exists) {
        throw StateError('يوجد حاجز بنفس الاسم العربي الجديد');
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(oldSnap.data()!);
      data['name_ar'] = newId;
      data['name_en'] = nameEn.trim();
      data['city'] = city.trim();
      data['latitude'] = latitude;
      data['longitude'] = longitude;
      data['aliases'] = mergeAliases(
        nameAr: newId,
        nameEn: nameEn.trim(),
        extraRaw: extraAliases,
      );

      txn.set(newRef, data);
      txn.delete(oldRef);
    });
  }
}
