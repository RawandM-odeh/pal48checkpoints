/// عرض اسم المدينة بالعربية فقط في الواجهة.
/// القيم المخزّنة (Firestore) تبقى كما هي؛ المطابقة تتم على النص الإنجليزي المخزَّن.
String cityDisplayNameAr(String storedCityOrLocation) {
  final String t = storedCityOrLocation.trim();
  if (t.isEmpty) {
    return t;
  }
  final String? mapped = _enCityToAr[t.toLowerCase()];
  return mapped ?? t;
}

/// لمطابقة البحث: النص العربي المعروض أو النص المخزَّن الأصلي.
bool cityStoredMatchesSearchQuery(String storedLocation, String queryLower) {
  final String s = storedLocation.trim().toLowerCase();
  if (s.isEmpty) {
    return false;
  }
  if (s.contains(queryLower)) {
    return true;
  }
  return cityDisplayNameAr(storedLocation).toLowerCase().contains(queryLower);
}

/// جديلة المدن الإنجليزية المعروفة → العربية (مطابقة case-insensitive).
const Map<String, String> _enCityToAr = <String, String>{
  'bethlehem': 'بيت لحم',
  'hebron': 'الخليل',
  'jenin': 'جنين',
  'jericho': 'أريحا',
  'jerusalem': 'القدس',
  'nablus': 'نابلس',
  'qalqilya': 'قلقيلية',
  'qalqiliya': 'قلقيلية',
  'ramallah': 'رام الله',
  'salfit': 'سلفيت',
  'tulkarm': 'طولكرم',
};
