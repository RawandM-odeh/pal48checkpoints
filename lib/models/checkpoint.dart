import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/geo_distance.dart';

/// Firestore: directional statuses + timestamps (camelCase أو snake_case).
/// الاسم: `name_ar` / `name` / `name_en` أو معرّف الوثيقة إن وُجد الاسم بالعربي كـ Doc ID.
/// المدينة: حقل `city` أو النص في `location` (لا يُقرأ `GeoPoint` كمدينة).
/// الإحداثيات: `latitude`/`longitude` أو `lat`/`lng` أو `geo` كـ [GeoPoint].
class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.name,
    required this.location,
    required this.entranceStatus,
    required this.exitStatus,
    this.latitude,
    this.longitude,
    this.entranceUpdatedAt,
    this.exitUpdatedAt,
  });

  final String id;
  final String name;
  final String location;
  final double? latitude;
  final double? longitude;
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
    final ({double? lat, double? lng}) coords = readCoordinates(map);
    return Checkpoint(
      id: id,
      name: readDisplayName(map, id),
      location: readCityOrLocation(map),
      latitude: coords.lat,
      longitude: coords.lng,
      entranceStatus: dirs.entrance,
      exitStatus: dirs.exit,
      entranceUpdatedAt: times.entrance,
      exitUpdatedAt: times.exit,
    );
  }

  /// مسافة تقريبية بالكم؛ null إذا لم تُعرَف إحداثيات الحاجز.
  double? distanceKmFrom(double userLat, double userLon) {
    final double? lat = latitude;
    final double? lng = longitude;
    if (lat == null || lng == null) {
      return null;
    }
    return haversineKm(lat, lng, userLat, userLon);
  }

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;

  /// إحداثيات من حقول شائعة أو [GeoPoint] تحت `geo` / `coordinates`.
  static ({double? lat, double? lng}) readCoordinates(Map<String, dynamic> map) {
    final Object? g = map['geo'] ?? map['coordinates'];
    if (g is GeoPoint) {
      return (lat: g.latitude, lng: g.longitude);
    }
    final double? lat = _readCoordinate(map['latitude']) ??
        _readCoordinate(map['lat']);
    final double? lng = _readCoordinate(map['longitude']) ??
        _readCoordinate(map['lng']) ??
        _readCoordinate(map['lon']);
    return (lat: lat, lng: lng);
  }

  static double? _readCoordinate(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  /// اسم الحاجز للعرض: حقول شائعة في Firestore ثم معرّف الوثيقة.
  static String readDisplayName(Map<String, dynamic> map, String docId) {
    final String? fromDoc = _firstNonEmptyString(map, const <String>[
      'name_ar',
      'nameAr',
      'name',
      'name_en',
      'nameEn',
    ]);
    if (fromDoc != null && fromDoc.isNotEmpty) {
      return fromDoc;
    }
    final String trimmedId = docId.trim();
    if (trimmedId.isNotEmpty) {
      return trimmedId;
    }
    return '';
  }

  /// مدينة أو موقع نصي: `city` ثم حقل `location` إن كان نصاً (يتجاهل GeoPoint).
  static String readCityOrLocation(Map<String, dynamic> map) {
    final String? city = _firstNonEmptyString(map, const <String>['city']);
    if (city != null && city.isNotEmpty) {
      return city;
    }
    final Object? loc = map['location'];
    if (loc is String && loc.trim().isNotEmpty) {
      return loc.trim();
    }
    return '';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
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
