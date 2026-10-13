//
// // ─────────────────────────────────────────────────────────────
//
// // lib/core/routes/app_router.dart — completed
//
// import 'package:flutter/material.dart';
// import '../../features/authentication/screens/dashboard_placeholder.dart';
// import '../../features/authentication/screens/login_screen.dart';
// import '../../features/authentication/screens/register_screen.dart';
// import '../../features/dependency_analysis/screens/upload_screen.dart';
//
// class AppRouter {
//   static Route<dynamic> generateRoute(RouteSettings settings) {
//     switch (settings.name) {
//       case '/login':
//         return MaterialPageRoute(builder: (_) => const LoginScreen());
//       case '/register':
//         return MaterialPageRoute(builder: (_) => const RegisterScreen());
//       case '/dashboard':
//         return MaterialPageRoute(builder: (_) => const DashboardPlaceholder());
//       case '/upload':
//         // return MaterialPageRoute(builder: (_) => const UploadScreen());
//       default:
//         return MaterialPageRoute(
//           builder: (_) => const Scaffold(body: Center(child: Text('Route not found'))),
//         );
//     }
//   }
// }