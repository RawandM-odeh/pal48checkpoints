/// نص وقت نسبي بالعربية — دقة أعلى للدقائق والدمج «ساعة و دقائق» / «يوم و ساعات».
///
/// لا يُستخدم `intl` لتقليل الاعتماديات.
const int _kMinutesPerHour = 60;
const int _kHoursPerDay = 24;
const int _kMinutesPerDay = _kMinutesPerHour * _kHoursPerDay;

String arabicRelativeSince(DateTime? updated) {
  if (updated == null) {
    return 'لا وقت محدَّث';
  }

  Duration diff = DateTime.now().difference(updated);
  if (diff.isNegative) {
    diff = Duration.zero;
  }

  final int totalMinutes = diff.inMinutes;
  if (totalMinutes < 1) {
    return 'الآن';
  }

  /// أقل من 24 ساعة: ساعات (ومعها الدقائق المتبقية عند وجودها).
  if (totalMinutes < _kMinutesPerDay) {
    return _arabicLessThanOneDayPhrase(totalMinutes);
  }

  /// باقِ الدقائق من [totalMinutes] أدق من [Duration.inHours] عند حدّ 24 ساعة.
  final int days = totalMinutes ~/ _kMinutesPerDay;

  /// أقل من أسبوعين: أيام؛ مع باقِ دقيق للساعات/الدقائق ضمن ذلك النطاق.
  if (days < 14) {
    final int remMinutes = totalMinutes % _kMinutesPerDay;
    if (remMinutes == 0) {
      return _arabicDaysPhrase(days);
    }
    final int remainderHours = remMinutes ~/ _kMinutesPerHour;
    final int remainderMins = remMinutes % _kMinutesPerHour;
    if (remainderHours == 0) {
      return '${_arabicDaysFragment(days)} و '
          '${_arabicMinutesFragment(remainderMins)}';
    }
    if (remainderMins == 0) {
      return '${_arabicDaysFragment(days)} و '
          '${_arabicHoursFragment(remainderHours)}';
    }
    return '${_arabicDaysFragment(days)} و '
        '${_arabicHoursFragment(remainderHours)} و '
        '${_arabicMinutesFragment(remainderMins)}';
  }

  final int weeks = days ~/ 7;
  return _arabicWeeksPhrase(weeks);
}

String _arabicLessThanOneDayPhrase(int totalMinutes) {
  if (totalMinutes < _kMinutesPerHour) {
    return _arabicMinutesWithSince(totalMinutes);
  }
  final int hours = totalMinutes ~/ _kMinutesPerHour;
  final int mins = totalMinutes % _kMinutesPerHour;
  if (mins == 0) {
    return _arabicHoursWithSince(hours);
  }
  return 'منذ ${_arabicHoursFragment(hours)} و ${_arabicMinutesFragment(mins)}';
}

String _arabicMinutesWithSince(int minutes) {
  return 'منذ ${_arabicMinutesFragment(minutes)}';
}

/// دقائق بصيغة عربية مألوفة (بدون البادئة «منذ») — للاستخدام المركَّب.
String _arabicMinutesFragment(int minutes) {
  if (minutes == 1) {
    return 'دقيقة';
  }
  if (minutes == 2) {
    return 'دقيقتين';
  }
  if (minutes <= 10) {
    return '$minutes دقائق';
  }
  return '$minutes دقيقة';
}

String _arabicHoursWithSince(int hours) {
  return 'منذ ${_arabicHoursFragment(hours)}';
}

/// ساعات بصيغة عربية مألوفة (بدون «منذ»).
String _arabicHoursFragment(int hours) {
  if (hours == 1) {
    return 'ساعة';
  }
  if (hours == 2) {
    return 'ساعتين';
  }
  if (hours <= 10) {
    return '$hours ساعات';
  }
  return '$hours ساعة';
}

/// بداية العبارة «منذ …» بالأيام — تُستخدم وحدها أو قبل «و …».
String _arabicDaysFragment(int days) {
  if (days == 1) {
    return 'منذ يوم';
  }
  final String tail = _arabicDaysTail(days);
  return 'منذ $tail';
}

String _arabicDaysTail(int days) {
  if (days == 2) {
    return 'يومين';
  }
  if (days <= 10) {
    return '$days أيام';
  }
  return '$days يوماً';
}

String _arabicDaysPhrase(int days) {
  return _arabicDaysFragment(days);
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
