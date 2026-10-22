import 'package:flutter/foundation.dart';

import '../../../core/services/api_client.dart';
import '../models/project.dart';
import '../services/project_service.dart';

enum ProjectLoadStatus { idle, loading, ready, error }

/// Projects of ONE organisation at a time (the one currently open).
/// Permissions are enforced by the backend; screens only hide controls.
class ProjectProvider extends ChangeNotifier {
  ProjectProvider(this._service);

  final ProjectService _service;

  String? _orgId;
  List<Project> _projects = const [];
  ProjectLoadStatus _status = ProjectLoadStatus.idle;
  ApiException? _loadError;
  ApiException? _actionError;
  bool _busy = false;
  int _request = 0; // latest load wins
  int _epoch = 0; // bumped on reset() (sign-out)

  /// Which organisation `projects` belongs to.
  String? get orgId => _orgId;
  List<Project> get projects => _projects;
  ProjectLoadStatus get status => _status;
  bool get isLoading => _status == ProjectLoadStatus.loading;
  bool get isBusy => _busy;
  ApiException? get loadError => _loadError;
  ApiException? get actionError => _actionError;

  Future<void> load(String orgId) async {
    final token = ++_request;
    if (_orgId != orgId) {
      _orgId = orgId;
      _projects = const [];
    }
    _status = ProjectLoadStatus.loading;
    _loadError = null;
    notifyListeners();

    try {
      final result = await _service.list(orgId);
      if (token != _request) return;
      _projects = result;
      _status = ProjectLoadStatus.ready;
    } on ApiException catch (e) {
      if (token != _request) return;
      _loadError = e;
      _status = ProjectLoadStatus.error;
    } catch (_) {
      if (token != _request) return;
      _loadError = const ApiException(
        ApiErrorKind.unknown,
        'Could not load projects.',
      );
      _status = ProjectLoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> createProject({
    required String orgId,
    required String name,
    required ProjectEcosystem ecosystem,
    String? repoUrl,
  }) async {
    if (_busy) return false;
    final epoch = _epoch;
    _busy = true;
    _actionError = null;
    notifyListeners();

    try {
      final created = await _service.create(
        orgId,
        name: name,
        ecosystem: ecosystem,
        repoUrl: repoUrl,
      );
      if (epoch != _epoch) return false;
      if (_orgId == orgId) {
        _projects = [created, ..._projects.where((p) => p.id != created.id)];
      }
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (epoch == _epoch) _actionError = e;
    } catch (_) {
      if (epoch == _epoch) {
        _actionError = const ApiException(
          ApiErrorKind.unknown,
          'Could not create the project. Please try again.',
        );
      }
    }
    if (epoch == _epoch) {
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

  /// Call on sign-out.
  void reset() {
    _epoch++;
    _request++;
    _orgId = null;
    _projects = const [];
    _status = ProjectLoadStatus.idle;
    _loadError = null;
    _actionError = null;
    _busy = false;
    notifyListeners();
  }
}