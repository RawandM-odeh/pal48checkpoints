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

  /// Requires **Email/Password** enabled in Firebase Console → Authentication → Sign-in method.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates a Firebase Auth account; [FirestoreService.getOrCreateUserRole] then creates `users/{uid}`.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _mobileGoogleSignIn?.signOut();
    }
    await _auth.signOut();
  }
}
