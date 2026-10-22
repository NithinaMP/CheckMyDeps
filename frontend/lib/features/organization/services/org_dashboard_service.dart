import '../../../core/services/api_client.dart';
import '../models/org_dashboard.dart';

/// Talks to GET /orgs/{orgId}/dashboard. No UI code in here.
class OrgDashboardService {
  OrgDashboardService(this._api);

  final ApiClient _api;

  Future<OrgDashboard> load(String orgId) async {
    final json =
    await _api.getJson('/orgs/${Uri.encodeComponent(orgId)}/dashboard');
    try {
      return OrgDashboard.fromJson(json);
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.malformedResponse,
        'The server returned a dashboard response the app could not read.',
      );
    }
  }
}