import 'package:geolocator/geolocator.dart';

/// سبب تعذُّر الحصول على الموقع.
enum DeviceLocationFailureKind {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

extension DeviceLocationFailureKindMessagesAr on DeviceLocationFailureKind {
  String get descriptionAr => switch (this) {
        DeviceLocationFailureKind.serviceDisabled =>
          'خدمات الموقع معطّلة. شغّل تحديد الموقع (GPS) من إعدادات الجهاز ثم أعد المحاولة.',
        DeviceLocationFailureKind.permissionDenied =>
          'لم يُسمح بالوصول للموقع. اسمح للمتصفّح أو التطبيق عند الطلب أو من الإعدادات.',
        DeviceLocationFailureKind.permissionDeniedForever =>
          'تم رفض إذن الموقع. افتح إعدادات المتصفّح أو التطبيق وفعّل الموقع.',
        DeviceLocationFailureKind.unavailable =>
          'تعذّر تحديد موقعك. تأكّد من الـ GPS والشبكة ثم أعد المحاولة.',
      };
}

class DeviceLocationResult {
  const DeviceLocationResult._({
    required this.position,
    required this.failureKind,
    this.cause,
  });

  factory DeviceLocationResult.ok(Position position) =>
      DeviceLocationResult._(
        position: position,
        failureKind: null,
        cause: null,
      );

  factory DeviceLocationResult.fail(
    DeviceLocationFailureKind kind, [
    Object? cause,
  ]) =>
      DeviceLocationResult._(
        position: null,
        failureKind: kind,
        cause: cause,
      );

  final Position? position;
  final DeviceLocationFailureKind? failureKind;
  final Object? cause;

  bool get isSuccess => position != null;
}

/// يطلب الإذن ويُعيد الموضع الحالي إن أمكن (خرائط، «أقرب الحواجز»، إلخ).
Future<DeviceLocationResult> requestDeviceLocation() async {
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return DeviceLocationResult.fail(
      DeviceLocationFailureKind.serviceDisabled,
    );
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    return DeviceLocationResult.fail(DeviceLocationFailureKind.permissionDenied);
  }
  if (permission == LocationPermission.deniedForever) {
    return DeviceLocationResult.fail(
      DeviceLocationFailureKind.permissionDeniedForever,
    );
  }

  try {
    final Position pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 30),
      ),
    );
    return DeviceLocationResult.ok(pos);
  } catch (e, _) {
    return DeviceLocationResult.fail(DeviceLocationFailureKind.unavailable, e);
  }
}
