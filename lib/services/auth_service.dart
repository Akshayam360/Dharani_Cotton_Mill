import 'package:firebase_auth/firebase_auth.dart';

/// Handles Firebase email/password authentication.
/// Staff, Labours, MD, Exempted — ellarukkum same login mechanism.
/// Accounts are created manually in Firebase Console (Authentication tab),
/// not through in-app registration.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Signs in with email & password.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found for this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        default:
          return 'Login failed: ${e.message}';
      }
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}