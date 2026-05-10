import 'package:intl/intl.dart';

import '../models/checkpoint.dart';
import 'ar_relative_time.dart';

/// نصوص مختصرة لصفحة المثبتة: حالة ورصد زمن مطوّل + نسبي لكل اتجاه.
List<String> savedCheckpointSubtitleLines(Checkpoint c) {
  final String e = CheckpointStatus.badgeLabelAr(c.entranceStatus);
  final String x = CheckpointStatus.badgeLabelAr(c.exitStatus);
  final DateTime? te = c.entranceUpdatedAt;
  final DateTime? tx = c.exitUpdatedAt;
  final String absE = arabicMediumDateTime(te);
  final String absX = arabicMediumDateTime(tx);
  final String relE = arabicRelativeSince(te);
  final String relX = arabicRelativeSince(tx);
  return <String>[
    'دخول — $e',
    '$absE · ($relE)',
    'خروج — $x',
    '$absX · ($relX)',
  ];
}

/// تاريخ وساعة بصيغة عربية (عرض مطوّل).
String arabicMediumDateTime(DateTime? d) {
  if (d == null) {
    return '—';
  }
  return DateFormat.yMMMd('ar').add_Hm().format(d.toLocal());
}
