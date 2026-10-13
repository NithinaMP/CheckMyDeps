import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/authentication/screens/auth_screen.dart';
import 'app_shell.dart';

/// Shows the login screen or the app, depending on Firebase's auth state.
/// Sign-in, sign-out and expired sessions all switch screens automatically.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data == null
            ? const AuthScreen()
            : AppShell(
          onSignedOut: () {
            // Handle sign-out here if needed.
          },
        );      },
    );
  }
}
