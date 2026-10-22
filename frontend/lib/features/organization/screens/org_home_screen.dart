import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/governance_widgets.dart';
import '../../../core/widgets/status_badges.dart';
import '../../projects/screens/project_detail_screen.dart';
import '../models/org_dashboard.dart';
import '../models/organization.dart';
import '../providers/org_dashboard_provider.dart';
import '../providers/organization_provider.dart';

/// Organisation overview: real figures from each project's latest saved analysis.
class OrgHomeScreen extends StatefulWidget {
  const OrgHomeScreen({
    super.key,
    required this.orgId,
    required this.onOpenProjects,
  });

  final String orgId;
  final VoidCallback onOpenProjects;

  @override
  State<OrgHomeScreen> createState() => _OrgHomeScreenState();
}

class _OrgHomeScreenState extends State<OrgHomeScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrgDashboardProvider>().load(widget.orgId);
    });
  }

  Future<void> _openProject(DashboardProject project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProjectDetailScreen(project: project.toProject(widget.orgId)),
      ),
    );
    // An analysis may have been run in there: refresh the figures.
    if (mounted) context.read<OrgDashboardProvider>().load(widget.orgId);
  }

  Future<void> _rename(OrgMembership m) async {
    final provider = context.read<OrganizationProvider>();
    provider.clearActionError();
    final controller = TextEditingController(text: m.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Rename organisation'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Organisation name'),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == m.name) return;

    final ok = await provider.renameActive(newName);
    if (!ok && mounted && provider.actionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.actionError!.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>();
    final m = org.activeMembership;
    if (m == null || m.id != widget.orgId) return const SizedBox.shrink();

    final dash = context.watch<OrgDashboardProvider>();
    final current = dash.orgId == widget.orgId; // never show another org's data
    final data = current ? dash.data : null;
    final error = current ? dash.error : null;
    final loading = !current || dash.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: m.name,
          subtitle: 'Organisation overview',
          badge: StatusBadge(m.role.label, AppColors.primary),
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: loading
                    ? null
                    : () =>
                    context.read<OrgDashboardProvider>().load(widget.orgId),
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (org.hasRole(OrgRole.admin)) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: org.isBusy ? null : () => _rename(m),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Rename'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (error != null) ...[
          _ErrorBanner(
            message: error.message,
            onRetry: () =>
                context.read<OrgDashboardProvider>().load(widget.orgId),
          ),
          const SizedBox(height: 16),
        ],
        if (data == null) ...[
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 56),
              child: Center(child: CircularProgressIndicator()),
            ),
        ] else if (data.totals.projects == 0)
          _NoProjects(
            canCreate: org.hasRole(OrgRole.lead),
            onOpenProjects: widget.onOpenProjects,
          )
        else
          _DashboardBody(
            data: data,
            onOpenProject: _openProject,
            onOpenProjects: widget.onOpenProjects,
          ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.onOpenProject,
    required this.onOpenProjects,
  });

  final OrgDashboard data;
  final ValueChanged<DashboardProject> onOpenProject;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final t = data.totals;
    final vulnerablePct = t.dependenciesAnalysed == 0
        ? null
        : '${(t.vulnerable * 100 / t.dependenciesAnalysed).round()}% of analysed dependencies';

    final attention = _AttentionCard(
      projects: data.attentionProjects,
      analysedProjects: t.analysedProjects,
      onOpen: onOpenProject,
      onOpenProjects: onOpenProjects,
    );
    final distribution = _DistributionCard(totals: t);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricGrid(
          minTileWidth: 280,
          children: [
            StatCard(
              label: 'Projects',
              value: '${t.projects}',
              icon: Icons.folder_outlined,
              caption:
              '${t.analysedProjects} analysed · ${t.notAnalysedProjects} not yet analysed',
            ),
            StatCard(
              label: 'Compliance score',
              value: t.complianceScore?.toString() ?? '—',
              icon: Icons.verified_user_outlined,
              accent: AppColors.primary,
              caption: t.complianceScore == null
                  ? 'Needs at least one analysed project'
                  : '0–100, higher is better · '
                  '${t.complianceProjects} project${t.complianceProjects == 1 ? '' : 's'}',
            ),
            StatCard(
              label: 'Dependencies analysed',
              value: '${t.dependenciesAnalysed}',
              icon: Icons.inventory_2_outlined,
              caption: t.dependenciesFailed > 0
                  ? '${t.dependenciesFailed} could not be analysed'
                  : 'across latest analyses',
            ),
            StatCard(
              label: 'Vulnerable dependencies',
              value: '${t.vulnerable}',
              icon: Icons.bug_report_outlined,
              accent: AppColors.critical,
              caption: vulnerablePct,
            ),
            StatCard(
              label: 'Licence violations',
              value: '${t.licenseViolations}',
              icon: Icons.gavel_rounded,
              accent: AppColors.high,
            ),
            StatCard(
              label: 'Unmaintained (ML)',
              value: '${t.unmaintained}',
              icon: Icons.build_circle_outlined,
              accent: AppColors.medium,
              caption: t.maintenanceUndetermined > 0
                  ? '${t.maintenanceUndetermined} undetermined'
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: attention),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: distribution),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [attention, const SizedBox(height: 16), distribution],
            );
          },
        ),
        const SizedBox(height: 24),
        _RecentCard(projects: data.recentAnalyses, onOpen: onOpenProject),
        if (data.notAnalysedProjects.isNotEmpty) ...[
          const SizedBox(height: 24),
          _NotAnalysedCard(
            projects: data.notAnalysedProjects,
            totalCount: t.notAnalysedProjects,
            onOpen: onOpenProject,
          ),
        ],
        const SizedBox(height: 24),
        const _HowCalculated(),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.projects,
    required this.analysedProjects,
    required this.onOpen,
    required this.onOpenProjects,
  });

  final List<DashboardProject> projects;
  final int analysedProjects;
  final ValueChanged<DashboardProject> onOpen;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Needs attention',
            subtitle:
            'Projects with medium or higher risk in their latest analysis, highest first',
            trailing: TextButton(
              onPressed: onOpenProjects,
              child: const Text('All projects'),
            ),
          ),
          const SizedBox(height: 8),
          if (projects.isEmpty)
            _EmptyLine(
              icon: analysedProjects == 0
                  ? Icons.upload_file_outlined
                  : Icons.check_circle_outline_rounded,
              text: analysedProjects == 0
                  ? 'Analyse a project to see its risk ranking here.'
                  : 'No analysed project has medium or higher risk.',
            )
          else
            for (var i = 0; i < projects.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _ProjectRow(
                project: projects[i],
                subtitle: _riskSubtitle(projects[i]),
                onTap: () => onOpen(projects[i]),
              ),
            ],
        ],
      ),
    );
  }
}

String _riskSubtitle(DashboardProject p) =>
    '${p.ecosystem.label} · Score ${p.complianceScore ?? '—'} · '
        '${p.vulnerable} vulnerable · ${p.licenseViolations} licence · '
        '${p.unmaintained} unmaintained';

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.totals});

  final DashboardTotals totals;

  @override
  Widget build(BuildContext context) {
    const order = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
    final byHighest = totals.projectsByHighestRisk;
    final hasAny = order.any((l) => (byHighest[l] ?? 0) > 0);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Dependency risk',
            subtitle: 'All analysed dependencies, latest analysis of each project',
          ),
          const SizedBox(height: 16),
          RiskDistributionBar(distribution: totals.riskDistribution),
          const SizedBox(height: 20),
          const Text(
            'Projects by highest risk',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (!hasAny)
            const Text(
              'No analysed projects yet.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in order)
                  if ((byHighest[level] ?? 0) > 0)
                    StatusBadge(
                      '$level · ${byHighest[level]}',
                      AppColors.riskColor(level),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.projects, required this.onOpen});

  final List<DashboardProject> projects;
  final ValueChanged<DashboardProject> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Recent analyses',
            subtitle: 'Most recently analysed projects',
          ),
          const SizedBox(height: 8),
          if (projects.isEmpty)
            const _EmptyLine(
              icon: Icons.history_rounded,
              text: 'No analyses have been run yet.',
            )
          else
            for (var i = 0; i < projects.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _ProjectRow(
                project: projects[i],
                subtitle:
                '${projects[i].filename ?? 'dependency file'} · '
                    '${formatDateTime(projects[i].analysedAt)} · '
                    'Score ${projects[i].complianceScore ?? '—'}',
                onTap: () => onOpen(projects[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _NotAnalysedCard extends StatelessWidget {
  const _NotAnalysedCard({
    required this.projects,
    required this.totalCount,
    required this.onOpen,
  });

  final List<DashboardProject> projects;
  final int totalCount;
  final ValueChanged<DashboardProject> onOpen;

  @override
  Widget build(BuildContext context) {
    final more = totalCount - projects.length;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Not analysed yet',
            subtitle: 'Open a project and upload its dependency file',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < projects.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ProjectRow(
              project: projects[i],
              subtitle: '${projects[i].ecosystem.label} · '
                  '${projects[i].ecosystem.fileName}',
              showRisk: false,
              onTap: () => onOpen(projects[i]),
            ),
          ],
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ $more more',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.subtitle,
    required this.onTap,
    this.showRisk = true,
  });

  final DashboardProject project;
  final String subtitle;
  final VoidCallback onTap;
  final bool showRisk;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (showRisk && project.hasAnalysis) ...[
              const SizedBox(width: 10),
              RiskBadge(project.highestRisk),
            ],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowCalculated extends StatelessWidget {
  const _HowCalculated();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12.5,
      height: 1.5,
    );
    return const AppCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('How these figures are calculated'),
          SizedBox(height: 10),
          Text(
            'Every figure uses each project\'s most recent saved analysis. '
                'Nothing is re-analysed when this page loads, and projects that '
                'have not been analysed are not counted.',
            style: style,
          ),
          SizedBox(height: 8),
          Text(
            'Compliance score: the risk-weighted average of dependency scores '
                '(0–100, higher is better) across all analysed dependencies. '
                'Project scores are combined with the same weights the analysis '
                'uses (Low ×1, Medium ×2, High ×3, Critical ×4), so a project with '
                'many high-risk packages counts for more. Scores are saved '
                'rounded, so the result can differ from an exact recalculation by '
                'less than one point.',
            style: style,
          ),
          SizedBox(height: 8),
          Text(
            'Vulnerable, licence violations and unmaintained are counts of '
                'dependencies, summed over projects. "Unmaintained" comes from the '
                'repository maintenance ML model; dependencies it could not assess '
                'are reported as undetermined, not as maintained.',
            style: style,
          ),
        ],
      ),
    );
  }
}

class _NoProjects extends StatelessWidget {
  const _NoProjects({required this.canCreate, required this.onOpenProjects});

  final bool canCreate;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.folder_open_rounded,
              size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No projects yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canCreate
                ? 'Create a project, upload its dependency file, and this '
                'overview will show compliance, vulnerabilities and risk.'
                : 'An admin or lead needs to create the first project. '
                'This overview fills in once a project has been analysed.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpenProjects,
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: const Text('Go to Projects'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}