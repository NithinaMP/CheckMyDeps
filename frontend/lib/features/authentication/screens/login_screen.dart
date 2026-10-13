// // lib/features/authentication/screens/login_screen.dart
//
// import 'package:flutter/material.dart';
// import '../services/auth_service.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _authService = AuthService();
//   bool _isLoading = false;
//   String? _errorMessage;
//
//   Future<void> _submit() async {
//     if (!_formKey.currentState!.validate()) return;
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     final error = await _authService.login(
//       email: _emailController.text.trim(),
//       password: _passwordController.text.trim(),
//     );
//
//     setState(() => _isLoading = false);
//
//     if (error == null && mounted) {
//       Navigator.pushReplacementNamed(context, '/dashboard');
//     } else {
//       setState(() => _errorMessage = error);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 420),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Text('Sign in', style: Theme.of(context).textTheme.headlineSmall),
//                   const SizedBox(height: 24),
//                   TextFormField(
//                     controller: _emailController,
//                     decoration: const InputDecoration(labelText: 'Email'),
//                     validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
//                   ),
//                   const SizedBox(height: 12),
//                   TextFormField(
//                     controller: _passwordController,
//                     decoration: const InputDecoration(labelText: 'Password'),
//                     obscureText: true,
//                     validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                   ),
//                   if (_errorMessage != null) ...[
//                     const SizedBox(height: 12),
//                     Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
//                   ],
//                   const SizedBox(height: 20),
//                   FilledButton(
//                     onPressed: _isLoading ? null : _submit,
//                     child: _isLoading
//                         ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
//                         : const Text('Log in'),
//                   ),
//                   TextButton(
//                     onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
//                     child: const Text("Don't have an account? Register"),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
