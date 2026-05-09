import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Firestore (camelCase): `entranceStatus`, `exitStatus`, `entranceUpdatedAt`, `exitUpdatedAt`.
/// Reads legacy `updatedAt`, snake_case timestamps, and single `status` when needed.
class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.name,
    required this.location,
    required this.entranceStatus,
    required this.exitStatus,
    this.entranceUpdatedAt,
    this.exitUpdatedAt,
  });

  final String id;
  final String name;
  final String location;
  final String entranceStatus;
  final String exitStatus;
  final DateTime? entranceUpdatedAt;
  final DateTime? exitUpdatedAt;

  factory Checkpoint.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Checkpoint.fromMap(doc.id, doc.data());
  }

  factory Checkpoint.fromMap(String id, Map<String, dynamic> map) {
    final ({String entrance, String exit}) dirs = readDirections(map);
    final ({DateTime? entrance, DateTime? exit}) times =
        _parseDirectionTimes(map);
    return Checkpoint(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      location: (map['location'] as String? ?? '').trim(),
      entranceStatus: dirs.entrance,
      exitStatus: dirs.exit,
      entranceUpdatedAt: times.entrance,
      exitUpdatedAt: times.exit,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'location': location,
      'entranceStatus': entranceStatus,
      'exitStatus': exitStatus,
    };
  }

  static ({DateTime? entrance, DateTime? exit}) _parseDirectionTimes(
    Map<String, dynamic> d,
  ) {
    final DateTime? entrance = _firstDate(d, const <String>[
      'entranceUpdatedAt',
      'entrance_updated_at',
      'updatedAt',
    ]);
    final DateTime? exit = _firstDate(d, const <String>[
      'exitUpdatedAt',
      'exit_updated_at',
      'updatedAt',
    ]);
    return (entrance: entrance, exit: exit);
  }

  static DateTime? _firstDate(Map<String, dynamic> d, List<String> keys) {
    for (final String k in keys) {
      if (!d.containsKey(k)) {
        continue;
      }
      final DateTime? v = _parseDate(d[k]);
      if (v != null) {
        return v;
      }
    }
    return null;
  }

  /// Accepts Firestore [Timestamp], ISO-8601 [String], or null.
  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final String s = value.trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }
    return null;
  }

  /// Normalized entrance / exit from Firestore (supports legacy fields).
  static ({String entrance, String exit}) readDirections(
    Map<String, dynamic> d,
  ) {
    final String legacyFallback =
        CheckpointStatus.normalize(_rawStatus(d['status']));
    final String entrance = CheckpointStatus.normalize(
      _directionalOrFallback(
        _firstNonEmptyString(d, <String>['entranceStatus', 'entrance_status']),
        legacyFallback,
      ),
    );
    final String exit = CheckpointStatus.normalize(
      _directionalOrFallback(
        _firstNonEmptyString(d, <String>['exitStatus', 'exit_status']),
        legacyFallback,
      ),
    );
    return (entrance: entrance, exit: exit);
  }

  static String? _firstNonEmptyString(
    Map<String, dynamic> d,
    List<String> keys,
  ) {
    for (final String k in keys) {
      final Object? v = d[k];
      if (v is String && v.trim().isNotEmpty) {
        return v.trim();
      }
    }
    return null;
  }

  static String _directionalOrFallback(String? field, String legacyFallback) {
    if (field != null && field.isNotEmpty) {
      return field;
    }
    return legacyFallback;
  }

  static String _rawStatus(Object? legacy) {
    if (legacy is String && legacy.trim().isNotEmpty) {
      return legacy.trim();
    }
    return CheckpointStatus.open;
  }
}

abstract final class CheckpointStatus {
  static const String open = 'open';
  static const String closed = 'closed';
  static const String crowded = 'crowded';

  static const List<String> all = <String>[
    open,
    closed,
    crowded,
  ];

  static String normalize(String value) {
    final String v = value.toLowerCase().trim();
    if (all.contains(v)) {
      return v;
    }
    return open;
  }

  /// Short Arabic label (e.g. admin rows).
  static String labelAr(String status) {
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return 'مغلق';
      case CheckpointStatus.crowded:
        return 'مزدحم';
      case CheckpointStatus.open:
      default:
        return 'مفتوح';
    }
  }

  /// Badge copy for user cards: سالك ✓ / مغلق ✗ / مزدحم ~
  static String badgeLabelAr(String status) {
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return 'مغلق ✗';
      case CheckpointStatus.crowded:
        return 'مزدحم ~';
      case CheckpointStatus.open:
      default:
        return 'سالك ✓';
    }
  }

  static ({Color bg, Color fg}) badgeColors(String status) {
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return (
          bg: const Color(0xFFFFE4E6),
          fg: const Color(0xFFB91C1C),
        );
      case CheckpointStatus.crowded:
        return (
          bg: const Color(0xFFFEF9C3),
          fg: const Color(0xFFEA580C),
        );
      case CheckpointStatus.open:
      default:
        return (
          bg: const Color(0xFFE5F7ED),
          fg: const Color(0xFF166534),
        );
    }
  }

  static Color dotColor(BuildContext context, String status) {
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return Theme.of(context).colorScheme.error;
      case CheckpointStatus.crowded:
        return const Color(0xFFEA580C);
      case CheckpointStatus.open:
      default:
        return Colors.green.shade700;
    }
  }
}
