import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';
import '../models/analysis_result.dart';
import '../services/analysis_service.dart';

enum AnalysisStatus { idle, loading, success, error }

/// One finished analysis, kept for the History page (this session only).
class HistoryEntry {
  HistoryEntry(this.result, this.at);

  final AnalysisResult result;
  final DateTime at;
}

/// Mirrors the backend parser (dependency_parser.parse_dependency_file).
bool isSupportedDependencyFile(String filename) {
  final lower = filename.toLowerCase();
  return lower.endsWith('.yaml') ||
      lower.endsWith('requirements.txt') ||
      lower.endsWith('package.json');
}

class AnalysisProvider extends ChangeNotifier {
  AnalysisProvider(this._service);

  final AnalysisService _service;

  AnalysisStatus _status = AnalysisStatus.idle;
  AnalysisResult? _result;
  ApiException? _error;
  String? _fileName;
  Uint8List? _fileBytes;
  String? _fileError;
  Map<String, dynamic>? _policy; // null = use the backend's default policy
  final List<HistoryEntry> _history = [];

  AnalysisStatus get status => _status;
  bool get isLoading => _status == AnalysisStatus.loading;

  /// Last SUCCESSFUL analysis. Kept even if a later attempt fails.
  AnalysisResult? get result => _result;
  ApiException? get error => _error;

  String? get fileName => _fileName;
  int? get fileSize => _fileBytes?.length;
  String? get fileError => _fileError;
  bool get hasFile => _fileBytes != null;

  /// Custom policy sent with the next analysis (null = backend default).
  Map<String, dynamic>? get policy => _policy;

  /// Analyses run in this session, newest first.
  List<HistoryEntry> get history => List.unmodifiable(_history);

  void setPolicy(Map<String, dynamic>? policy) {
    _policy = policy;
    notifyListeners();
  }

  /// Shows a past analysis from the history list as the current result.
  void openFromHistory(int index) {
    if (index < 0 || index >= _history.length) return;
    _result = _history[index].result;
    _status = AnalysisStatus.success;
    notifyListeners();
  }

  void selectFile(String name, Uint8List bytes) {
    _error = null;
    if (!isSupportedDependencyFile(name)) {
      _rejectFile(
          '"$name" is not supported. Use pubspec.yaml, requirements.txt or package.json.');
    } else if (bytes.isEmpty) {
      _rejectFile('The selected file is empty.');
    } else if (bytes.length > ApiConfig.maxFileBytes) {
      _rejectFile('The file is larger than the 1 MB limit.');
    } else {
      _fileName = name;
      _fileBytes = bytes;
      _fileError = null;
    }
    notifyListeners();
  }

  void rejectFile(String message) {
    _rejectFile(message);
    notifyListeners();
  }

  void _rejectFile(String message) {
    _fileName = null;
    _fileBytes = null;
    _fileError = message;
  }

  void clearFile() {
    _fileName = null;
    _fileBytes = null;
    _fileError = null;
    _error = null;
    notifyListeners();
  }

  /// Returns true when the analysis succeeded.
  Future<bool> analyze() async {
    if (isLoading || _fileBytes == null || _fileName == null) return false;

    _status = AnalysisStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final analysis = await _service.run(
        filename: _fileName!,
        bytes: _fileBytes!,
        policy: _policy,
      );
      _result = analysis;
      _history.insert(0, HistoryEntry(analysis, DateTime.now()));
      if (_history.length > 20) _history.removeLast();
      _status = AnalysisStatus.success;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e;
    } catch (_) {
      _error = const ApiException(
        ApiErrorKind.unknown,
        'An unexpected error occurred. Please try again.',
      );
    }
    _status = AnalysisStatus.error;
    notifyListeners();
    return false;
  }

  /// Runs limited genuine analysis for unauthenticated guests (calls /analysis/guest-run).
  Future<bool> analyzeGuest() async {
    if (isLoading || _fileBytes == null || _fileName == null) return false;

    _status = AnalysisStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final analysis = await _service.runGuest(
        filename: _fileName!,
        bytes: _fileBytes!,
      );
      _result = analysis;
      _status = AnalysisStatus.success;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e;
    } catch (_) {
      _error = const ApiException(
        ApiErrorKind.unknown,
        'An unexpected error occurred during guest analysis. Please try again.',
      );
    }
    _status = AnalysisStatus.error;
    notifyListeners();
    return false;
  }

  /// Call on sign-out so the next user never sees the previous user's data.
  void reset() {
    _status = AnalysisStatus.idle;
    _result = null;
    _error = null;
    _fileName = null;
    _fileBytes = null;
    _fileError = null;
    _policy = null;
    _history.clear();
    notifyListeners();
  }
}
