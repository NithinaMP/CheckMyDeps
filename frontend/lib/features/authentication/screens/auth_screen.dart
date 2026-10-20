import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';

/// Combined sign-in / create-account screen.
/// Navigation after success is automatic: AuthGate listens to Firebase.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialIsRegister = false,
    this.onBackToLanding,
  });

  final bool initialIsRegister;
  final VoidCallback? onBackToLanding;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late bool _isRegister;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialIsRegister;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toggleMode() => setState(() {
        _isRegister = !_isRegister;
        _error = null;
        _info = null;
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_isRegister) {
        await _auth.register(_email.text, _password.text);
      } else {
        await _auth.signIn(_email.text, _password.text);
      }
      // Success: AuthGate swaps this screen for the app automatically.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      setState(() {
        _error = 'Enter your email above first, then tap "Forgot password?".';
        _info = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await _auth.sendPasswordReset(email);
      if (mounted) setState(() => _info = 'Password reset email sent to $email.');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        return Row(
          children: [
            if (wide) const Expanded(flex: 5, child: _BrandPanel()),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildForm(context, showLogo: !wide),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildForm(BuildContext context, {required bool showLogo}) {
    final text = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBackToLanding != null) ...[
            TextButton.icon(
              onPressed: widget.onBackToLanding,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to CheckMyDeps'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (showLogo) ...[
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text('CheckMyDeps',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 32),
          ],
          Text(_isRegister ? 'Create your account' : 'Welcome back',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _isRegister
                ? 'Register to analyze your project dependencies.'
                : 'Sign in to continue to your governance dashboard.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) =>
                _validEmail(v ?? '') ? null : 'Enter a valid email address',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
            validator: (v) => (v == null || v.length < 6)
                ? 'Password must be at least 6 characters'
                : null,
            onFieldSubmitted: (_) => _isRegister ? null : _submit(),
          ),
          if (_isRegister) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
          if (!_isRegister)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            )
          else
            const SizedBox(height: 8),
          if (_error != null) _Banner(_error!, AppColors.critical, Icons.error_outline),
          if (_info != null) _Banner(_info!, AppColors.low, Icons.check_circle_outline),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(_isRegister ? 'Create account' : 'Sign in'),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _toggleMode,
              child: Text(_isRegister
                  ? 'Already have an account? Sign in'
                  : "Don't have an account? Register"),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message, this.color, this.icon);
  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF16346B)],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.shield_outlined, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Text('CheckMyDeps',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 40),
          const Text('Know the health of every\ndependency you ship.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const Text(
            'AI-assisted governance for open-source dependencies.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 40),
          point(Icons.gavel_outlined, 'License compliance',
              'Check every package against your policy.'),
          point(Icons.security_outlined, 'Vulnerability detection',
              'Known issues from OSV.dev, per version.'),
          point(Icons.update_outlined, 'Maintenance prediction',
              'ML-based signal on whether a project is still maintained.'),
        ],
      ),
    );
  }
}
