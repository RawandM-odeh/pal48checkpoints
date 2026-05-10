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
    List<String>? tags,
  }) {
    return _repository.updateStatus(id, direction, status, tags: tags);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
