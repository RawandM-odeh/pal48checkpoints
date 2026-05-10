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
        return 'طريقة الدخول غير مفعّلة. '
            'في Firebase: Authentication → Sign-in method — فعّل البريد/كلمة المرور وGoogle.';
      case 'invalid-email':
        return 'عنوان البريد الإلكتروني غير صالح.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد أو كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد مستخدم مسبقاً. سجّل الدخول أو استخدم بريداً آخر.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً (استخدم 6 أحرف على الأقل).';
      case 'too-many-requests':
        return 'محاولات كثيرة. حاولي لاحقاً.';
      case 'popup-closed-by-user':
        return 'تم إغلاق نافذة تسجيل الدخول.';
      case 'popup-blocked':
        return 'المتصفح منع النافذة المنبثقة. اسمحي بالنوافذ المنبثقة لهذا الموقع.';
      case 'network-request-failed':
        return 'فشل الاتصال بالشبكة. تحققي من الإنترنت.';
      case 'admin-restricted-operation':
        return 'عملية الدخول هذه معطّلة في مشروع Firebase '
            '(Anonymous أو إعدادات الأمان). استخدم «تخطي لاحقًا» أو فعّل الطريقة من Console.';
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
