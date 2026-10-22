import 'package:flutter/foundation.dart';

import '../../../core/services/api_client.dart';
import '../models/organization.dart';
import '../services/organisation_service.dart';
// import '../services/organization_service.dart';

enum OrgLoadStatus { idle, loading, ready, error }

/// Holds the signed-in user's organisation memberships and which workspace is active.
///
/// `activeOrgId == null` means the Personal workspace (existing behaviour).
/// SECURITY NOTE: the active org and role here only drive the UI. They are never
/// trusted by the backend, which re-verifies membership + role on every request.
class OrganizationProvider extends ChangeNotifier {
  OrganizationProvider(this._service);

  final OrganizationService _service;

  OrgLoadStatus _status = OrgLoadStatus.idle;
  List<OrgMembership> _memberships = const [];
  String? _activeOrgId;
  ApiException? _loadError;
  ApiException? _actionError;
  bool _busy = false;
  int _generation = 0; // bumped on reset() so late responses are discarded

  OrgLoadStatus get status => _status;
  bool get isLoading => _status == OrgLoadStatus.loading;
  bool get isBusy => _busy;
  List<OrgMembership> get memberships => _memberships;
  ApiException? get loadError => _loadError;
  ApiException? get actionError => _actionError;

  OrgMembership? get activeMembership {
    final id = _activeOrgId;
    if (id == null) return null;
    for (final m in _memberships) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool get isOrgWorkspace => activeMembership != null;
  OrgRole? get activeRole => activeMembership?.role;

  /// UI gating helper. False in the Personal workspace.
  bool hasRole(OrgRole minimum) => activeRole?.atLeast(minimum) ?? false;

  Future<void> load() async {
    if (isLoading) return;
    final gen = _generation;
    _status = OrgLoadStatus.loading;
    _loadError = null;
    notifyListeners();

    try {
      final result = await _service.listMine();
      if (gen != _generation) return;
      _memberships = result;
      if (_activeOrgId != null && !result.any((m) => m.id == _activeOrgId)) {
        _activeOrgId = null; // membership gone -> back to Personal
      }
      _status = OrgLoadStatus.ready;
    } on ApiException catch (e) {
      if (gen != _generation) return;
      _loadError = e;
      _status = OrgLoadStatus.error;
    } catch (_) {
      if (gen != _generation) return;
      _loadError = const ApiException(
        ApiErrorKind.unknown,
        'Could not load your organisations.',
      );
      _status = OrgLoadStatus.error;
    }
    notifyListeners();
  }

  void switchToPersonal() {
    if (_activeOrgId == null) return;
    _activeOrgId = null;
    notifyListeners();
  }

  /// Only organisations the backend reported for this user can be activated.
  bool switchToOrganization(String orgId) {
    if (!_memberships.any((m) => m.id == orgId)) return false;
    _activeOrgId = orgId;
    notifyListeners();
    return true;
  }

  /// Creates an organisation (caller becomes admin) and switches to it.
  Future<bool> createOrganization(String name) async {
    if (_busy) return false;
    final gen = _generation;
    _busy = true;
    _actionError = null;
    notifyListeners();

    try {
      final created = await _service.create(name);
      if (gen != _generation) return false;
      _memberships = [
        created,
        ..._memberships.where((m) => m.id != created.id),
      ];
      _activeOrgId = created.id;
      _status = OrgLoadStatus.ready;
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (gen == _generation) _actionError = e;
    } catch (_) {
      if (gen == _generation) {
        _actionError = const ApiException(
          ApiErrorKind.unknown,
          'Could not create the organisation. Please try again.',
        );
      }
    }
    if (gen == _generation) {
      _busy = false;
      notifyListeners();
    }
    return false;
  }

  /// Admin-only on the backend; the UI also hides the control for other roles.
  Future<bool> renameActive(String name) async {
    final current = activeMembership;
    if (current == null || _busy) return false;
    final gen = _generation;
    _busy = true;
    _actionError = null;
    notifyListeners();

    try {
      final updated = await _service.rename(current.id, name);
      if (gen != _generation) return false;
      _memberships = [
        for (final m in _memberships) m.id == updated.id ? updated : m,
      ];
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (gen == _generation) _actionError = e;
    } catch (_) {
      if (gen == _generation) {
        _actionError = const ApiException(
          ApiErrorKind.unknown,
          'Could not rename the organisation. Please try again.',
        );
      }
    }
    if (gen == _generation) {
      _busy = false;
      notifyListeners();
    }
    return false;
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    notifyListeners();
  }

  /// Call on sign-out so the next user never inherits this user's workspaces.
  void reset() {
    _generation++;
    _status = OrgLoadStatus.idle;
    _memberships = const [];
    _activeOrgId = null;
    _loadError = null;
    _actionError = null;
    _busy = false;
    notifyListeners();
  }
}
