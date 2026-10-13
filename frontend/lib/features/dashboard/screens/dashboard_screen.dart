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
        PageHeader(
          title: 'Governance Dashboard',
          subtitle: result == null
              ? 'Monitor dependency health, compliance and maintenance risk.'
              : 'Latest analysis: ${result.filename}',
          action: FilledButton.icon(
            onPressed: onUploadTap,
            icon: const Icon(Icons.upload_file, size: 20),
            label: Text(result == null ? 'Upload file' : 'New analysis'),
          ),
        ),
        const SizedBox(height: 24),
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

// --------------------------------------------------------------- empty state

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUploadTap});

  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insights_outlined,
                size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text('No analysis yet',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Upload a pubspec.yaml, requirements.txt or package.json to see '
              'your compliance score, risk distribution and maintenance '
              'predictions.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onUploadTap,
            icon: const Icon(Icons.upload_file, size: 20),
            label: const Text('Upload dependency file'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- content

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

// --------------------------------------------------- score + stat cards grid

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

    final scoreCard = AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Compliance score',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ScoreGauge(score: s.complianceScore),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Highest risk  ',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              RiskBadge(s.highestRisk),
            ],
          ),
        ],
      ),
    );

    final cards = <Widget>[
      StatCard(
        label: 'Dependencies',
        value: '${s.totalDependencies}',
        caption: '${s.analyzed} analyzed',
        icon: Icons.inventory_2_outlined,
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
            ? '${s.vulnerable} packages affected · $unverified unverified'
            : '${s.vulnerable} packages affected',
        icon: Icons.security_outlined,
        accent: totalVulns == 0 ? AppColors.low : AppColors.high,
      ),
      StatCard(
        label: 'License violations',
        value: '${s.licenseViolations}',
        caption: 'Prohibited by policy',
        icon: Icons.gavel_outlined,
        accent: s.licenseViolations == 0 ? AppColors.low : AppColors.critical,
      ),
      StatCard(
        label: 'Needs review',
        value: '${s.needsReview}',
        caption: 'Unknown or restricted',
        icon: Icons.rule_outlined,
        accent: s.needsReview == 0 ? AppColors.low : AppColors.medium,
      ),
      StatCard(
        label: 'Unmaintained',
        value: '${s.unmaintained}',
        caption: '${s.maintained} maintained',
        icon: Icons.update_disabled_outlined,
        accent: s.unmaintained == 0 ? AppColors.low : AppColors.high,
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

// --------------------------------------------------------- risk distribution

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
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 18),
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
                    padding: const EdgeInsets.only(bottom: 14),
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
        SizedBox(width: 92, child: Align(alignment: Alignment.centerLeft, child: label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 12, color: AppColors.background),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(height: 12, color: color),
              ),
            ]),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text('$count  (${(fraction * 100).round()}%)',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- maintenance

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 18,
                    child: Row(children: [
                      for (final i in items)
                        if (i.$2 > 0)
                          Expanded(
                              flex: i.$2, child: Container(color: i.$3)),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(color: i.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(i.$1)),
                      Text('${i.$2}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                const Text(
                  'Predicted from recent GitHub commit activity.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }
}

// ------------------------------------------------------------ priority + fail

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
      trailing: TextButton(onPressed: onViewAll, child: const Text('View all')),
      child: dependencies.isEmpty
          ? const Text('No analyzed dependencies.',
              style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: [
                for (var i = 0; i < dependencies.length; i++) ...[
                  if (i > 0) const Divider(),
                  _PriorityRow(dep: dependencies[i], onTap: () => onOpen(dependencies[i])),
                ],
              ],
            ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.dep, required this.onTap});

  final DependencyResult dep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final drivers = dep.governance?.riskDrivers ?? const [];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          SizedBox(
            width: 32,
            child: Text('#${dep.riskRank ?? '-'}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dep.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  drivers.isEmpty ? 'No risk drivers reported' : drivers.first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RiskBadge(dep.riskLevel),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text('${dep.score ?? '-'}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
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
