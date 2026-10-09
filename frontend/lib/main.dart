import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GovernanceApp());
}

class GovernanceApp extends StatelessWidget {
  const GovernanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dependency Governance Platform',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}