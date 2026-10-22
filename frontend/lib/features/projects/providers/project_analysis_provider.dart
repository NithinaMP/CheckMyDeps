import 'package:flutter/foundation.dart';

import '../../../core/services/api_client.dart';
import '../../dependency_analysis/providers/analysis_provider.dart'
    show isSupportedDependencyFile;
import '../models/project.dart';
import '../models/project_analysis.dart';
import '../services/project_analysis_service.dart';

/// State for the project currently open on the detail screen:
/// analysis history, the opened result, and the file waiting to be analysed.
class ProjectAnalysisProvider extends ChangeNotifier {
  ProjectAnalysisProvider(this._service);

  static const int maxFileBytes = 1024 * 1024; // same limit as the backend

  final ProjectAnalysisService _service;

  String? _orgId;
  String? _projectId;

  List<AnalysisHistoryItem> _history = const [];
  bool _historyLoading = false;
  ApiException? _historyError;

  StoredAnalysis? _selected;
  bool _opening = false;
  ApiException? _openError;

  String? _fileName;
  Uint8List? _fileBytes;
  String? _fileError;

  bool _running = false;
  ApiException? _runError;

  int _epoch = 0; // bumped when another project is opened, and on reset()
  int _historyRequest = 0;
  int _openRequest = 0;

  String? get orgId => _orgId;
  String? get projectId => _projectId;
  List<AnalysisHistoryItem> get history => _history;
  bool get historyLoading => _historyLoading;
  ApiException? get historyError => _historyError;
  StoredAnalysis? get selected => _selected;
  bool get isOpening => _opening;
  ApiException? get openError => _openError;
  String? get fileName => _fileName;
  String? get fileError => _fileError;
  bool get hasFile => _fileName != null && _fileBytes != null;
  int get fileSize => _fileBytes?.length ?? 0;
  bool get isRunning => _running;
  ApiException? get runError => _runError;

  void _clearProjectState() {
    _epoch++;
    _historyRequest++;
    _openRequest++;
    _history = const [];
    _historyLoading = false;
    _historyError = null;
    _selected = null;
    _opening = false;
    _openError = null;
    _fileName = null;
    _fileBytes = null;
    _fileError = null;
    _running = false;
    _runError = null;
  }

  /// Opens a project: loads its history and shows its newest analysis.
  Future<void> open(String orgId, String projectId) async {
    if (_orgId != orgId || _projectId != projectId) {
      _clearProjectState();
      _orgId = orgId;
      _projectId = projectId;
    }
    final epoch = _epoch;
    final request = ++_historyRequest;
    _historyLoading = true;
    _historyError = null;
    notifyListeners();

    List<AnalysisHistoryItem> items;
    try {
      items = await _service.history(orgId, projectId);
    } on ApiException catch (e) {
      _failHistory(e, epoch, request);
      return;
    } catch (_) {
      _failHistory(
        const ApiException(
            ApiErrorKind.unknown, 'Could not load analysis history.'),
        epoch,
        request,
      );
      return;
    }
    if (epoch != _epoch || request != _historyRequest) return;
    _history = items;
    _historyLoading = false;
    notifyListeners();

    if (_selected == null && items.isNotEmpty) {
      await openAnalysis(items.first.id);
    }
  }

  void _failHistory(ApiException e, int epoch, int request) {
    if (epoch != _epoch || request != _historyRequest) return;
    _historyError = e;
    _historyLoading = false;
    notifyListeners();
  }

  /// Loads one stored analysis (full result) and makes it the selected one.
  Future<void> openAnalysis(String analysisId) async {
    final orgId = _orgId;
    final projectId = _projectId;
    if (orgId == null || projectId == null) return;
    final epoch = _epoch;
    final request = ++_openRequest;
    _opening = true;
    _openError = null;
    notifyListeners();

    StoredAnalysis stored;
    try {
      stored = await _service.get(orgId, projectId, analysisId);
    } on ApiException catch (e) {
      _failOpen(e, epoch, request);
      return;
    } catch (_) {
      _failOpen(
        const ApiException(
            ApiErrorKind.unknown, 'Could not open this analysis.'),
        epoch,
        request,
      );
      return;
    }
    if (epoch != _epoch || request != _openRequest) return;
    _selected = stored;
    _opening = false;
    notifyListeners();
  }

  void _failOpen(ApiException e, int epoch, int request) {
    if (epoch != _epoch || request != _openRequest) return;
    _openError = e;
    _opening = false;
    notifyListeners();
  }

  // ── File selection ──────────────────────────────────────────────────────

  void rejectFile(String message) {
    _fileName = null;
    _fileBytes = null;
    _fileError = message;
    notifyListeners();
  }

  void selectFile(String name, Uint8List bytes, ProjectEcosystem ecosystem) {
    if (!isSupportedDependencyFile(name)) {
      rejectFile(
          '"$name" is not supported. Use pubspec.yaml, requirements.txt or package.json.');
      return;
    }
    if (!ecosystem.acceptsFile(name)) {
      rejectFile(
          'This project tracks ${ecosystem.label} dependencies. Upload ${ecosystem.fileName}.');
      return;
    }
    if (bytes.isEmpty) {
      rejectFile('The selected file is empty.');
      return;
    }
    if (bytes.length > maxFileBytes) {
      rejectFile('File is too large (limit is 1 MB).');
      return;
    }
    _fileName = name;
    _fileBytes = bytes;
    _fileError = null;
    _runError = null;
    notifyListeners();
  }

  // ── Run ────────────────────────────────────────────────────────────────

  /// Sends the selected file through the backend pipeline. The result is stored
  /// server-side; on success it becomes the selected result and the newest
  /// history row.
  Future<bool> run() async {
    final orgId = _orgId;
    final projectId = _projectId;
    final name = _fileName;
    final bytes = _fileBytes;
    if (_running ||
        orgId == null ||
        projectId == null ||
        name == null ||
        bytes == null) {
      return false;
    }
    final epoch = _epoch;
    _running = true;
    _runError = null;
    notifyListeners();

    StoredAnalysis stored;
    try {
      stored = await _service.run(orgId, projectId, filename: name, bytes: bytes);
    } on ApiException catch (e) {
      _failRun(e, epoch);
      return false;
    } catch (_) {
      _failRun(
        const ApiException(ApiErrorKind.unknown,
            'The analysis could not be completed. Please try again.'),
        epoch,
      );
      return false;
    }
    if (epoch != _epoch) return false;

    _openRequest++; // a slower "open" must not replace this fresh result
    _selected = stored;
    _opening = false;
    _openError = null;
    _history = [
      stored.toHistoryItem(),
      ..._history.where((h) => h.id != stored.id),
    ];
    _fileName = null;
    _fileBytes = null;
    _fileError = null;
    _running = false;
    notifyListeners();
    return true;
  }

  void _failRun(ApiException e, int epoch) {
    if (epoch != _epoch) return;
    _runError = e;
    _running = false;
    notifyListeners();
  }

  /// Call on sign-out.
  void reset() {
    _clearProjectState();
    _orgId = null;
    _projectId = null;
    notifyListeners();
  }
}