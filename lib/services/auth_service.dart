import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Created only on mobile/desktop — never on web, or [GoogleSignIn]
  /// asserts for a web OAuth client ID at construction time.
  GoogleSignIn? _mobileGoogleSignIn;

  GoogleSignIn get _googleSignInNonWeb {
    return _mobileGoogleSignIn ??= GoogleSignIn();
  }

  /// Web uses Firebase Auth popup OAuth (no `GoogleSignIn` web client ID).
  /// Android/iOS use the `google_sign_in` plugin.
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    final GoogleSignInAccount? googleUser = await _googleSignInNonWeb.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _mobileGoogleSignIn?.signOut();
    }
    await _auth.signOut();
  }
}
