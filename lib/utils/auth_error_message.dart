import 'package:firebase_auth/firebase_auth.dart';

/// Maps Firebase Auth failures to short, actionable text (Arabic).
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'configuration-not-found':
        return 'إعدادات Firebase Authentication غير جاهزة.\n'
            'في Firebase Console: Authentication → اضغط Get started، ثم فعّل Google من Sign-in method، '
            'وتأكد أن localhost ضمن Authorized domains.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بـ Google غير مفعّل. '
            'في Firebase: Authentication → Sign-in method → Google → Enable.';
      case 'popup-closed-by-user':
        return 'تم إغلاق نافذة تسجيل الدخول.';
      case 'popup-blocked':
        return 'المتصفح منع النافذة المنبثقة. اسمحي بالنوافذ المنبثقة لهذا الموقع.';
      case 'network-request-failed':
        return 'فشل الاتصال بالشبكة. تحققي من الإنترنت.';
      default:
        return error.message?.isNotEmpty == true
            ? '${error.code}: ${error.message}'
            : error.code;
    }
  }

  final String s = error.toString();
  if (s.contains('configuration-not-found')) {
    return 'إعدادات Firebase Authentication غير جاهزة.\n'
        'في Firebase Console: Authentication → Get started، ثم فعّل Google، '
        'وتأكد أن localhost ضمن Authorized domains.';
  }
  return s;
}
