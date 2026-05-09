import 'dart:math' as math;

/// مسافة قطعة الدائرة بين نقطتين على سطح الأرض (كم).
double haversineKm(
  double lat1Deg,
  double lon1Deg,
  double lat2Deg,
  double lon2Deg,
) {
  const double earthKm = 6371;
  final double p1 = lat1Deg * math.pi / 180;
  final double p2 = lat2Deg * math.pi / 180;
  final double dLat = (lat2Deg - lat1Deg) * math.pi / 180;
  final double dLon = (lon2Deg - lon1Deg) * math.pi / 180;

  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1) *
          math.cos(p2) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthKm * c;
}
