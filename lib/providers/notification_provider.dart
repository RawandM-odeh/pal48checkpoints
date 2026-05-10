import 'package:flutter/foundation.dart';

/// Single foreground-received line (FCM while app is active).
class ForegroundInboxEntry {
  const ForegroundInboxEntry({
    this.dedupeKey,
    required this.title,
    required this.body,
  });

  /// Matches Firestore `notifications/{id}` when present (admin broadcasts).
  final String? dedupeKey;
  final String title;
  final String body;

  String get displayLine =>
      '${title.isEmpty ? 'إشعار' : title}: ${body.isEmpty ? '' : body}';
}

/// Foreground inbox lines + helpers for merging with Firestore history (Option B).
class NotificationProvider extends ChangeNotifier {
  final List<ForegroundInboxEntry> _foregroundEntries = <ForegroundInboxEntry>[];

  List<ForegroundInboxEntry> get foregroundEntries =>
      List<ForegroundInboxEntry>.unmodifiable(_foregroundEntries);

  /// One-line preview strings (إعدادات → مسح سجل المعاينة).
  List<String> get entries =>
      _foregroundEntries.map((ForegroundInboxEntry e) => e.displayLine).toList(growable: false);

  void addForegroundLine(
    String title,
    String body, {
    String? dedupeKey,
  }) {
    final String t = title.trim();
    final String b = body.trim();
    final String? key =
        dedupeKey != null && dedupeKey.trim().isNotEmpty ? dedupeKey.trim() : null;
    if (key != null) {
      _foregroundEntries.removeWhere((ForegroundInboxEntry e) => e.dedupeKey == key);
    }
    _foregroundEntries.insert(
      0,
      ForegroundInboxEntry(dedupeKey: key, title: t, body: b),
    );
    if (_foregroundEntries.length > 30) {
      _foregroundEntries.removeLast();
    }
    notifyListeners();
  }

  void clear() {
    _foregroundEntries.clear();
    notifyListeners();
  }
}
