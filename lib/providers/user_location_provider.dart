import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// موقع الجهاز الحالي لعرض الحواجز القريبة فقط.
class UserLocationProvider extends ChangeNotifier {
  bool resolving = false;
  Position? position;
  String? errorMessageAr;

  /// متزامن مع وضع «أقرب الحواجز» في الواجهة (يفعّل تتبّع الموقع المتقطع).
  bool nearestModeActive = false;

  StreamSubscription<Position>? _positionSub;

  void setNearestModeActive(bool active) {
    nearestModeActive = active;
    if (!active) {
      _cancelPositionStream();
      errorMessageAr = null;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessageAr = null;
    notifyListeners();
  }

  void _cancelPositionStream() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _attachPositionStream() {
    _cancelPositionStream();
    if (kIsWeb || !nearestModeActive) {
      return;
    }
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 35,
      ),
    ).listen(
      (Position p) {
        position = p;
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('UserLocationProvider position stream: $e\n$st');
      },
    );
  }

  Future<void> resolve() async {
    resolving = true;
    errorMessageAr = null;
    notifyListeners();

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (nearestModeActive) {
          errorMessageAr =
              'خدمات الموقع مغلقة. شغّل تحديد الموقع من إعدادات الجهاز ثم أعد المحاولة.';
        }
        position = null;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (nearestModeActive) {
          errorMessageAr =
              'لم يُسمح بالوصول للموقع. اسمح للتطبيق من الإعدادات لعرض الحواجز القريبة.';
        }
        position = null;
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (nearestModeActive) {
          errorMessageAr =
              'تم رفض إذن الموقع بشكل دائم. افتح إعدادات التطبيق وفعّل الموقع.';
        }
        position = null;
        return;
      }

      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      errorMessageAr = null;
      _attachPositionStream();
    } catch (e, st) {
      debugPrint('UserLocationProvider.resolve failed: $e\n$st');
      position = null;
      if (nearestModeActive) {
        errorMessageAr =
            'تعذّر تحديد موقعك. تأكد من الإنترنت والـ GPS ثم أعد المحاولة.';
      }
    } finally {
      resolving = false;
      if (!nearestModeActive) {
        errorMessageAr = null;
        _cancelPositionStream();
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancelPositionStream();
    super.dispose();
  }
}
