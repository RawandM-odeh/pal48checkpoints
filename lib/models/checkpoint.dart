import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/geo_distance.dart';

/// مصدر كتابة الحالة في الخادم (لوحة الإدارة مقابل مستخدم التطبيق).
enum CheckpointUpdateSource { admin, user }

/// عنصر واحد في سجل التحديثات المخزَّن في الوثيقة (حد أقصى 6 في الخادم).
class CheckpointHistoryEntry {
  const CheckpointHistoryEntry({
    required this.at,
    required this.entranceStatus,
    required this.exitStatus,
    required this.source,
  });

  final DateTime at;
  final String entranceStatus;
  final String exitStatus;

  /// مصدر السجل في Firestore (مثل `app`، `admin`، `telegram`، …).
  final String source;

  static CheckpointHistoryEntry? tryParse(dynamic raw) {
    if (raw == null) {
      return null;
    }
    final Map<String, dynamic> map = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    final DateTime? at = Checkpoint._historyEntryDate(map['at']);
    if (at == null) {
      return null;
    }
    final ({String entrance, String exit}) dirs = Checkpoint.readDirections(
      map,
    );
    final String srcRaw = (map['source'] is String
        ? (map['source'] as String).trim().toLowerCase()
        : '');
    final String source = srcRaw.isNotEmpty ? srcRaw : 'admin';
    return CheckpointHistoryEntry(
      at: at,
      entranceStatus: dirs.entrance,
      exitStatus: dirs.exit,
      source: source,
    );
  }
}

/// Firestore: canonical directional fields use snake_case (`entrance_status`, …);
/// camelCase kept readable-only for older docs.
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
    this.entranceSource,
    this.exitSource,
    this.statusHistory = const <CheckpointHistoryEntry>[],
    this.reportTags = const <String>[],
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

  /// مصدر آخر تحديث للدخول (`telegram`، `app`، `admin`، …).
  final String? entranceSource;

  /// مصدر آخر تحديث للخروج.
  final String? exitSource;

  /// آخر التحديثات كما خُزّنت في `status_history` (الأحدث أولاً).
  final List<CheckpointHistoryEntry> statusHistory;
  final List<String> reportTags;

  factory Checkpoint.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Checkpoint.fromMap(doc.id, doc.data());
  }

  factory Checkpoint.fromMap(String id, Map<String, dynamic> map) {
    final ({String entrance, String exit}) dirs = readDirections(map);
    final ({DateTime? entrance, DateTime? exit}) times = _parseDirectionTimes(
      map,
    );
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
      entranceSource: _parseUpdateSource(map, const <String>[
        'entrance_source',
        'entranceSource',
      ]),
      exitSource: _parseUpdateSource(map, const <String>[
        'exit_source',
        'exitSource',
      ]),
      statusHistory: _parseStatusHistory(
        map['status_history'] ?? map['statusHistory'],
      ),
      reportTags: readReportTags(map),
    );
  }

  static List<CheckpointHistoryEntry> _parseStatusHistory(dynamic value) {
    if (value is! List) {
      return const <CheckpointHistoryEntry>[];
    }
    final List<CheckpointHistoryEntry> out = <CheckpointHistoryEntry>[];
    for (final Object? item in value) {
      final CheckpointHistoryEntry? e = CheckpointHistoryEntry.tryParse(item);
      if (e != null) {
        out.add(e);
      }
    }
    return List<CheckpointHistoryEntry>.unmodifiable(out);
  }

  static String? _parseUpdateSource(Map<String, dynamic> d, List<String> keys) {
    final String? s = _firstNonEmptyString(d, keys);
    if (s == null) {
      return null;
    }
    return s.trim().toLowerCase();
  }

  static DateTime? _historyEntryDate(dynamic value) {
    return _parseDate(value);
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

  /// تحديث من التطبيق (وليس تليغرام أو مصدر خارجي آخر).
  static bool isInAppUpdateSource(String? source) {
    if (source == null) {
      return false;
    }
    final String x = source.trim().toLowerCase();
    return x == 'user' || x == 'app';
  }

  /// إحداثيات من حقول شائعة أو [GeoPoint] تحت `geo` / `coordinates`.
  static ({double? lat, double? lng}) readCoordinates(
    Map<String, dynamic> map,
  ) {
    final Object? g = map['geo'] ?? map['coordinates'];
    if (g is GeoPoint) {
      return (lat: g.latitude, lng: g.longitude);
    }
    final double? lat =
        _readCoordinate(map['latitude']) ?? _readCoordinate(map['lat']);
    final double? lng =
        _readCoordinate(map['longitude']) ??
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
    if (value is String) {
      final String s = value.trim().replaceAll(',', '.');
      if (s.isEmpty) {
        return null;
      }
      return double.tryParse(s);
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
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'entrance_status': CheckpointStatus.normalize(entranceStatus),
      'exit_status': CheckpointStatus.normalize(exitStatus),
      if (reportTags.isNotEmpty) 'reportTags': List<String>.from(reportTags),
    };
  }

  /// Optional tags array; backwards-compatible when absent or malformed.
  static List<String> readReportTags(Map<String, dynamic> map) {
    final Object? raw = map['reportTags'] ?? map['report_tags'];
    if (raw == null) {
      return const <String>[];
    }
    if (raw is! Iterable<dynamic>) {
      return const <String>[];
    }
    final List<String> buf = <String>[];
    for (final Object? e in raw) {
      if (e is String && e.trim().isNotEmpty) {
        buf.add(e.trim());
      }
    }
    return CheckpointReportTag.normalizeList(buf);
  }

  static ({DateTime? entrance, DateTime? exit}) _parseDirectionTimes(
    Map<String, dynamic> d,
  ) {
    final DateTime? entrance = _firstDate(d, const <String>[
      'entrance_updated_at',
      'entranceUpdatedAt',
      'updatedAt',
    ]);
    final DateTime? exit = _firstDate(d, const <String>[
      'exit_updated_at',
      'exitUpdatedAt',
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
    final String legacyFallback = CheckpointStatus.normalize(
      _rawStatus(d['status']),
    );
    final String entrance = CheckpointStatus.normalize(
      _directionalOrFallback(
        _firstNonEmptyString(d, <String>['entrance_status', 'entranceStatus']),
        legacyFallback,
      ),
    );
    final String exit = CheckpointStatus.normalize(
      _directionalOrFallback(
        _firstNonEmptyString(d, <String>['exit_status', 'exitStatus']),
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

/// Keys stored under `reportTags` on checkpoint documents.
abstract final class CheckpointReportTag {
  static const String inspection = 'inspection';
  static const String trafficAccident = 'traffic_accident';
  static const String trafficDensity = 'traffic_density';
  static const String maintenance = 'maintenance';
  static const String badWeather = 'bad_weather';

  static const List<String> allowedKeys = <String>[
    inspection,
    trafficAccident,
    trafficDensity,
    maintenance,
    badWeather,
  ];

  static final Set<String> _allowed = allowedKeys.toSet();

  static List<String> normalizeList(Iterable<String> values) {
    final Set<String> out = <String>{};
    for (final String s in values) {
      final String t = s.trim().toLowerCase();
      if (_allowed.contains(t)) {
        out.add(t);
      }
    }
    final List<String> list = out.toList()..sort();
    return List<String>.unmodifiable(list);
  }
}

abstract final class CheckpointStatus {
  static const String open = 'open';
  static const String closed = 'closed';
  static const String crowded = 'crowded';
  static const String armyPresent = 'army_present';
  static const String settlersPresent = 'settlers_present';

  /// Canonical order for forms, segmented controls, and sheets.
  static const List<String> all = <String>[
    open,
    crowded,
    closed,
    armyPresent,
    settlersPresent,
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
        return 'أزمة';
      case CheckpointStatus.armyPresent:
        return 'جيش';
      case CheckpointStatus.settlersPresent:
        return 'مستوطنون';
      case CheckpointStatus.open:
      default:
        return 'مفتوح';
    }
  }

  /// Badge copy for user cards: سالك ✓ / مغلق ✗ / أزمة ~ / جيش / مستوطنون
  static String badgeLabelAr(String status) {
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return 'مغلق ✗';
      case CheckpointStatus.crowded:
        return 'أزمة ~';
      case CheckpointStatus.armyPresent:
        return 'جيش ⚠';
      case CheckpointStatus.settlersPresent:
        return 'مستوطنون ⚠';
      case CheckpointStatus.open:
      default:
        return 'سالك ✓';
    }
  }

  static ({Color bg, Color fg}) badgeColors(String status) {
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return (bg: const Color(0xFFFFE4E6), fg: const Color(0xFFB91C1C));
      case CheckpointStatus.crowded:
        return (bg: const Color(0xFFFEF9C3), fg: const Color(0xFFEA580C));
      case CheckpointStatus.armyPresent:
        return (bg: const Color(0xFFFFF7D6), fg: const Color(0xFF92400E));
      case CheckpointStatus.settlersPresent:
        return (bg: const Color(0xFFF3E8FF), fg: const Color(0xFF7E22CE));
      case CheckpointStatus.open:
      default:
        return (bg: const Color(0xFFE5F7ED), fg: const Color(0xFF166534));
    }
  }

  static Color dotColor(BuildContext context, String status) {
    switch (normalize(status)) {
      case CheckpointStatus.closed:
        return Theme.of(context).colorScheme.error;
      case CheckpointStatus.crowded:
        return const Color(0xFFEA580C);
      case CheckpointStatus.armyPresent:
        return const Color(0xFFD97706);
      case CheckpointStatus.settlersPresent:
        return const Color(0xFF9333EA);
      case CheckpointStatus.open:
      default:
        return Colors.green.shade700;
    }
  }
}
