/// نص وقت نسبي مبسط بالعربية (لم يُستخدم `intl` لتقليل الاعتماديات).
///
/// أقل من ساعة: الدقائق فقط. من ساعة حتى أقل من 24 ساعة: الساعات.
/// بعدها: الأيام ثم الأسابيع.
String arabicRelativeSince(DateTime? updated) {
  if (updated == null) {
    return 'لا وقت محدَّث';
  }

  Duration diff = DateTime.now().difference(updated);
  if (diff.isNegative) {
    diff = Duration.zero;
  }

  final int minutesTotal = diff.inMinutes;
  if (minutesTotal < 1) {
    return 'الآن';
  }
  if (minutesTotal < 60) {
    return _arabicMinutesPhrase(minutesTotal);
  }

  final int hoursTotal = diff.inHours;
  if (hoursTotal < 24) {
    return _arabicHoursPhrase(hoursTotal);
  }

  final int days = diff.inDays;
  if (days == 1) {
    return 'منذ يوم';
  }
  if (days < 14) {
    return _arabicDaysPhrase(days);
  }

  final int weeks = days ~/ 7;
  return _arabicWeeksPhrase(weeks);
}

String _arabicMinutesPhrase(int minutes) {
  if (minutes == 1) {
    return 'منذ دقيقة واحدة';
  }
  if (minutes == 2) {
    return 'منذ دقيقتين';
  }
  if (minutes <= 10) {
    return 'منذ $minutes دقائق';
  }
  return 'منذ $minutes دقيقة';
}

String _arabicHoursPhrase(int hours) {
  if (hours == 1) {
    return 'منذ ساعة';
  }
  if (hours == 2) {
    return 'منذ ساعتين';
  }
  if (hours <= 10) {
    return 'منذ $hours ساعات';
  }
  return 'منذ $hours ساعة';
}

String _arabicDaysPhrase(int days) {
  if (days == 2) {
    return 'منذ يومين';
  }
  if (days <= 10) {
    return 'منذ $days أيام';
  }
  return 'منذ $days يوماً';
}

String _arabicWeeksPhrase(int weeks) {
  if (weeks == 1) {
    return 'منذ أسبوع';
  }
  if (weeks == 2) {
    return 'منذ أسبوعين';
  }
  if (weeks <= 10) {
    return 'منذ $weeks أسابيع';
  }
  return 'منذ $weeks أسبوعاً';
}
