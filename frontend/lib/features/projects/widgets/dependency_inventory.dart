import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/governance_widgets.dart';
import '../../dependency_analysis/models/analysis_result.dart';
import '../../dependency_analysis/screens/dependencies_screen.dart'
    show DependencyRow;

/// The dependencies of ONE stored analysis, with search, risk filter and sort.
/// Rows reuse the personal workspace's DependencyRow. Only data the backend
/// saved is shown; missing metadata renders as unknown, never as a guess.
class DependencyInventory extends StatefulWidget {
  const DependencyInventory({
    super.key,
    required this.dependencies,
    required this.onOpen,
  });

  final List<DependencyResult> dependencies;
  final ValueChanged<DependencyResult> onOpen;

  @override
  State<DependencyInventory> createState() => _DependencyInventoryState();
}

class _DependencyInventoryState extends State<DependencyInventory> {
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
    final all = widget.dependencies;

    if (all.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Dependency inventory'),
          SizedBox(height: 12),
          AppCard(child: Text('This analysis contains no dependencies.')),
        ],
      );
    }

    final visible = _visible(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Dependency inventory',
          subtitle: '${all.length} package${all.length == 1 ? '' : 's'} · '
              'select one for vulnerability, licence and maintenance details',
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final searchWidth =
                  constraints.maxWidth < 280 ? constraints.maxWidth : 280.0;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: searchWidth,
                        child: TextField(
                          decoration: const InputDecoration(
                            isDense: true,
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search packages',
                          ),
                          onChanged: (value) => setState(
                                  () => _query = value.trim().toLowerCase()),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sort,
                          items: const [
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
                  );
                },
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
        const SizedBox(height: 12),
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
                    if (!compact) ...[
                      const _HeaderRow(),
                      const Divider(height: 1),
                    ],
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      DependencyRow(
                        dep: visible[i],
                        compact: compact,
                        onTap: () => widget.onOpen(visible[i]),
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

/// Column labels aligned with DependencyRow's wide layout.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.3,
    );
    Widget label(String text) => Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 36, child: label('#')),
          Expanded(flex: 4, child: label('Package')),
          SizedBox(width: 96, child: label('Risk')),
          SizedBox(width: 48, child: label('Score')),
          Expanded(flex: 2, child: label('Maintenance')),
          Expanded(flex: 2, child: label('Vulnerabilities')),
          Expanded(flex: 2, child: label('Licence')),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}