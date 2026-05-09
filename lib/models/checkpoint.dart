import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Firestore checkpoints: status one of `open`, `closed`, `delayed`.
class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String location;
  final String status;
  final DateTime? updatedAt;

  factory Checkpoint.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data();
    Timestamp? ts = d['updatedAt'] as Timestamp?;
    final String raw = (d['status'] as String? ?? CheckpointStatus.open).trim();
    return Checkpoint(
      id: doc.id,
      name: (d['name'] as String? ?? '').trim(),
      location: (d['location'] as String? ?? '').trim(),
      status: CheckpointStatus.normalize(raw),
      updatedAt: ts?.toDate(),
    );
  }
}

abstract final class CheckpointStatus {
  static const String open = 'open';
  static const String closed = 'closed';
  static const String delayed = 'delayed';

  static const List<String> all = <String>[
    open,
    closed,
    delayed,
  ];

  static String normalize(String value) {
    final String v = value.toLowerCase();
    if (all.contains(v)) {
      return v;
    }
    return open;
  }

  /// Arabic labels for RTL UI.
  static String labelAr(String status) {
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return 'مغلق';
      case CheckpointStatus.delayed:
        return 'متأخر';
      case CheckpointStatus.open:
      default:
        return 'مفتوح';
    }
  }

  static Color chipColor(BuildContext context, String status) {
    final ThemeData theme = Theme.of(context);
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return theme.colorScheme.error;
      case CheckpointStatus.delayed:
        return theme.colorScheme.secondary;
      case CheckpointStatus.open:
      default:
        return Colors.green.shade700;
    }
  }
}
