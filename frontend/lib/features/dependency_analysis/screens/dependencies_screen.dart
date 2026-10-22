import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/status_badges.dart';
import '../models/analysis_result.dart';
import '../providers/analysis_provider.dart';

/// Every dependency of the latest analysis, with search, filter and sort.
class DependenciesScreen extends StatefulWidget {
  const DependenciesScreen({
    super.key,
    required this.onOpenDependency,
    required this.onUploadTap,
  });

  final ValueChanged<DependencyResult> onOpenDependency;
  final VoidCallback onUploadTap;

  @override
  State<DependenciesScreen> createState() => _DependenciesScreenState();
}

class _DependenciesScreenState extends State<DependenciesScreen> {
  static const List<String> _filters = [
    'ALL',
    'CRITICAL',
    'HIGH',
    'MEDIUM',
    'LOW',
    'FAILED',
  ];

  String _filter = 'ALL';
  String _query = '';
  String _sort = 'risk';

  int _count(List<DependencyResult> all, String filter) {
    if (filter == 'ALL') return all.length;
    if (filter == 'FAILED') return all.where((d) => d.isFailed).length;
    return all
        .where((d) => !d.isFailed && d.riskLevel?.toUpperCase() == filter)
        .length;
  }

  String _filterLabel(String filter) =>
      '${filter[0]}${filter.substring(1).toLowerCase()}';

  List<DependencyResult> _visible(List<DependencyResult> all) {
    final list = all.where((d) {
      if (_query.isNotEmpty && !d.name.toLowerCase().contains(_query)) {
        return false;
      }
      if (_filter == 'ALL') return true;
      if (_filter == 'FAILED') return d.isFailed;
      return !d.isFailed && d.riskLevel?.toUpperCase() == _filter;
    }).toList();

    if (_sort == 'name') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sort == 'score') {
      list.sort((a, b) => (a.score ?? 1000).compareTo(b.score ?? 1000));
    }
    // 'risk' keeps the backend's own ranking (most risky first).
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;

    if (result == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Dependencies',
            subtitle: 'Every package in your project, ranked by risk',
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 40, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text('No analysis yet. Upload a dependency file first.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.onUploadTap,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload dependency file'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final all = result.dependencies;
    final visible = _visible(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Dependencies',
          subtitle: '${all.length} packages from ${result.filename}',
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search packages',
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sort,
                      items: [
                        DropdownMenuItem<String>(
                            value: 'risk', child: Text('Sort: highest risk')),
                        DropdownMenuItem<String>(
                            value: 'score', child: Text('Sort: lowest score')),
                        DropdownMenuItem<String>(
                            value: 'name', child: Text('Sort: name')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _filters)
                    ChoiceChip(
                      label: Text('${_filterLabel(f)} (${_count(all, f)})'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          const AppCard(child: Text('No packages match your filters.'))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      DependencyRow(
                        dep: visible[i],
                        compact: compact,
                        onTap: () => widget.onOpenDependency(visible[i]),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class DependencyRow extends StatelessWidget {
  const DependencyRow({
    super.key,
    required this.dep,
    required this.compact,
    required this.onTap,
  });

  final DependencyResult dep;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final version = dep.versionChecked ?? dep.declaredVersion;
    final subtitle = version == null ? dep.ecosystem : '${dep.ecosystem} · $version';

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dep.name,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );

    if (compact) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: nameBlock),
                  const SizedBox(width: 8),
                  if (dep.isFailed)
                    const StatusBadge('Failed', AppColors.neutral)
                  else
                    RiskBadge(dep.riskLevel),
                ],
              ),
              if (!dep.isFailed) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    MaintenanceBadge(dep.maintenanceStatus),
                    VulnerabilityBadge(dep.vulnerabilities),
                    LicenseBadge(dep.licenseStatus),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(dep.riskRank == null ? '–' : '#${dep.riskRank}',
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(flex: 4, child: nameBlock),
            if (dep.isFailed)
              const Expanded(
                flex: 9,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge('Analysis failed', AppColors.neutral),
                ),
              )
            else ...[
              SizedBox(width: 96, child: Align(alignment: Alignment.centerLeft, child: RiskBadge(dep.riskLevel))),
              SizedBox(
                width: 48,
                child: Text('${dep.score ?? '–'}',
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: 2,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: MaintenanceBadge(dep.maintenanceStatus)),
              ),
              Expanded(
                flex: 2,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: VulnerabilityBadge(dep.vulnerabilities)),
              ),
              Expanded(
                flex: 2,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: LicenseBadge(dep.licenseStatus)),
              ),
            ],
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
