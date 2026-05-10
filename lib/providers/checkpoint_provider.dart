import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/checkpoint.dart';
import '../repositories/checkpoint_repository.dart';

class CheckpointProvider extends ChangeNotifier {
  CheckpointProvider(this._repository) {
    _subscription = _repository.watchCheckpoints().listen(
      (List<Checkpoint> list) {
        _items = List<Checkpoint>.from(list);
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e, StackTrace _) {
        _loading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  final CheckpointRepository _repository;
  StreamSubscription<List<Checkpoint>>? _subscription;

  List<Checkpoint> _items = <Checkpoint>[];
  bool _loading = true;
  String? _error;

  List<Checkpoint> get items => List<Checkpoint>.unmodifiable(_items);
  bool get loading => _loading;
  String? get error => _error;

  CheckpointRepository get repository => _repository;

  Future<void> updateStatus(
    String id,
    String direction,
    String status, {
    CheckpointUpdateSource source = CheckpointUpdateSource.user,
    List<String>? tags,
  }) {
    return _repository.updateStatus(
      id,
      direction,
      status,
      source: source,
      tags: tags,
    );
  }

  Future<void> updateBothStatuses(
    String id, {
    required String entranceStatus,
    required String exitStatus,
    CheckpointUpdateSource source = CheckpointUpdateSource.user,
    List<String>? tags,
  }) {
    return _repository.updateBothStatuses(
      id,
      entranceStatus: entranceStatus,
      exitStatus: exitStatus,
      source: source,
      tags: tags,
    );
  }

  Future<Map<String, dynamic>> getCheckpointDocument(String checkpointId) {
    return _repository.getCheckpointDocument(checkpointId);
  }

  Future<void> updateCheckpointMeta({
    required String documentId,
    required String nameEn,
    required double latitude,
    required double longitude,
    required String city,
    required String extraAliases,
  }) {
    return _repository.updateCheckpointMeta(
      documentId: documentId,
      nameEn: nameEn,
      latitude: latitude,
      longitude: longitude,
      city: city,
      extraAliases: extraAliases,
    );
  }

  Future<void> migrateCheckpointDocument({
    required String oldDocumentId,
    required String newNameAr,
    required String nameEn,
    required double latitude,
    required double longitude,
    required String city,
    required String extraAliases,
  }) {
    return _repository.migrateCheckpointDocument(
      oldDocumentId: oldDocumentId,
      newNameAr: newNameAr,
      nameEn: nameEn,
      latitude: latitude,
      longitude: longitude,
      city: city,
      extraAliases: extraAliases,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
