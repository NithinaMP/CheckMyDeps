import '../../projects/models/project.dart';

const List<String> _levels = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

int _int(Object? v) => v is num ? v.toInt() : 0;
int? _optInt(Object? v) => v is num ? v.toInt() : null;
String? _optStr(Object? v) => v is String && v.isNotEmpty ? v : null;
DateTime? _optDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, int> _distribution(Object? raw) {
  final map = raw is Map ? raw : const <String, Object?>{};
  return {for (final level in _levels) level: _int(map[level])};
}

/// One project on the dashboard, with its latest saved analysis (if any).
class DashboardProject {
  const DashboardProject({
    required this.id,
    required this.name,
    required this.ecosystem,
    this.repoUrl,
    this.createdAt,
    this.analysisId,
    this.filename,
    this.analysedAt,
    this.complianceScore,
    this.highestRisk,
    this.riskDistribution = const {},
    this.totalDependencies = 0,
    this.analyzed = 0,
    this.failed = 0,
    this.vulnerable = 0,
    this.licenseViolations = 0,
    this.unmaintained = 0,
  });

  final String id;
  final String name;
  final ProjectEcosystem ecosystem;
  final String? repoUrl;
  final DateTime? createdAt;
  final String? analysisId;
  final String? filename;
  final DateTime? analysedAt;
  final int? complianceScore;
  final String? highestRisk;
  final Map<String, int> riskDistribution;
  final int totalDependencies;
  final int analyzed;
  final int failed;
  final int vulnerable;
  final int licenseViolations;
  final int unmaintained;

  bool get hasAnalysis => analysisId != null;

  /// Enough to open the project detail screen.
  Project toProject(String orgId) => Project(
    id: id,
    orgId: orgId,
    name: name,
    ecosystem: ecosystem,
    repoUrl: repoUrl,
    createdAt: createdAt,
  );

  factory DashboardProject.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final name = j['name'];
    final ecosystem = ProjectEcosystem.tryParse(j['ecosystem']);
    if (id is! String || id.isEmpty || name is! String || ecosystem == null) {
      throw const FormatException('Invalid dashboard project');
    }
    return DashboardProject(
      id: id,
      name: name,
      ecosystem: ecosystem,
      repoUrl: _optStr(j['repo_url']),
      createdAt: _optDate(j['created_at']),
      analysisId: _optStr(j['analysis_id']),
      filename: _optStr(j['filename']),
      analysedAt: _optDate(j['analysed_at']),
      complianceScore: _optInt(j['compliance_score']),
      highestRisk: _optStr(j['highest_risk']),
      riskDistribution: _distribution(j['risk_distribution']),
      totalDependencies: _int(j['total_dependencies']),
      analyzed: _int(j['analyzed']),
      failed: _int(j['failed']),
      vulnerable: _int(j['vulnerable']),
      licenseViolations: _int(j['license_violations']),
      unmaintained: _int(j['unmaintained']),
    );
  }
}

class DashboardTotals {
  const DashboardTotals({
    required this.projects,
    required this.analysedProjects,
    required this.notAnalysedProjects,
    required this.dependenciesTotal,
    required this.dependenciesAnalysed,
    required this.dependenciesFailed,
    required this.vulnerable,
    required this.licenseViolations,
    required this.unmaintained,
    required this.maintenanceUndetermined,
    required this.needsReview,
    required this.riskDistribution,
    required this.projectsByHighestRisk,
    required this.complianceProjects,
    this.complianceScore,
  });

  final int projects;
  final int analysedProjects;
  final int notAnalysedProjects;
  final int dependenciesTotal;
  final int dependenciesAnalysed;
  final int dependenciesFailed;
  final int vulnerable;
  final int licenseViolations;
  final int unmaintained;
  final int maintenanceUndetermined;
  final int needsReview;
  final Map<String, int> riskDistribution;
  final Map<String, int> projectsByHighestRisk;
  final int complianceProjects;
  final int? complianceScore;

  factory DashboardTotals.fromJson(Map<String, dynamic> j) => DashboardTotals(
    projects: _int(j['projects']),
    analysedProjects: _int(j['analysed_projects']),
    notAnalysedProjects: _int(j['not_analysed_projects']),
    dependenciesTotal: _int(j['dependencies_total']),
    dependenciesAnalysed: _int(j['dependencies_analysed']),
    dependenciesFailed: _int(j['dependencies_failed']),
    vulnerable: _int(j['vulnerable']),
    licenseViolations: _int(j['license_violations']),
    unmaintained: _int(j['unmaintained']),
    maintenanceUndetermined: _int(j['maintenance_undetermined']),
    needsReview: _int(j['needs_review']),
    riskDistribution: _distribution(j['risk_distribution']),
    projectsByHighestRisk: _distribution(j['projects_by_highest_risk']),
    complianceProjects: _int(j['compliance_projects']),
    complianceScore: _optInt(j['compliance_score']),
  );
}

class OrgDashboard {
  const OrgDashboard({
    required this.totals,
    required this.recentAnalyses,
    required this.attentionProjects,
    required this.notAnalysedProjects,
    this.generatedAt,
  });

  final DashboardTotals totals;
  final List<DashboardProject> recentAnalyses;
  final List<DashboardProject> attentionProjects;
  final List<DashboardProject> notAnalysedProjects;
  final DateTime? generatedAt;

  factory OrgDashboard.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'];
    if (totals is! Map) {
      throw const FormatException('Invalid dashboard payload');
    }
    return OrgDashboard(
      totals: DashboardTotals.fromJson(Map<String, dynamic>.from(totals)),
      recentAnalyses: _projects(j['recent_analyses']),
      attentionProjects: _projects(j['attention_projects']),
      notAnalysedProjects: _projects(j['not_analysed_projects']),
      generatedAt: _optDate(j['generated_at']),
    );
  }

  /// A malformed entry is skipped; it never breaks the whole dashboard.
  static List<DashboardProject> _projects(Object? raw) {
    if (raw is! List) return const [];
    final out = <DashboardProject>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(DashboardProject.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        continue;
      }
    }
    return out;
  }
}