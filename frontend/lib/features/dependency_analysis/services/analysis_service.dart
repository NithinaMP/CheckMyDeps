import 'dart:convert';
import 'dart:typed_data';

import '../../../core/services/api_client.dart';
import '../models/analysis_result.dart';

/// Talks to POST /analysis/run. No UI code in here.
class AnalysisService {
  AnalysisService(this._api);

  final ApiClient _api;

  Future<AnalysisResult> run({
    required String filename,
    required Uint8List bytes,
    Map<String, dynamic>? policy,
  }) async {
    final json = await _api.postMultipart(
      '/analysis/run',
      fileField: 'file',
      filename: filename,
      bytes: bytes,
      fields: policy == null ? const {} : {'policy_json': jsonEncode(policy)},
    );

    try {
      return AnalysisResult.fromJson(json);
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.malformedResponse,
        'The analysis finished but the response was not in the expected format.',
      );
    }
  }

  /// Calls the limited unauthenticated guest endpoint: POST /analysis/guest-run
  Future<AnalysisResult> runGuest({
    required String filename,
    required Uint8List bytes,
  }) async {
    final json = await _api.postMultipart(
      '/analysis/guest-run',
      fileField: 'file',
      filename: filename,
      bytes: bytes,
      requiresAuth: false,
    );

    try {
      return AnalysisResult.fromJson(json);
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.malformedResponse,
        'The analysis finished but the response was not in the expected format.',
      );
    }
  }
}
