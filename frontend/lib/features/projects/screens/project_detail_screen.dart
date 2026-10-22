import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/governance_widgets.dart';
import '../../../core/widgets/status_badges.dart';
import '../../dependency_analysis/models/analysis_result.dart';
import '../../dependency_analysis/screens/dependency_detail_screen.dart';
import '../models/project.dart';
import '../models/project_analysis.dart';
import '../providers/project_analysis_provider.dart';
import '../widgets/dependency_inventory.dart';

/// One project: result of the selected saved analysis, dependency inventory,
/// upload & analyse, and analysis history.
/// Backend permissions apply to every call (any organisation member may analyse).
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<ProjectAnalysisProvider>()
          .open(widget.project.orgId, widget.project.id);
    });
  }

  Future<void> _pick() async {
    final provider = context.read<ProjectAnalysisProvider>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['yaml', 'txt', 'json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      provider.rejectFile('Could not read the selected file.');
      return;
    }
    provider.selectFile(file.name, bytes, widget.project.ecosystem);
  }

  void _openDependency(DependencyResult dependency) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DependencyDetailScreen(dependency: dependency),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProjectAnalysisProvider>();
    final project = widget.project;
    final current = p.projectId == project.id; // never show another project's data

    final subtitle = [
      project.ecosystem.fileName,
      if (project.repoUrl != null) project.repoUrl!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Project',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1000;
                final upload = _UploadCard(project: project, onPick: _pick);
                final main = _MainColumn(
                  current: current,
                  onOpenDependency: _openDependency,
                );
                const history = _HistorySection();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageHeader(
                      title: project.name,
                      subtitle: subtitle,
                      badge:
                      StatusBadge(project.ecosystem.label, AppColors.accent),
                    ),
                    const SizedBox(height: 24),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: main),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 360,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                upload,
                                const SizedBox(height: 24),
                                if (current) history,
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          upload,
                          const SizedBox(height: 24),
                          main,
                          const SizedBox(height: 24),
                          if (current) history,
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main column: selected result + inventory ───────────────────────────────

class _MainColumn extends StatelessWidget {
  const _MainColumn({required this.current, required this.onOpenDependency});

  final bool current;
  final ValueChanged<DependencyResult> onOpenDependency;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProjectAnalysisProvider>();

    if (!current ||
        (p.historyLoading && p.selected == null && p.history.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final selected = p.selected;
    final isLatest = selected != null &&
        p.history.isNotEmpty &&
        p.history.first.id == selected.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.openError != null) ...[
          _InlineError(message: p.openError!.message),
          const SizedBox(height: 16),
        ],
        if (p.isOpening)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (selected != null)
          _ResultView(
            analysis: selected,
            isLatest: isLatest,
            onBackToLatest: p.history.isEmpty
                ? null
                : () => context
                .read<ProjectAnalysisProvider>()
                .openAnalysis(p.history.first.id),
            onOpenDependency: onOpenDependency,
          )
        else if (p.history.isEmpty && p.historyError == null)
            const _FirstRunEmpty(),
      ],
    );
  }
}

class _FirstRunEmpty extends StatelessWidget {
  const _FirstRunEmpty();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No analysis yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Upload this project\'s dependency file to see its compliance '
                'score, risky packages and maintenance predictions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.analysis,
    required this.isLatest,
    required this.onBackToLatest,
    required this.onOpenDependency,
  });

  final StoredAnalysis analysis;
  final bool isLatest;
  final VoidCallback? onBackToLatest;
  final ValueChanged<DependencyResult> onOpenDependency;

  @override
  Widget build(BuildContext context) {
    final r = analysis.result;
    final s = r.summary;
    final by = analysis.createdByEmail == null ? '' : ' · ${analysis.createdByEmail}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analysis result',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.filename} · ${formatDateTime(analysis.createdAt)}$by',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              StatusBadge(
                isLatest ? 'Latest' : 'Earlier analysis',
                isLatest ? AppColors.low : AppColors.medium,
              ),
              if (!isLatest && onBackToLatest != null)
                TextButton(
                  onPressed: onBackToLatest,
                  child: const Text('View latest'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MetricGrid(
          minTileWidth: 200,
          gap: 12,
          children: [
            StatCard(
              label: 'Compliance score',
              value: s.complianceScore?.toString() ?? '—',
              icon: Icons.verified_user_outlined,
              caption:
              s.highestRisk == null ? null : 'Highest risk: ${s.highestRisk}',
              accent: AppColors.riskColor(s.highestRisk),
            ),
            StatCard(
              label: 'Dependencies analysed',
              value: '${s.analyzed} / ${s.totalDependencies}',
              icon: Icons.inventory_2_outlined,
              caption: s.failed > 0 ? '${s.failed} could not be analysed' : null,
            ),
            StatCard(
              label: 'Vulnerable',
              value: '${s.vulnerable}',
              icon: Icons.bug_report_outlined,
              accent: AppColors.critical,
            ),
            StatCard(
              label: 'Licence violations',
              value: '${s.licenseViolations}',
              icon: Icons.gavel_rounded,
              accent: AppColors.high,
            ),
            StatCard(
              label: 'Unmaintained (ML)',
              value: '${s.unmaintained}',
              icon: Icons.build_circle_outlined,
              accent: AppColors.medium,
              caption: s.maintenanceUndetermined > 0
                  ? '${s.maintenanceUndetermined} undetermined'
                  : null,
            ),
            StatCard(
              label: 'Needs review',
              value: '${s.needsReview}',
              icon: Icons.flag_outlined,
              accent: AppColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Risk distribution',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              RiskDistributionBar(distribution: s.riskDistribution),
            ],
          ),
        ),
        for (final note in r.notes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              note,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 28),
        DependencyInventory(
          key: ValueKey(analysis.id), // fresh filters for each opened analysis
          dependencies: r.dependencies,
          onOpen: onOpenDependency,
        ),
      ],
    );
  }
}

// ── Side column: upload + history ──────────────────────────────────────────

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.project, required this.onPick});

  final Project project;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProjectAnalysisProvider>();
    final running = p.isRunning;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analyse a file',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload ${project.ecosystem.fileName}. It is analysed with the '
                'platform pipeline (package registries, vulnerability database and '
                'the maintenance ML model) and saved to this project\'s history.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: running ? null : onPick,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(p.hasFile ? 'Change file' : 'Choose file'),
              ),
              FilledButton.icon(
                onPressed: (!p.hasFile || running)
                    ? null
                    : () => context.read<ProjectAnalysisProvider>().run(),
                icon: running
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(running ? 'Analysing…' : 'Analyse'),
              ),
            ],
          ),
          if (p.hasFile)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${p.fileName} · ${(p.fileSize / 1024).toStringAsFixed(1)} KB',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          if (running)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Analysing dependencies. Large files can take a minute or two.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ),
          if (p.fileError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                p.fileError!,
                style: const TextStyle(color: AppColors.critical, fontSize: 13),
              ),
            ),
          if (p.runError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                p.runError!.message,
                style: const TextStyle(color: AppColors.critical, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProjectAnalysisProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Analysis history',
          subtitle: p.history.isEmpty
              ? null
              : '${p.history.length} saved · select one to view that result',
        ),
        const SizedBox(height: 12),
        if (p.historyError != null)
          _InlineError(message: p.historyError!.message)
        else if (p.historyLoading && p.history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (p.history.isEmpty)
            const Text(
              'No analyses yet.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            for (var i = 0; i < p.history.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryRow(
                  item: p.history[i],
                  isLatest: i == 0,
                  selected: p.history[i].id == p.selected?.id,
                  onTap: () => context
                      .read<ProjectAnalysisProvider>()
                      .openAnalysis(p.history[i].id),
                ),
              ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.item,
    required this.isLatest,
    required this.selected,
    required this.onTap,
  });

  final AnalysisHistoryItem item;
  final bool isLatest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = item.summary;
    final by = item.createdByEmail == null ? '' : ' · ${item.createdByEmail}';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        borderColor: selected ? AppColors.primary : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.filename,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isLatest) ...[
                  const SizedBox(width: 8),
                  const StatusBadge('Latest', AppColors.low),
                ],
                const SizedBox(width: 8),
                RiskBadge(s.highestRisk),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${formatDateTime(item.createdAt)}$by',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Score ${s.complianceScore?.toString() ?? '—'} · '
                  '${s.analyzed}/${s.totalDependencies} analysed · '
                  '${s.vulnerable} vulnerable',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.criticalBg,
      borderColor: AppColors.critical.withAlpha(60),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.critical),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}