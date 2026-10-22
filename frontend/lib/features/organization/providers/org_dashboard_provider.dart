import 'package:flutter/foundation.dart';

import '../../../core/services/api_client.dart';
import '../models/org_dashboard.dart';
import '../services/org_dashboard_service.dart';

enum DashboardStatus { idle, loading, ready, error }

/// Dashboard of the organisation currently open. Figures come from the backend,
/// which aggregates saved analyses; nothing is computed or invented here.
class OrgDashboardProvider extends ChangeNotifier {
  OrgDashboardProvider(this._service);

  final OrgDashboardService _service;

  String? _orgId;
  OrgDashboard? _data;
  DashboardStatus _status = DashboardStatus.idle;
  ApiException? _error;
  int _request = 0; // latest load wins

  String? get orgId => _orgId;
  OrgDashboard? get data => _data;
  DashboardStatus get status => _status;
  bool get isLoading => _status == DashboardStatus.loading;
  ApiException? get error => _error;

  Future<void> load(String orgId) async {
    final token = ++_request;
    if (_orgId != orgId) {
      _orgId = orgId;
      _data = null; // never show another organisation's figures
    }
    _status = DashboardStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.load(orgId);
      if (token != _request) return;
      _data = result;
      _status = DashboardStatus.ready;
    } on ApiException catch (e) {
      if (token != _request) return;
      _error = e; // previous data for the same organisation stays visible
      _status = DashboardStatus.error;
    } catch (_) {
      if (token != _request) return;
      _error = const ApiException(
        ApiErrorKind.unknown,
        'Could not load the organisation overview.',
      );
      _status = DashboardStatus.error;
    }
    notifyListeners();
  }

  /// Call on sign-out.
  void reset() {
    _request++;
    _orgId = null;
    _data = null;
    _status = DashboardStatus.idle;
    _error = null;
    notifyListeners();
  }
}