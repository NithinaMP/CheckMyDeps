import '../../dependency_analysis/models/analysis_result.dart';

/// One row of a project's analysis history (summary only).
class AnalysisHistoryItem {
  const AnalysisHistoryItem({
    required this.id,
    required this.filename,
    required this.summary,
    this.createdAt,
    this.createdByEmail,
  });

  final String id;
  final String filename;
  final AnalysisSummary summary;
  final DateTime? createdAt;
  final String? createdByEmail;

  factory AnalysisHistoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final filename = json['filename'];
    final summary = json['summary'];
    if (id is! String || id.isEmpty || filename is! String || summary is! Map) {
      throw const FormatException('Invalid analysis history payload');
    }
    final created = json['created_at'];
    final email = json['created_by_email'];
    return AnalysisHistoryItem(
      id: id,
      filename: filename,
      summary: AnalysisSummary.fromJson(Map<String, dynamic>.from(summary)),
      createdAt: created is String ? DateTime.tryParse(created) : null,
      createdByEmail: email is String ? email : null,
    );
  }
}

/// A full stored analysis: the same result shape the personal workspace uses.
class StoredAnalysis {
  const StoredAnalysis({
    required this.id,
    required this.result,
    this.createdAt,
    this.createdByEmail,
  });

  final String id;
  final AnalysisResult result;
  final DateTime? createdAt;
  final String? createdByEmail;

  factory StoredAnalysis.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Invalid stored analysis payload');
    }
    final created = json['created_at'];
    final email = json['created_by_email'];
    return StoredAnalysis(
      id: id,
      result: AnalysisResult.fromJson(json),
      createdAt: created is String ? DateTime.tryParse(created) : null,
      createdByEmail: email is String ? email : null,
    );
  }

  AnalysisHistoryItem toHistoryItem() => AnalysisHistoryItem(
    id: id,
    filename: result.filename,
    summary: result.summary,
    createdAt: createdAt,
    createdByEmail: createdByEmail,
  );
}