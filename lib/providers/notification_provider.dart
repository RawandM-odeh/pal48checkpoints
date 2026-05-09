import 'package:flutter/foundation.dart';

/// Keeps recent in-app notification lines shown on the user screen (foreground flows).
class NotificationProvider extends ChangeNotifier {
  final List<String> _entries = <String>[];

  List<String> get entries => List.unmodifiable(_entries);

  void addForegroundLine(String title, String body) {
    final String line =
        '${title.trim().isEmpty ? 'إشعار' : title.trim()}: ${body.trim()}';
    _entries.insert(0, line);
    if (_entries.length > 30) {
      _entries.removeLast();
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
