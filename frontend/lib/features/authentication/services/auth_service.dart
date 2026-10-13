// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
//
// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   Stream<User?> get authStateChanges => _auth.authStateChanges();
//   User? get currentUser => _auth.currentUser;
//
//   Future<String?> register({
//     required String name,
//     required String email,
//     required String password,
//   }) async {
//     try {
//       final credential = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       await _firestore.collection('users').doc(credential.user!.uid).set({
//         'name': name,
//         'email': email,
//         'role': 'individual',
//         'organizationId': null,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//       return null; // null = success
//     } on FirebaseAuthException catch (e) {
//       debugPrint('Firebase Auth error: ${e.code} - ${e.message}');
//       return '${e.code}: ${e.message ?? 'Registration failed'}';
//     } catch (e) {
//       debugPrint('Registration error: $e');
//       return 'Registration failed: $e';
//     }
//   }
//
//   Future<String?> login({
//     required String email,
//     required String password,
//   }) async {
//     try {
//       await _auth.signInWithEmailAndPassword(email: email, password: password);
//       return null;
//     } on FirebaseAuthException catch (e) {
//       return e.message ?? 'Login failed';
//     }
//   }
//
//   Future<void> logout() => _auth.signOut();
//
//   /// Token sent to FastAPI to verify the user on protected endpoints
//   // Future<String?> getIdToken() async {
//   //   final user = _auth.currentUser;
//   //   if (user == null) return null;
//   //   return await user.getIdToken(true);
//   // }
//   Future<String?> getIdToken() async {
//     final user = _auth.currentUser;
//     if (user == null) return null;
//
//     final token = await user.getIdToken(true);
//     print('FIREBASE ID TOKEN: $token');
//     return token;
//   }
//
// }

import 'package:firebase_auth/firebase_auth.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin wrapper around Firebase Auth. Screens never touch FirebaseAuth
/// directly, and errors are converted to readable messages.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<void> signIn(String email, String password) =>
      _run(() => _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password));

  Future<void> register(String email, String password) =>
      _run(() => _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password));

  Future<void> sendPasswordReset(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() => _auth.signOut();

  Future<void> _run(Future<dynamic> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw const AuthFailure('Something went wrong. Please try again.');
    }
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try signing in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
