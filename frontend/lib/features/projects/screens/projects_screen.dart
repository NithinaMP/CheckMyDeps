import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/status_badges.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import 'project_detail_screen.dart';

enum _Sort { newest, risk, name }

const List<String> _riskOrder = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

/// Project list for the open organisation. `canCreate` only hides the button;
/// the backend enforces lead/admin on creation.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.orgId,
    required this.canCreate,
  });

  final String orgId;
  final bool canCreate;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  _Sort _sort = _Sort.newest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orgId != widget.orgId) _load();
  }

  void _load() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProjectProvider>().load(widget.orgId);
    });
  }

  Future<void> _create() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateProjectDialog(orgId: widget.orgId),
    );
  }

  Future<void> _open(Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(project: project),
      ),
    );
    // An analysis may have been run in there: refresh scores and badges.
    if (mounted) context.read<ProjectProvider>().load(widget.orgId);
  }

  int _riskIndex(Project p) {
    final risk = p.latestAnalysis?.summary.highestRisk;
    return risk == null ? -1 : _riskOrder.indexOf(risk.toUpperCase());
  }

  int _byRisk(Project a, Project b) {
    final ra = _riskIndex(a);
    final rb = _riskIndex(b);
    if (ra != rb) return rb.compareTo(ra); // highest risk first, unanalysed last
    final sa = a.latestAnalysis?.summary.complianceScore ?? 1000;
    final sb = b.latestAnalysis?.summary.complianceScore ?? 1000;
    if (sa != sb) return sa.compareTo(sb);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  List<Project> _sorted(List<Project> items) {
    final list = [...items]; // backend order is already newest first
    if (_sort == _Sort.name) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sort == _Sort.risk) {
      list.sort(_byRisk);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProjectProvider>();
    final current = p.orgId == widget.orgId; // never show another org's list
    final projects = current ? p.projects : const <Project>[];
    final loading = !current || p.isLoading;
    final error = current ? p.loadError : null;
    final analysed = projects.where((x) => x.latestAnalysis != null).length;
    final sorted = _sorted(projects);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Projects',
          subtitle: projects.isEmpty
              ? 'Dependency projects tracked by this organisation'
              : '${projects.length} project${projects.length == 1 ? '' : 's'} · '
              '$analysed analysed',
          action: widget.canCreate
              ? FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New project'),
          )
              : null,
        ),
        const SizedBox(height: 24),
        if (error != null) ...[
          _ErrorCard(
            message: error.message,
            onRetry: () => context.read<ProjectProvider>().load(widget.orgId),
          ),
          const SizedBox(height: 16),
        ],
        if (loading && projects.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (projects.isEmpty && error == null)
          _EmptyCard(canCreate: widget.canCreate, onCreate: _create)
        else ...[
            if (projects.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_Sort>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem<_Sort>(
                          value: _Sort.newest, child: Text('Sort: newest')),
                      DropdownMenuItem<_Sort>(
                          value: _Sort.risk, child: Text('Sort: highest risk')),
                      DropdownMenuItem<_Sort>(
                          value: _Sort.name, child: Text('Sort: name')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                ),
              ),
            for (final project in sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProjectCard(
                  project: project,
                  onTap: () => _open(project),
                ),
              ),
          ],
      ],
    );
  }
}

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = project.latestAnalysis;
    final parts = <String>[
      project.ecosystem.fileName,
      if (project.repoUrl != null) project.repoUrl!,
      if (project.createdAt != null) 'Created ${_date(project.createdAt!)}',
    ];

    final icon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.folder_rounded, color: AppColors.primary, size: 20),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          project.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          parts.join(' · '),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );

    final metrics = latest == null
        ? const Text(
      'Not analysed yet',
      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
    )
        : Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RiskBadge(latest.summary.highestRisk),
        Text(
          'Score ${latest.summary.complianceScore?.toString() ?? '—'}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 12.5,
          ),
        ),
        _Metric(
          icon: Icons.bug_report_outlined,
          value: latest.summary.vulnerable,
          tooltip: 'Vulnerable dependencies',
          activeColor: AppColors.critical,
        ),
        _Metric(
          icon: Icons.gavel_rounded,
          value: latest.summary.licenseViolations,
          tooltip: 'Licence violations',
          activeColor: AppColors.high,
        ),
        _Metric(
          icon: Icons.build_circle_outlined,
          value: latest.summary.unmaintained,
          tooltip: 'Unmaintained (ML)',
          activeColor: AppColors.medium,
        ),
      ],
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: 14),
                      Expanded(child: titleBlock),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatusBadge(project.ecosystem.label, AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(child: metrics),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                icon,
                const SizedBox(width: 14),
                Expanded(child: titleBlock),
                const SizedBox(width: 16),
                StatusBadge(project.ecosystem.label, AppColors.accent),
                const SizedBox(width: 20),
                Flexible(child: metrics),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.tooltip,
    required this.activeColor,
  });

  final IconData icon;
  final int value;
  final String tooltip;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 15, color: active ? activeColor : AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: active ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.canCreate, required this.onCreate});

  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.folder_open_rounded,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No projects yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canCreate
                ? 'Create a project to start tracking its dependencies.'
                : 'An admin or lead needs to create the first project.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (canCreate) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create first project'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

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

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog({required this.orgId});

  final String orgId;

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _repo = TextEditingController();
  ProjectEcosystem _ecosystem = ProjectEcosystem.pub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProjectProvider>().clearActionError();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _repo.dispose();
    super.dispose();
  }

  /// Mirrors the backend: 2-80 characters after trimming.
  String? _validateName(String? value) {
    final v = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.length < 2) return 'Enter at least 2 characters';
    if (v.length > 80) return 'Use 80 characters or fewer';
    return null;
  }

  String? _validateRepo(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final ok = v.length <= 300 && RegExp(r'^https?://\S+$').hasMatch(v);
    return ok ? null : 'Enter a valid http(s) link';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = _repo.text.trim();
    final ok = await context.read<ProjectProvider>().createProject(
      orgId: widget.orgId,
      name: _name.text.trim(),
      ecosystem: _ecosystem,
      repoUrl: repo.isEmpty ? null : repo,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final busy = provider.isBusy;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'New project',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  enabled: !busy,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Project name'),
                  validator: _validateName,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dependency file type',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in ProjectEcosystem.values)
                      ChoiceChip(
                        label: Text('${e.label} · ${e.fileName}'),
                        selected: _ecosystem == e,
                        onSelected:
                        busy ? null : (_) => setState(() => _ecosystem = e),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _repo,
                  enabled: !busy,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Repository link (optional)',
                    hintText: 'https://github.com/org/repo',
                  ),
                  validator: _validateRepo,
                ),
                if (provider.actionError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    provider.actionError!.message,
                    style: const TextStyle(
                      color: AppColors.critical,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text('Create'),
        ),
      ],
    );
  }
}