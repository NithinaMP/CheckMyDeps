import '../../../core/services/api_client.dart';
import '../models/organization.dart';
// import '../models/organization.dart';

/// Talks to /orgs. No UI code in here.
class OrganizationService {
  OrganizationService(this._api);

  final ApiClient _api;

  Future<List<OrgMembership>> listMine() async {
    final json = await _api.getJson('/orgs');
    return _guard(() {
      final raw = json['organizations'];
      if (raw is! List) throw const FormatException('organizations missing');
      return raw
          .map((e) => OrgMembership.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    });
  }

  Future<OrgMembership> create(String name) async {
    final json = await _api.postJson('/orgs', {'name': name});
    return _guard(() => OrgMembership.fromJson(json));
  }

  Future<OrgMembership> rename(String orgId, String name) async {
    final json = await _api.patchJson(
      '/orgs/${Uri.encodeComponent(orgId)}',
      {'name': name},
    );
    return _guard(() => OrgMembership.fromJson(json));
  }

  T _guard<T>(T Function() parse) {
    try {
      return parse();
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.malformedResponse,
        'The server returned an organisation response the app could not read.',
      );
    }
  }
}
