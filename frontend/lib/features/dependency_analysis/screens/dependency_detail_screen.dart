import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/status_badges.dart';
import '../models/analysis_result.dart';

/// Full-page details for one dependency. Opened from the dashboard and from
/// the Dependencies list.
class DependencyDetailScreen extends StatelessWidget {
  const DependencyDetailScreen({super.key, required this.dependency});

  final DependencyResult dependency;

  @override
  Widget build(BuildContext context) {
    final dep = dependency;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(dep.name),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(dep: dep),
                const SizedBox(height: 16),
                if (dep.isFailed)
                  _FailedCard(dep: dep)
                else ...[
                  _ScoreCard(dep: dep),
                  const SizedBox(height: 16),
                  _MaintenanceCard(dep: dep),
                  const SizedBox(height: 16),
                  _SecurityCard(dep: dep),
                  const SizedBox(height: 16),
                  _LicenseCard(dep: dep),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- header

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.dep});

  final DependencyResult dep;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final registry = dep.registry;
    final version = dep.versionChecked ?? dep.declaredVersion ?? '—';
    String sourceNote = '';
    if (dep.versionSource == 'registry_latest') {
      sourceNote = ' (latest from registry)';
    } else if (dep.versionSource == 'declared') {
      sourceNote = ' (declared in file)';
    }
    final description = registry?.description;
    final repoUri = safeWebUri(registry?.repositoryUrl);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dep.name,
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${dep.ecosystem} · version $version$sourceNote',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(description, style: text.bodyMedium),
                ],
                if (repoUri != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => openExternal(repoUri),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open repository'),
                  ),
                ],
              ],
            ),
          ),
          if (!dep.isFailed) ...[
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RiskBadge(dep.riskLevel),
                const SizedBox(height: 8),
                Text('${dep.score ?? '–'}',
                    style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.riskColor(dep.riskLevel))),
                Text('score / 100',
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.dep});

  final DependencyResult dep;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.critical),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This dependency could not be analyzed'
                  '${dep.error == null ? '.' : ': ${dep.error}'}\n'
                  'It is not included in the project score and is not assumed safe.',
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- score

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.dep});

  final DependencyResult dep;

  @override
  Widget build(BuildContext context) {
    final gov = dep.governance;
    if (gov == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Governance score breakdown'),
          for (final key in const ['security', 'maintenance', 'license'])
            if (gov.components[key] != null)
              _ComponentRow(label: _capitalize(key), score: gov.components[key]!),
          if (gov.capApplied) ...[
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.info_outline,
              color: AppColors.medium,
              text: 'The score is capped because the risk level is '
                  '${gov.riskLevel.toLowerCase()}.',
            ),
          ],
          if (gov.riskDrivers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Why this risk level',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _Bullets(items: gov.riskDrivers, color: AppColors.riskColor(gov.riskLevel)),
          ],
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.label, required this.score});

  final String label;
  final ComponentScore score;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final health = (score.health ?? 0.0).clamp(0.0, 1.0).toDouble();
    final weight = ((score.weight ?? 0.0) * 100).round();
    final points = (score.points ?? 0.0).toStringAsFixed(1);

    Color barColor;
    if (health >= 0.8) {
      barColor = AppColors.low;
    } else if (health >= 0.5) {
      barColor = AppColors.medium;
    } else if (health >= 0.2) {
      barColor = AppColors.high;
    } else {
      barColor = AppColors.critical;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('$label ($weight%)',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: health,
                minHeight: 10,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text('$points pts',
                textAlign: TextAlign.end,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- maintenance

class _Win {
  _Win(this.window, this.commits, this.maxGap);
  final int window;
  final int commits;
  final double maxGap;
}

List<_Win> _parseWindows(dynamic raw) {
  final out = <_Win>[];
  if (raw is List) {
    for (final w in raw) {
      if (w is Map) {
        final n = w['window'];
        final c = w['commits'];
        final g = w['max_days_without_commits'];
        out.add(_Win(
          n is num ? n.toInt() : out.length + 1,
          c is num ? c.toInt() : 0,
          g is num ? g.toDouble() : 0.0,
        ));
      }
    }
  }
  out.sort((a, b) => a.window.compareTo(b.window));
  return out;
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.dep});

  final DependencyResult dep;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = dep.maintenance;
    final windows = _parseWindows(m?.windows);
    final probability = m?.probabilityUnmaintained;
    final determined =
        dep.maintenanceStatus == 'Maintained' || dep.maintenanceStatus == 'Unmaintained';
    final reason = m?.reason;
    final pushedAt = m?.pushedAt;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Maintenance'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MaintenanceBadge(dep.maintenanceStatus),
              if (probability != null)
                Text(
                  'Estimated probability unmaintained: '
                      '${(probability * 100).toStringAsFixed(0)}%',
                  style: text.bodyMedium,
                ),
              if (m != null && m.archived == true)
                const StatusBadge('Archived on GitHub', AppColors.high),
            ],
          ),
          if (!determined) ...[
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.help_outline,
              color: AppColors.neutral,
              text: (reason != null && reason.isNotEmpty)
                  ? '$reason The status is not assumed to be maintained.'
                  : 'The maintenance status could not be determined and is '
                  'not assumed to be maintained.',
            ),
          ],
          if (pushedAt != null && pushedAt.length >= 10) ...[
            const SizedBox(height: 12),
            Text('Last push to the repository: ${pushedAt.substring(0, 10)}',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
          if (windows.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Commit activity (eight consecutive windows, oldest to newest)',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _WindowBars(windows: windows),
          ],
          const SizedBox(height: 12),
          Text(
            'An indicative estimate from a machine-learning model that looks at '
                'recent commit activity. It is not a guarantee.',
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WindowBars extends StatelessWidget {
  const _WindowBars({required this.windows});

  final List<_Win> windows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    var maxCommits = 0;
    for (final w in windows) {
      if (w.commits > maxCommits) maxCommits = w.commits;
    }

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final w in windows)
            Expanded(
              child: Tooltip(
                message: 'Window ${w.window}: ${w.commits} commits, '
                    'longest gap ${w.maxGap.toStringAsFixed(0)} days',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${w.commits}',
                          style: text.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Container(
                        height: maxCommits == 0
                            ? 3.0
                            : (w.commits / maxCommits) * 100.0 + 3.0,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('W${w.window}',
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- security

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.dep});

  final DependencyResult dep;

  String _scopeNote(VulnerabilityInfo v) {
    if (v.scope == 'all_versions') {
      return 'No version was pinned, so this counts every known vulnerability '
          'for the package.';
    }
    final q = v.queriedVersion;
    return q == null ? 'Checked against the declared version.' : 'Checked version $q.';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = dep.vulnerabilities;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Security (OSV.dev)'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              VulnerabilityBadge(v),
              if (v != null && v.isVerified)
                Text(_scopeNote(v),
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (v == null || !v.isVerified)
            const _InfoLine(
              icon: Icons.help_outline,
              color: AppColors.neutral,
              text: 'The vulnerability lookup was unavailable. This package is '
                  'not assumed to be safe.',
            )
          else if (v.items.isEmpty)
            Text('No known vulnerabilities for this version.',
                style: text.bodyMedium)
          else
            ...v.items.map((item) => _VulnTile(item: item)),
          if (v != null && v.truncated) ...[
            const SizedBox(height: 8),
            Text('Only the first results are shown.',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _VulnTile extends StatelessWidget {
  const _VulnTile({required this.item});

  final VulnerabilityItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final severity = item.severity ?? 'UNKNOWN';
    Uri? link;
    for (final ref in item.references) {
      final uri = safeWebUri(ref);
      if (uri != null) {
        link = uri;
        break;
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(severity, severityColor(severity)),
              Text(item.id,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          if (item.summary != null && item.summary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.summary!, style: text.bodyMedium),
          ],
          if (link != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => openExternal(link!),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View advisory'),
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- license

class _LicenseCard extends StatelessWidget {
  const _LicenseCard({required this.dep});

  final DependencyResult dep;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rules = dep.rules;
    final licenseName = rules?.detectedLicense ?? dep.registry?.license;
    final reason = rules?.license.reason;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('License and policy'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(licenseName ?? 'Unknown license',
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
              LicenseBadge(dep.licenseStatus),
              if (rules != null) PolicyBadge(rules.policy.status),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(reason,
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
          if (rules != null && rules.policy.violations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Policy violations',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _Bullets(items: rules.policy.violations, color: AppColors.critical),
          ],
          if (rules != null && rules.policy.reviewItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Needs review',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _Bullets(items: rules.policy.reviewItems, color: AppColors.medium),
          ],
          if (rules != null &&
              rules.policy.violations.isEmpty &&
              rules.policy.reviewItems.isEmpty) ...[
            const SizedBox(height: 12),
            Text('No policy issues for this dependency.', style: text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ small bits

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items, required this.color});

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
