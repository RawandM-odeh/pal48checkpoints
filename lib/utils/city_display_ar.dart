/// عرض اسم المدينة بالعربية فقط في الواجهة.
/// القيم المخزّنة (Firestore) تبقى كما هي؛ المطابقة تتم على النص الإنجليزي المخزَّن.
String cityDisplayNameAr(String storedCityOrLocation) {
  final String t = storedCityOrLocation.trim();
  if (t.isEmpty) {
    return t;
  }
  final String? mapped = _lookupArabicCityName(t);
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

String? _lookupArabicCityName(String raw) {
  final String key = _normalizeCityLookupKey(raw);
  if (key.isEmpty) {
    return null;
  }

  final String? direct = _enCityToAr[key];
  if (direct != null) {
    return direct;
  }

  final String? fromComma = _lookupBeforeComma(key);
  if (fromComma != null) {
    return fromComma;
  }

  final String? fromSuffix = _lookupWithStrippedSuffix(key);
  if (fromSuffix != null) {
    return fromSuffix;
  }

  final String lettersOnly = key.replaceAll(RegExp(r'[^a-z]'), '');
  if (lettersOnly.isNotEmpty) {
    return _enCityToAr[lettersOnly];
  }

  return null;
}

String _normalizeCityLookupKey(String raw) {
  return raw
      .trim()
      .replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e\ufeff\u00a0]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

String? _lookupBeforeComma(String key) {
  final int comma = key.indexOf(',');
  if (comma <= 0) {
    return null;
  }
  return _enCityToAr[key.substring(0, comma).trim()];
}

String? _lookupWithStrippedSuffix(String key) {
  const List<String> suffixes = <String>[
    ' governorate',
    ' city',
    ' area',
    ' district',
    ' region',
  ];
  for (final String suffix in suffixes) {
    if (key.endsWith(suffix)) {
      final String? hit = _enCityToAr[key.substring(0, key.length - suffix.length)];
      if (hit != null) {
        return hit;
      }
    }
  }
  return null;
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
  'salfeet': 'سلفيت',
  'salefit': 'سلفيت',
  'tulkarm': 'طولكرم',
};
