/// نص وقت نسبي مبسط بالعربية (لم يُستخدم `intl` لتقليل الاعتماديات).
String arabicRelativeSince(DateTime? updated) {
  if (updated == null) {
    return 'لا وقت محدَّث';
  }

  Duration diff = DateTime.now().difference(updated);
  if (diff.isNegative) {
    diff = Duration.zero;
  }

  final int minutes = diff.inMinutes;
  if (minutes < 1) {
    return 'الآن';
  }
  if (minutes == 1) {
    return 'منذ دقيقة واحدة';
  }
  if (minutes < 60) {
    return 'منذ $minutes دقيقة';
  }

  final int hours = diff.inHours;
  if (hours == 1) {
    return 'منذ ساعة';
  }
  if (hours < 24) {
    return 'منذ $hours ساعة';
  }

  final int days = diff.inDays;
  if (days == 1) {
    return 'منذ يوم';
  }
  if (days < 14) {
    return 'منذ $days أيام';
  }

  final int weeks = days ~/ 7;
  return 'منذ $weeks أسبوع';
}
