import 'dart:typed_data';

import '../../../core/services/api_client.dart';
import '../models/project_analysis.dart';

/// Talks to /orgs/{orgId}/projects/{projectId}/analyses. No UI code in here.
class ProjectAnalysisService {
  ProjectAnalysisService(this._api);

  final ApiClient _api;

  String _base(String orgId, String projectId) =>
      '/orgs/${Uri.encodeComponent(orgId)}'
          '/projects/${Uri.encodeComponent(projectId)}/analyses';

  Future<List<AnalysisHistoryItem>> history(
      String orgId, String projectId) async {
    final json = await _api.getJson(_base(orgId, projectId));
    return _guard(() {
      final raw = json['analyses'];
      if (raw is! List) throw const FormatException('analyses missing');
      return raw
          .map((e) =>
          AnalysisHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    });
  }

  /// Runs the platform pipeline on the uploaded file and stores the result.
  Future<StoredAnalysis> run(
      String orgId,
      String projectId, {
        required String filename,
        required Uint8List bytes,
      }) async {
    final json = await _api.postMultipart(
      _base(orgId, projectId),
      fileField: 'file',
      filename: filename,
      bytes: bytes,
    );
    return _guard(() => StoredAnalysis.fromJson(json));
  }

  Future<StoredAnalysis> get(
      String orgId, String projectId, String analysisId) async {
    final json = await _api
        .getJson('${_base(orgId, projectId)}/${Uri.encodeComponent(analysisId)}');
    return _guard(() => StoredAnalysis.fromJson(json));
  }

  T _guard<T>(T Function() parse) {
    try {
      return parse();
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.malformedResponse,
        'The server returned an analysis response the app could not read.',
      );
    }
  }
}