// Typed models for the response of POST /analysis/run.
//
// Parsing is deliberately defensive: the backend omits many fields for failed
// or partially-analyzed dependencies, so every optional field is nullable and
// a missing value never throws.

Map<String, dynamic>? _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;
List<dynamic> _list(dynamic v) => v is List ? v : const [];
int? _int(dynamic v) => v is num ? v.toInt() : null;
double? _double(dynamic v) => v is num ? v.toDouble() : null;
String? _str(dynamic v) => v is String ? v : null;
bool? _bool(dynamic v) => v is bool ? v : null;
List<String> _strList(dynamic v) => _list(v).whereType<String>().toList();

const riskLevels = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

class AnalysisResult {
  AnalysisResult({
    required this.filename,
    required this.summary,
    required this.dependencies,
    required this.skipped,
    required this.notes,
    required this.policyUsed,
  });

  final String filename;
  final AnalysisSummary summary;
  final List<DependencyResult> dependencies;
  final int skipped;
  final List<String> notes;
  final Map<String, dynamic> policyUsed;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);
    if (summary == null || json['dependencies'] is! List) {
      throw const FormatException('Response is missing summary or dependencies');
    }
    return AnalysisResult(
      filename: _str(json['filename']) ?? 'dependency file',
      summary: AnalysisSummary.fromJson(summary),
      dependencies: _list(json['dependencies'])
          .map(_map)
          .whereType<Map<String, dynamic>>()
          .map(DependencyResult.fromJson)
          .toList(),
      skipped: _int(json['skipped']) ?? 0,
      notes: _strList(json['notes']),
      policyUsed: _map(json['policy_used']) ?? const {},
    );
  }
}

class AnalysisSummary {
  AnalysisSummary({
    required this.complianceScore,
    required this.highestRisk,
    required this.totalDependencies,
    required this.analyzed,
    required this.failed,
    required this.riskDistribution,
    required this.maintained,
    required this.unmaintained,
    required this.maintenanceUndetermined,
    required this.vulnerable,
    required this.licenseViolations,
    required this.needsReview,
  });

  /// null when no dependency could be analyzed. Never show this as 0.
  final int? complianceScore;
  final String? highestRisk;
  final int totalDependencies;
  final int analyzed;
  final int failed;
  final Map<String, int> riskDistribution;
  final int maintained;
  final int unmaintained;
  final int maintenanceUndetermined;
  final int vulnerable;
  final int licenseViolations;
  final int needsReview;

  factory AnalysisSummary.fromJson(Map<String, dynamic> j) {
    final dist = _map(j['risk_distribution']) ?? const {};
    return AnalysisSummary(
      complianceScore: _int(j['compliance_score']),
      highestRisk: _str(j['highest_risk']),
      totalDependencies: _int(j['total_dependencies']) ?? 0,
      analyzed: _int(j['analyzed']) ?? 0,
      failed: _int(j['failed']) ?? 0,
      riskDistribution: {
        for (final level in riskLevels) level: _int(dist[level]) ?? 0,
      },
      maintained: _int(j['maintained']) ?? 0,
      unmaintained: _int(j['unmaintained']) ?? 0,
      maintenanceUndetermined: _int(j['maintenance_undetermined']) ?? 0,
      vulnerable: _int(j['vulnerable']) ?? 0,
      licenseViolations: _int(j['license_violations']) ?? 0,
      needsReview: _int(j['needs_review']) ?? 0,
    );
  }
}

class DependencyResult {
  DependencyResult({
    required this.name,
    required this.ecosystem,
    required this.declaredVersion,
    required this.status,
    this.error,
    this.versionChecked,
    this.versionSource,
    this.registry,
    this.maintenance,
    this.vulnerabilities,
    this.rules,
    this.governance,
    this.riskRank,
  });

  final String name;
  final String ecosystem;
  final String? declaredVersion;

  /// "analyzed" or "failed".
  final String status;
  final String? error;
  final String? versionChecked;
  final String? versionSource;
  final RegistryInfo? registry;
  final MaintenanceInfo? maintenance;
  final VulnerabilityInfo? vulnerabilities;
  final RulesInfo? rules;
  final GovernanceInfo? governance;
  final int? riskRank;

  bool get isFailed => status != 'analyzed';

  // Convenience getters for tables and badges.
  String? get riskLevel => governance?.riskLevel;
  int? get score => governance?.score;
  String get maintenanceStatus =>
      maintenance?.status ?? 'Unable to determine';
  String? get licenseStatus => rules?.license.status;
  int? get vulnerabilityCount => vulnerabilities?.count;

  factory DependencyResult.fromJson(Map<String, dynamic> j) {
    final registry = _map(j['registry']);
    final maintenance = _map(j['maintenance']);
    final vulns = _map(j['vulnerabilities']);
    final rules = _map(j['rules']);
    final governance = _map(j['governance']);
    return DependencyResult(
      name: _str(j['name']) ?? 'unknown',
      ecosystem: _str(j['ecosystem']) ?? '',
      declaredVersion: _str(j['declared_version']),
      status: _str(j['status']) ?? 'failed',
      error: _str(j['error']),
      versionChecked: _str(j['version_checked']),
      versionSource: _str(j['version_source']),
      registry: registry == null ? null : RegistryInfo.fromJson(registry),
      maintenance:
          maintenance == null ? null : MaintenanceInfo.fromJson(maintenance),
      vulnerabilities:
          vulns == null ? null : VulnerabilityInfo.fromJson(vulns),
      rules: rules == null ? null : RulesInfo.fromJson(rules),
      governance:
          governance == null ? null : GovernanceInfo.fromJson(governance),
      riskRank: _int(j['risk_rank']),
    );
  }
}

class RegistryInfo {
  RegistryInfo({
    required this.found,
    this.latestVersion,
    this.license,
    this.repositoryUrl,
    this.description,
  });

  final bool found;
  final String? latestVersion;
  final String? license;
  final String? repositoryUrl;
  final String? description;

  factory RegistryInfo.fromJson(Map<String, dynamic> j) => RegistryInfo(
        found: _bool(j['found']) ?? false,
        latestVersion: _str(j['latest_version']),
        license: _str(j['license']),
        repositoryUrl: _str(j['repository_url']),
        description: _str(j['description']),
      );
}

class MaintenanceInfo {
  MaintenanceInfo({
    required this.status,
    this.probabilityUnmaintained,
    this.reason,
    this.repositoryUrl,
    this.archived,
    this.pushedAt,
    this.windows,
    this.features,
  });

  /// "Maintained", "Unmaintained" or "Unable to determine".
  /// Read from the nested prediction first, then the top level.
  final String status;
  final double? probabilityUnmaintained;

  /// Why the status could not be determined (only present in that case).
  final String? reason;
  final String? repositoryUrl;
  final bool? archived;
  final String? pushedAt;
  final dynamic windows;
  final Map<String, dynamic>? features;

  factory MaintenanceInfo.fromJson(Map<String, dynamic> j) {
    final prediction = _map(j['prediction']);
    final meta = _map(j['repository_metadata']);
    return MaintenanceInfo(
      status: _str(prediction?['status']) ??
          _str(j['status']) ??
          'Unable to determine',
      probabilityUnmaintained: _double(prediction?['probability_unmaintained']),
      reason: _str(j['reason']),
      repositoryUrl: _str(j['repository_url']),
      archived: _bool(meta?['archived']),
      pushedAt: _str(meta?['pushed_at']),
      windows: j['windows'],
      features: _map(j['features']),
    );
  }
}

class VulnerabilityItem {
  VulnerabilityItem({
    required this.id,
    this.summary,
    this.severity,
    this.aliases = const [],
    this.references = const [],
  });

  final String id;
  final String? summary;
  final String? severity;
  final List<String> aliases;
  final List<String> references;

  factory VulnerabilityItem.fromJson(Map<String, dynamic> j) =>
      VulnerabilityItem(
        id: _str(j['id']) ?? 'unknown',
        summary: _str(j['summary']),
        severity: _str(j['severity']),
        aliases: _strList(j['aliases']),
        references: _strList(j['references']),
      );
}

class VulnerabilityInfo {
  VulnerabilityInfo({
    required this.status,
    this.reason,
    this.queriedVersion,
    this.scope,
    this.count,
    this.highestSeverity,
    this.truncated = false,
    this.items = const [],
  });

  /// "ok", "unavailable" or "unsupported_ecosystem".
  /// Anything other than "ok" means we do NOT know the vulnerability state.
  final String status;
  final String? reason;
  final String? queriedVersion;
  final String? scope;
  final int? count;
  final String? highestSeverity;
  final bool truncated;
  final List<VulnerabilityItem> items;

  bool get isVerified => status == 'ok';

  factory VulnerabilityInfo.fromJson(Map<String, dynamic> j) =>
      VulnerabilityInfo(
        status: _str(j['status']) ?? 'unavailable',
        reason: _str(j['reason']),
        queriedVersion: _str(j['queried_version']),
        scope: _str(j['scope']),
        count: _int(j['vulnerability_count']),
        highestSeverity: _str(j['highest_severity']),
        truncated: _bool(j['truncated']) ?? false,
        items: _list(j['vulnerabilities'])
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .map(VulnerabilityItem.fromJson)
            .toList(),
      );
}

/// One rule result (license / vulnerability / maintenance).
class RuleResult {
  RuleResult({required this.status, this.reason, this.data = const {}});

  final String status;
  final String? reason;

  /// Raw map, for extra fields such as "raw", "families", "ml_status".
  final Map<String, dynamic> data;

  factory RuleResult.fromJson(Map<String, dynamic>? j) => RuleResult(
        status: _str(j?['status']) ?? 'UNKNOWN',
        reason: _str(j?['reason']),
        data: j ?? const {},
      );
}

class PolicyDecision {
  PolicyDecision({
    required this.status,
    this.violations = const [],
    this.reviewItems = const [],
  });

  /// "OK", "REVIEW" or "VIOLATION".
  final String status;
  final List<String> violations;
  final List<String> reviewItems;

  factory PolicyDecision.fromJson(Map<String, dynamic>? j) => PolicyDecision(
        status: _str(j?['policy_status']) ?? 'REVIEW',
        violations: _strList(j?['violations']),
        reviewItems: _strList(j?['review_items']),
      );
}

class RulesInfo {
  RulesInfo({
    required this.license,
    required this.vulnerability,
    required this.maintenance,
    required this.policy,
  });

  final RuleResult license;
  final RuleResult vulnerability;
  final RuleResult maintenance;
  final PolicyDecision policy;

  String? get detectedLicense => _str(license.data['raw']);

  factory RulesInfo.fromJson(Map<String, dynamic> j) => RulesInfo(
        license: RuleResult.fromJson(_map(j['license'])),
        vulnerability: RuleResult.fromJson(_map(j['vulnerability'])),
        maintenance: RuleResult.fromJson(_map(j['maintenance'])),
        policy: PolicyDecision.fromJson(_map(j['policy'])),
      );
}

class ComponentScore {
  ComponentScore({this.health, this.weight, this.points});

  final double? health;
  final double? weight;
  final double? points;

  factory ComponentScore.fromJson(Map<String, dynamic> j) => ComponentScore(
        health: _double(j['health']),
        weight: _double(j['weight']),
        points: _double(j['points']),
      );
}

class GovernanceInfo {
  GovernanceInfo({
    required this.score,
    required this.riskLevel,
    this.riskDrivers = const [],
    this.capApplied = false,
    this.components = const {},
  });

  final int score;
  final String riskLevel;
  final List<String> riskDrivers;
  final bool capApplied;

  /// Keys: "security", "maintenance", "license".
  final Map<String, ComponentScore> components;

  factory GovernanceInfo.fromJson(Map<String, dynamic> j) {
    final comps = _map(j['components']) ?? const {};
    return GovernanceInfo(
      score: _int(j['score']) ?? 0,
      riskLevel: _str(j['risk_level']) ?? 'MEDIUM',
      riskDrivers: _strList(j['risk_drivers']),
      capApplied: _bool(j['cap_applied']) ?? false,
      components: {
        for (final e in comps.entries)
          if (_map(e.value) != null)
            e.key: ComponentScore.fromJson(_map(e.value)!),
      },
    );
  }
}
