import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/authentication/screens/auth_screen.dart';
import '../../features/guest/screens/landing_page_screen.dart';
import 'app_shell.dart';

/// Routes between the public Landing Page (guest experience), the Auth screen,
/// and the AppShell workspace based on Firebase auth state and user navigation.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showAuthScreen = false;
  bool _initialRegisterMode = false;

  void _openAuth({required bool isRegister}) {
    setState(() {
      _showAuthScreen = true;
      _initialRegisterMode = isRegister;
    });
  }

  void _closeAuth() {
    setState(() {
      _showAuthScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          if (_showAuthScreen) {
            return AuthScreen(
              initialIsRegister: _initialRegisterMode,
              onBackToLanding: _closeAuth,
            );
          }
          return LandingPageScreen(
            onSignInTap: () => _openAuth(isRegister: false),
            onRegisterTap: () => _openAuth(isRegister: true),
          );
        }

        return AppShell(
          onSignedOut: () {
            setState(() {
              _showAuthScreen = false;
            });
          },
        );
      },
    );
  }
}
