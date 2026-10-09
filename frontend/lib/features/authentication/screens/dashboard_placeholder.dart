
// ─────────────────────────────────────────────────────────────

// lib/features/dashboard/screens/dashboard_placeholder.dart
// Temporary — replaced with the real dashboard in Phase 12.
// Exists now only so navigation after login/register resolves to something.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../authentication/services/auth_service.dart';

class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard (placeholder)')),
      body: Center(
        child:
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Logged in as: ${user?.email ?? "unknown"}'),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () async {

                await AuthService().logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: const Text('Log out'),

            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () async {
                // Should succeed — reading your own user document
                final myDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .get();

                print('My doc: ${myDoc.data()}');

                // Should fail — reading another user's document
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc('some-fake-uid')
                      .get();

                  print('WARNING: This read was not blocked!');
                } catch (e) {
                  print('Correctly blocked: $e');
                }
              },
              child: const Text('Test Firestore Rules'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/upload'),
              child: const Text('Upload dependency file'),
            ),

            ElevatedButton(
              onPressed: () async {
                final token =
                await FirebaseAuth.instance.currentUser!.getIdToken();

                print('ID TOKEN: $token');
              },
              child: const Text('Get ID Token'),
            ),
          ],
        )      ),
    );
  }
}
