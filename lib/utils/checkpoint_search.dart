import '../models/checkpoint.dart';
import 'city_display_ar.dart';

/// بحث مستخدم الشاشة الرئيسية بالاسم، المدينة (عربي/إنجليزي)، أو حالة الدخول/الخروج.
bool checkpointMatchesUserSearch(Checkpoint c, String qLower) {
  if (qLower.isEmpty) {
    return true;
  }
  if (c.name.toLowerCase().contains(qLower)) {
    return true;
  }
  if (cityStoredMatchesSearchQuery(c.location, qLower)) {
    return true;
  }
  final String en = CheckpointStatus.normalize(c.entranceStatus);
  final String ex = CheckpointStatus.normalize(c.exitStatus);
  if (en.contains(qLower) || ex.contains(qLower)) {
    return true;
  }
  final String enAr = CheckpointStatus.labelAr(en).toLowerCase();
  final String exAr = CheckpointStatus.labelAr(ex).toLowerCase();
  if (enAr.contains(qLower) || exAr.contains(qLower)) {
    return true;
  }
  if (CheckpointStatus.badgeLabelAr(en).toLowerCase().contains(qLower) ||
      CheckpointStatus.badgeLabelAr(ex).toLowerCase().contains(qLower)) {
    return true;
  }
  return false;
}
