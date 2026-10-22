import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/layout/auth_gate.dart';
import 'core/services/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/dependency_analysis/providers/analysis_provider.dart';
import 'features/dependency_analysis/services/analysis_service.dart';
import 'features/organization/providers/organization_provider.dart';
import 'features/organization/services/organisation_service.dart';
// import 'features/organization/services/organization_service.dart';
import 'features/projects/providers/project_provider.dart';
import 'features/projects/services/project_service.dart';
import 'firebase_options.dart';
import 'features/organization/providers/org_dashboard_provider.dart';
import 'features/organization/services/org_dashboard_service.dart';
import 'features/projects/providers/project_analysis_provider.dart';
import 'features/projects/services/project_analysis_service.dart';

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
        ChangeNotifierProvider(
          create: (_) => OrganizationProvider(OrganizationService(ApiClient())),
        ),
        ChangeNotifierProvider(
          create: (_) => ProjectProvider(ProjectService(ApiClient())),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ProjectAnalysisProvider(ProjectAnalysisService(ApiClient())),
        ),
        ChangeNotifierProvider(
          create: (_) => OrgDashboardProvider(OrgDashboardService(ApiClient())),
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