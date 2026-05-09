import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// موقع الجهاز الحالي لعرض الحواجز القريبة فقط.
class UserLocationProvider extends ChangeNotifier {
  bool resolving = false;
  Position? position;
  String? errorMessageAr;

  Future<void> resolve() async {
    resolving = true;
    errorMessageAr = null;
    notifyListeners();

    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        errorMessageAr =
            'خدمات الموقع مغلقة. شغّل تحديد الموقع من إعدادات الجهاز ثم أعد المحاولة.';
        position = null;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        errorMessageAr =
            'لم يُسمح بالوصول للموقع. اسمح للتطبيق من الإعدادات لعرض الحواجز القريبة.';
        position = null;
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        errorMessageAr =
            'تم رفض إذن الموقع بشكل دائم. افتح إعدادات التطبيق وفعّل الموقع.';
        position = null;
        return;
      }

      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      errorMessageAr = null;
    } catch (e, st) {
      debugPrint('UserLocationProvider.resolve failed: $e\n$st');
      position = null;
      errorMessageAr =
          'تعذّر تحديد موقعك. تأكد من الإنترنت والـ GPS ثم أعد المحاولة.';
    } finally {
      resolving = false;
      notifyListeners();
    }
  }
}
