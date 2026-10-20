import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/layout/auth_gate.dart';
import 'core/services/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/dependency_analysis/providers/analysis_provider.dart';
import 'features/dependency_analysis/services/analysis_service.dart';
import 'firebase_options.dart';

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AnalysisProvider(AnalysisService(ApiClient())),
        ),
      ],
      child: MaterialApp(
        title: 'CheckMyDeps',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AuthGate(),
      ),
    );
  }
}