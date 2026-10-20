import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/guest_upload_card.dart';

class LandingPageScreen extends StatelessWidget {
  const LandingPageScreen({
    super.key,
    required this.onSignInTap,
    required this.onRegisterTap,
  });

  final VoidCallback onSignInTap;
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _NavigationBar(
              onSignInTap: onSignInTap,
              onRegisterTap: onRegisterTap,
            ),
            _HeroSection(
              onSignInTap: onSignInTap,
              onRegisterTap: onRegisterTap,
            ),
            _GovernancePillarsSection(),
            _PlatformComparisonSection(),
            _BottomCallToAction(
              onSignInTap: onSignInTap,
              onRegisterTap: onRegisterTap,
            ),
            const _FooterSection(),
          ],
        ),
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.onSignInTap,
    required this.onRegisterTap,
  });

  final VoidCallback onSignInTap;
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border.withAlpha(120))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              // Brand
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'CheckMyDeps',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Actions
              TextButton(
                onPressed: onSignInTap,
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onRegisterTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onSignInTap,
    required this.onRegisterTap,
  });

  final VoidCallback onSignInTap;
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFF1F5F9),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              // Eyebrow Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.primary.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_graph_outlined, size: 14, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'AI-Powered Software Supply Chain Governance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Know the True Health of\nEvery Dependency You Ship',
                textAlign: TextAlign.center,
                style: text.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 42,
                  height: 1.15,
                  letterSpacing: -1,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  'CheckMyDeps delivers continuous dependency intelligence: ML-driven package maintenance forecasting, automated OSV vulnerability detection, and organizational license compliance.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Supported Ecosystem Chips
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const [
                  _EcosystemTag('Flutter & Dart (pub.dev)'),
                  _EcosystemTag('Python (PyPI)'),
                  _EcosystemTag('Node.js & React (npm)'),
                ],
              ),
              const SizedBox(height: 36),

              // Sandbox Upload Area
              GuestUploadCard(
                onSignInTap: onSignInTap,
                onRegisterTap: onRegisterTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EcosystemTag extends StatelessWidget {
  const _EcosystemTag(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.low),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernancePillarsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Comprehensive Governance Architecture',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'Unlike standard vulnerability checkers, CheckMyDeps evaluates risk across three independent dimensions to catch abandoned and non-compliant code before it reaches production.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, c) {
                  final isWide = c.maxWidth >= 760;
                  final cards = [
                    const _PillarCard(
                      icon: Icons.psychology_outlined,
                      accent: Color(0xFF6366F1),
                      title: 'ML-Based Maintenance Prediction',
                      body:
                          'A trained 16-feature classifier analyzes 8 temporal commit windows and inactive gaps directly from upstream GitHub repositories to predict abandoned packages.',
                    ),
                    const _PillarCard(
                      icon: Icons.security_outlined,
                      accent: Color(0xFFE11D48),
                      title: 'Live OSV.dev Advisory Detection',
                      body:
                          'Direct automated integration with Google OSV.dev checks each declared package version against global CVE and GHSA databases without outdated static caches.',
                    ),
                    const _PillarCard(
                      icon: Icons.gavel_outlined,
                      accent: Color(0xFF0D9488),
                      title: 'SPDX License Compliance Rules',
                      body:
                          'Automated classification separates permissible permissive licenses (MIT, Apache-2.0, BSD) from restricted (MPL, LGPL) and toxic copyleft (GPL, AGPL) licenses.',
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 20),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  }

                  return Column(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        cards[i],
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformComparisonSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'How CheckMyDeps Compares',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Beyond basic package lists or retrospective CVE scanners',
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Governance Capability', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Standard SCA Tools', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('CheckMyDeps Platform',
                              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    _tableRow(
                      'Predictive Upstream Maintenance',
                      'None (reactive only)',
                      '16-Feature ML Temporal Classifier',
                    ),
                    _tableRow(
                      'Live OSV.dev Correlation',
                      'Local database snapshots',
                      'Direct real-time API query',
                    ),
                    _tableRow(
                      'SPDX Policy Enforcement',
                      'Fixed pass/fail rules',
                      'Allowed, Restricted & Prohibited tiers',
                    ),
                    _tableRow(
                      'Governance Scoring Caps',
                      'Linear averages',
                      'Critical risk caps score at 40/100',
                    ),
                    _tableRow(
                      'Three Tier User Workflows',
                      'Single flat dashboard',
                      'Guest Sandbox, Individual, and Org Portals',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _tableRow(String feature, String standard, String checkMyDeps) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(feature, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(standard, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 16, color: AppColors.low),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  checkMyDeps,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomCallToAction extends StatelessWidget {
  const _BottomCallToAction({
    required this.onSignInTap,
    required this.onRegisterTap,
  });

  final VoidCallback onSignInTap;
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const Text(
                'Protect Your Supply Chain Today',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Create an individual account to save analyses and track project trends over time, or sign in to continue governance evaluation.',
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: onRegisterTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Create Free Account'),
                  ),
                  OutlinedButton(
                    onPressed: onSignInTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Sign In to Platform'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF070F1E),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 6,
            spacing: 16,
            children: const [
              Text(
                'CheckMyDeps — Dependency Governance Platform',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                'FastAPI · Flutter Web · OSV.dev · Scikit-Learn',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
