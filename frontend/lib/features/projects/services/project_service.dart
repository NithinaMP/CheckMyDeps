import '../../../core/services/api_client.dart';
import '../models/project.dart';

/// Talks to /orgs/{orgId}/projects. No UI code in here.
class ProjectService {
  ProjectService(this._api);

  final ApiClient _api;

  String _base(String orgId) => '/orgs/${Uri.encodeComponent(orgId)}/projects';

  Future<List<Project>> list(String orgId) async {
    final json = await _api.getJson(_base(orgId));
    return _guard(() {
      final raw = json['projects'];
      if (raw is! List) throw const FormatException('projects missing');
      return raw
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    });
  }

  Future<Project> create(
      String orgId, {
        required String name,
        required ProjectEcosystem ecosystem,
        String? repoUrl,
      }) async {
    final json = await _api.postJson(_base(orgId), {
      'name': name,
      'ecosystem': ecosystem.apiValue,
    'repo_url': ?repoUrl,    });
    return _guard(() => Project.fromJson(json));
  }

  T _guard<T>(T Function() parse) {
    try {
      return parse();
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.malformedResponse,
        'The server returned a project response the app could not read.',
      );
    }
  }
}