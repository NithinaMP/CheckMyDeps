import '../../dependency_analysis/models/analysis_result.dart';

/// Same identifiers the backend parser/registry already use.
enum ProjectEcosystem {
  pub('pub', 'Flutter / Dart', 'pubspec.yaml'),
  pypi('PyPI', 'Python', 'requirements.txt'),
  npm('npm', 'Node.js', 'package.json');

  const ProjectEcosystem(this.apiValue, this.label, this.fileName);

  final String apiValue;
  final String label;
  final String fileName;

  static ProjectEcosystem? tryParse(Object? value) {
    if (value is! String) return null;
    for (final e in ProjectEcosystem.values) {
      if (e.apiValue == value) return e;
    }
    return null;
  }

  /// Mirrors the backend parser's file detection for this ecosystem.
  bool acceptsFile(String filename) {
    final lower = filename.toLowerCase();
    switch (this) {
      case ProjectEcosystem.pub:
        return lower.endsWith('.yaml');
      case ProjectEcosystem.pypi:
        return lower.endsWith('requirements.txt');
      case ProjectEcosystem.npm:
        return lower.endsWith('package.json');
    }
  }
}

/// Pointer to a project's most recent stored analysis (summary only).
class LatestAnalysis {
  const LatestAnalysis({
    required this.id,
    required this.filename,
    required this.summary,
    this.createdAt,
  });

  final String id;
  final String filename;
  final AnalysisSummary summary;
  final DateTime? createdAt;

  factory LatestAnalysis.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final filename = json['filename'];
    final summary = json['summary'];
    if (id is! String || filename is! String || summary is! Map) {
      throw const FormatException('Invalid latest analysis payload');
    }
    final created = json['created_at'];
    return LatestAnalysis(
      id: id,
      filename: filename,
      summary: AnalysisSummary.fromJson(Map<String, dynamic>.from(summary)),
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.orgId,
    required this.name,
    required this.ecosystem,
    this.repoUrl,
    this.createdAt,
    this.latestAnalysis,
  });

  final String id;
  final String orgId;
  final String name;
  final ProjectEcosystem ecosystem;
  final String? repoUrl;
  final DateTime? createdAt;
  final LatestAnalysis? latestAnalysis;

  factory Project.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final orgId = json['org_id'];
    final name = json['name'];
    final ecosystem = ProjectEcosystem.tryParse(json['ecosystem']);
    if (id is! String ||
        id.isEmpty ||
        orgId is! String ||
        name is! String ||
        ecosystem == null) {
      throw const FormatException('Invalid project payload');
    }
    final repo = json['repo_url'];
    final created = json['created_at'];

    // A malformed pointer must never break the project list.
    LatestAnalysis? latest;
    final rawLatest = json['latest_analysis'];
    if (rawLatest is Map) {
      try {
        latest = LatestAnalysis.fromJson(Map<String, dynamic>.from(rawLatest));
      } catch (_) {
        latest = null;
      }
    }

    return Project(
      id: id,
      orgId: orgId,
      name: name,
      ecosystem: ecosystem,
      repoUrl: repo is String && repo.isNotEmpty ? repo : null,
      createdAt: created is String ? DateTime.tryParse(created) : null,
      latestAnalysis: latest,
    );
  }
}