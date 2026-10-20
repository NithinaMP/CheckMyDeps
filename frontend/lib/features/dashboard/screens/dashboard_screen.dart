import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';

import '../../dependency_analysis/models/analysis_result.dart';
import '../../dependency_analysis/providers/analysis_provider.dart';

import '../widgets/score_gauge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onUploadTap,
    required this.onOpenDependency,
    required this.onViewAll,
  });

  final VoidCallback onUploadTap;
  final ValueChanged<DependencyResult> onOpenDependency;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardHeader(result: result, onUploadTap: onUploadTap),
        const SizedBox(height: 28),
        if (result == null)
          _EmptyState(onUploadTap: onUploadTap)
        else
          _Content(
            result: result,
            onOpenDependency: onOpenDependency,
            onViewAll: onViewAll,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────── header ───────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.result, required this.onUploadTap});

  final AnalysisResult? result;
  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasResult = result != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Governance Dashboard',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasResult
                    ? 'Last analysis: ${result!.filename}'
                    : 'Monitor dependency health, compliance and risk.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: onUploadTap,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: Text(hasResult ? 'New analysis' : 'Upload file'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────── empty state ─────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUploadTap});

  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        // Hero card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withAlpha(50)),
          ),
          child: Column(
            children: [
              // Icon badge
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withAlpha(60),
                      const Color(0xFF7C3AED).withAlpha(40),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withAlpha(80),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No analysis yet',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  'Upload a pubspec.yaml, requirements.txt, or package.json to '
                  'see your compliance score, risk distribution, and ML-based '
                  'maintenance predictions.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: Colors.white60,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onUploadTap,
                icon: const Icon(Icons.upload_file_rounded, size: 20),
                label: const Text('Upload dependency file'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Feature pills
        _FeaturePillsRow(),
      ],
    );
  }
}

class _FeaturePillsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const pills = [
      (Icons.gavel_rounded, 'License compliance', AppColors.primary),
      (Icons.security_rounded, 'Vulnerability detection', AppColors.high),
      (Icons.psychology_rounded, 'ML maintenance prediction', Color(0xFF7C3AED)),
      (Icons.policy_rounded, 'Policy enforcement', AppColors.medium),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final (icon, label, color) in pills)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────── content ───────────────────────────

class _Content extends StatelessWidget {
  const _Content({
    required this.result,
    required this.onOpenDependency,
    required this.onViewAll,
  });

  final AnalysisResult result;
  final ValueChanged<DependencyResult> onOpenDependency;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final s = result.summary;
    final analyzed = result.dependencies.where((d) => !d.isFailed).toList();
    final failed = result.dependencies.where((d) => d.isFailed).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.failed > 0) ...[
          _Notice(
            icon: Icons.warning_amber_rounded,
            color: AppColors.medium,
            text: '${s.failed} of ${s.totalDependencies} dependencies could '
                'not be analyzed. The score below covers only the '
                '${s.analyzed} that were.',
          ),
          const SizedBox(height: 16),
        ],
        if (result.skipped > 0) ...[
          _Notice(
            icon: Icons.info_outline,
            color: AppColors.primary,
            text: '${result.skipped} dependencies were skipped because the '
                'file has more than the analysis limit.',
          ),
          const SizedBox(height: 16),
        ],
        _TopSection(summary: s, analyzed: analyzed),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final risk = _RiskDistributionCard(summary: s);
          final maint = _MaintenanceCard(summary: s);
          if (c.maxWidth >= 860) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: risk),
                  const SizedBox(width: 16),
                  Expanded(child: maint),
                ],
              ),
            );
          }
          return Column(children: [risk, const SizedBox(height: 16), maint]);
        }),
        const SizedBox(height: 16),
        _PriorityCard(
          dependencies: analyzed.take(5).toList(),
          onOpen: onOpenDependency,
          onViewAll: onViewAll,
        ),
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 16),
          _FailedCard(failed: failed),
        ],
        if (result.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final note in result.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(note,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ]),
    );
  }
}

// ─────────────────────────── score + stat grid ────────────────────────────

class _TopSection extends StatelessWidget {
  const _TopSection({required this.summary, required this.analyzed});

  final AnalysisSummary summary;
  final List<DependencyResult> analyzed;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final totalVulns =
        analyzed.fold<int>(0, (sum, d) => sum + (d.vulnerabilityCount ?? 0));
    final unverified =
        analyzed.where((d) => !(d.vulnerabilities?.isVerified ?? false)).length;

    final scoreCard = _ScoreCard(summary: s);

    final cards = <Widget>[
      StatCard(
        label: 'Dependencies',
        value: '${s.totalDependencies}',
        caption: '${s.analyzed} analyzed',
        icon: Icons.inventory_2_rounded,
      ),
      StatCard(
        label: 'Failed analyses',
        value: '${s.failed}',
        caption: s.failed == 0 ? 'All completed' : 'Listed below',
        icon: Icons.error_outline,
        accent: s.failed == 0 ? AppColors.low : AppColors.critical,
        valueColor: s.failed == 0 ? null : AppColors.critical,
      ),
      StatCard(
        label: 'Known vulnerabilities',
        value: '$totalVulns',
        caption: unverified > 0
            ? '${s.vulnerable} pkgs · $unverified unverified'
            : '${s.vulnerable} packages affected',
        icon: Icons.security_rounded,
        accent: totalVulns == 0 ? AppColors.low : AppColors.high,
        valueColor: totalVulns == 0 ? null : AppColors.high,
      ),
      StatCard(
        label: 'License violations',
        value: '${s.licenseViolations}',
        caption: 'Prohibited by policy',
        icon: Icons.gavel_rounded,
        accent: s.licenseViolations == 0 ? AppColors.low : AppColors.critical,
        valueColor: s.licenseViolations == 0 ? null : AppColors.critical,
      ),
      StatCard(
        label: 'Needs review',
        value: '${s.needsReview}',
        caption: 'Unknown or restricted',
        icon: Icons.rule_rounded,
        accent: s.needsReview == 0 ? AppColors.low : AppColors.medium,
      ),
      StatCard(
        label: 'Unmaintained',
        value: '${s.unmaintained}',
        caption: '${s.maintained} maintained',
        icon: Icons.update_disabled_rounded,
        accent: s.unmaintained == 0 ? AppColors.low : AppColors.high,
        valueColor: s.unmaintained == 0 ? null : AppColors.high,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      const gap = 16.0;
      Widget grid(double maxWidth) {
        final cols = maxWidth >= 640 ? 3 : (maxWidth >= 380 ? 2 : 1);
        final w = (maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      }

      if (c.maxWidth >= 1000) {
        const scoreWidth = 280.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: scoreWidth, child: scoreCard),
            const SizedBox(width: gap),
            Expanded(
              child: LayoutBuilder(
                  builder: (context, cc) => grid(cc.maxWidth)),
            ),
          ],
        );
      }
      return Column(
        children: [scoreCard, const SizedBox(height: gap), grid(c.maxWidth)],
      );
    });
  }
}

/// Score card with gradient accent border
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.summary});
  final AnalysisSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Compliance score',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          ScoreGauge(score: s.complianceScore),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Highest risk  ',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              RiskBadge(s.highestRisk),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── risk distribution ────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _RiskDistributionCard extends StatelessWidget {
  const _RiskDistributionCard({required this.summary});

  final AnalysisSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.analyzed;
    return _SectionCard(
      title: 'Risk distribution',
      child: total == 0
          ? const Text('No analyzed dependencies to show.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: [
                for (final level in riskLevels)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _BarRow(
                      label: RiskBadge(level),
                      count: summary.riskDistribution[level] ?? 0,
                      total: total,
                      color: AppColors.riskColor(level),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final Widget label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(width: 96, child: Align(alignment: Alignment.centerLeft, child: label)),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(children: [
                Container(height: 10, color: AppColors.surfaceSubtle),
                FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            '$count  (${(fraction * 100).round()}%)',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── maintenance ─────────────────────────────────────

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.summary});

  final AnalysisSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Maintained', summary.maintained, AppColors.low),
      ('Unmaintained', summary.unmaintained, AppColors.high),
      ('Undetermined', summary.maintenanceUndetermined, AppColors.neutral),
    ];
    final total = items.fold<int>(0, (a, e) => a + e.$2);

    return _SectionCard(
      title: 'Maintenance status',
      child: total == 0
          ? const Text('No maintenance predictions available.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stacked bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 16,
                    child: Row(children: [
                      for (final i in items)
                        if (i.$2 > 0)
                          Expanded(
                            flex: i.$2,
                            child: Container(color: i.$3),
                          ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: i.$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          i.$1,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${i.$2}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        total > 0 ? '(${(i.$2 / total * 100).round()}%)' : '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ]),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withAlpha(12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withAlpha(40),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.psychology_rounded,
                          size: 14, color: Color(0xFF7C3AED)),
                      SizedBox(width: 6),
                      Text(
                        'ML prediction from GitHub commit activity',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ──────────────────────── priority + failed ───────────────────────────────

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.dependencies,
    required this.onOpen,
    required this.onViewAll,
  });

  final List<DependencyResult> dependencies;
  final ValueChanged<DependencyResult> onOpen;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Highest-priority dependencies',
      trailing: TextButton.icon(
        onPressed: onViewAll,
        icon: const Icon(Icons.open_in_new, size: 14),
        label: const Text('View all'),
      ),
      child: dependencies.isEmpty
          ? const Text('No analyzed dependencies.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: [
                for (var i = 0; i < dependencies.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.border),
                  _PriorityRow(
                    dep: dependencies[i],
                    onTap: () => onOpen(dependencies[i]),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PriorityRow extends StatefulWidget {
  const _PriorityRow({required this.dep, required this.onTap});

  final DependencyResult dep;
  final VoidCallback onTap;

  @override
  State<_PriorityRow> createState() => _PriorityRowState();
}

class _PriorityRowState extends State<_PriorityRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dep = widget.dep;
    final drivers = dep.governance?.riskDrivers ?? const [];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            // Rank badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '#${dep.riskRank ?? '-'}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dep.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    drivers.isEmpty ? 'No risk drivers reported' : drivers.first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            RiskBadge(dep.riskLevel),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(
                '${dep.score ?? '—'}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.failed});

  final List<DependencyResult> failed;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Failed analyses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in failed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.critical),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(d.error ?? 'Analysis failed.',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
