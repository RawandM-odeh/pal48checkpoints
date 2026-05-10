import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/request_device_position.dart';

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
      final DeviceLocationResult r = await requestDeviceLocation();
      if (!r.isSuccess) {
        position = null;
        if (nearestModeActive) {
          errorMessageAr = r.failureKind!.descriptionAr;
        }
        return;
      }
      position = r.position;
      errorMessageAr = null;
      _attachPositionStream();
    } catch (e, st) {
      debugPrint('UserLocationProvider.resolve failed: $e\n$st');
      position = null;
      if (nearestModeActive) {
        errorMessageAr =
            DeviceLocationFailureKind.unavailable.descriptionAr;
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
