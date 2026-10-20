import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../dependency_analysis/providers/analysis_provider.dart';

/// Analyses run during this session. Opening one shows it on the dashboard.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.onOpened,
    required this.onUploadTap,
  });

  /// Called after a past analysis is reopened (the shell switches to Dashboard).
  final VoidCallback onOpened;
  final VoidCallback onUploadTap;

  String _when(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final provider = context.watch<AnalysisProvider>();
    final items = provider.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'History',
          subtitle: 'Analyses you ran in this session',
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          AppCard(
            child: Column(
              children: [
                const Icon(Icons.history, size: 40, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text('No analyses yet.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onUploadTap,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload dependency file'),
                ),
              ],
            ),
          )
        else ...[
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].result.filename,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            '${_when(items[i].at)} · '
                                '${items[i].result.summary.totalDependencies} dependencies',
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Score ${items[i].result.summary.complianceScore ?? '–'}',
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        RiskBadge(items[i].result.summary.highestRisk),
                      ],
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        context.read<AnalysisProvider>().openFromHistory(i);
                        onOpened();
                      },
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'History is kept for this session only. Saved history arrives with '
                'cloud storage.',
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
