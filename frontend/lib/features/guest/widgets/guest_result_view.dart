import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/status_badges.dart';
import '../../dashboard/widgets/score_gauge.dart';
import '../../dependency_analysis/models/analysis_result.dart';

class GuestResultView extends StatelessWidget {
  const GuestResultView({
    super.key,
    required this.result,
    required this.onSignInTap,
    required this.onRegisterTap,
    required this.onResetTap,
  });

  final AnalysisResult result;
  final VoidCallback onSignInTap;
  final VoidCallback onRegisterTap;
  final VoidCallback onResetTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final summary = result.summary;
    final dependencies = result.dependencies;
    final totalInFile = result.totalInFile ?? summary.totalDependencies;
    final analyzedCount = dependencies.where((d) => !d.isFailed).length;
    final lockedCount = result.lockedDependenciesCount ??
        (totalInFile > dependencies.length ? totalInFile - dependencies.length : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top summary row: File name & Reset button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withAlpha(80)),
                        ),
                        child: const Text(
                          'GUEST PREVIEW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        result.filename,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time dependency governance analysis powered by OSV.dev and ML maintenance prediction.',
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onResetTap,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Another File'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Prominent Score & Metrics banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ).boxShadow!.first,
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final gaugeWidget = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Governance Score',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ScoreGauge(score: summary.complianceScore),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Highest Risk: ',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      RiskBadge(summary.highestRisk),
                    ],
                  ),
                ],
              );

              final kpiGrid = Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Analyzed in Sandbox',
                    value: '$analyzedCount of $totalInFile',
                    caption: lockedCount > 0 ? '$lockedCount locked behind sign-in' : 'All analyzed',
                    icon: Icons.inventory_2_outlined,
                    accent: AppColors.primary,
                  ),
                  _MetricTile(
                    label: 'Known Vulnerabilities',
                    value: '${summary.vulnerable}',
                    caption: summary.vulnerable == 0 ? 'No CVEs detected' : 'OSV.dev advisory matches',
                    icon: Icons.security_outlined,
                    accent: summary.vulnerable == 0 ? AppColors.low : AppColors.high,
                  ),
                  _MetricTile(
                    label: 'ML Maintenance Risk',
                    value: '${summary.unmaintained}',
                    caption: '${summary.maintained} maintained repository',
                    icon: Icons.update_disabled_outlined,
                    accent: summary.unmaintained == 0 ? AppColors.low : AppColors.high,
                  ),
                  _MetricTile(
                    label: 'License Policy State',
                    value: summary.licenseViolations > 0
                        ? '${summary.licenseViolations} Violations'
                        : 'Compliant',
                    caption: 'Checked against standard policy',
                    icon: Icons.gavel_outlined,
                    accent: summary.licenseViolations == 0 ? AppColors.low : AppColors.critical,
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  children: [
                    SizedBox(width: 220, child: gaugeWidget),
                    Container(
                      height: 140,
                      width: 1,
                      color: AppColors.border,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    Expanded(child: kpiGrid),
                  ],
                );
              }

              return Column(
                children: [
                  gaugeWidget,
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),
                  kpiGrid,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Lock / Sign In Callout Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F172A),
                AppColors.navy.withAlpha(240),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withAlpha(90)),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_clock_outlined, color: Color(0xFF67E8F9), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        lockedCount > 0
                            ? '$lockedCount additional dependencies in this file are locked'
                            : 'Sign in to access deep-dive reports & history',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Free individual accounts unlock full project scans, deep commit activity curves, individual CVE links, persistent history, and custom organizational policy enforcement.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              );

              final buttons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: onRegisterTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text('Create Free Account'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: onSignInTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text('Sign In'),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 24),
                    buttons,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: 16),
                  buttons,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // List of analyzed dependencies
        Text(
          'Sample of Analyzed Packages (${dependencies.length})',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < dependencies.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                _GuestDependencyRow(dep: dependencies[i], rank: i + 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _GuestDependencyRow extends StatelessWidget {
  const _GuestDependencyRow({required this.dep, required this.rank});

  final DependencyResult dep;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final version = dep.versionChecked ?? dep.declaredVersion ?? 'latest';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dep.name,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${dep.ecosystem} · $version',
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RiskBadge(dep.riskLevel),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '${dep.score ?? '—'}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          MaintenanceBadge(dep.maintenanceStatus),
          const SizedBox(width: 10),
          VulnerabilityBadge(dep.vulnerabilities),
          const SizedBox(width: 10),
          LicenseBadge(dep.licenseStatus),
        ],
      ),
    );
  }
}
