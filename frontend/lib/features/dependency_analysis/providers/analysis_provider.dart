import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';
import '../models/analysis_result.dart';
import '../services/analysis_service.dart';

enum AnalysisStatus { idle, loading, success, error }

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

  AnalysisStatus get status => _status;
  bool get isLoading => _status == AnalysisStatus.loading;

  /// Last SUCCESSFUL analysis. Kept even if a later attempt fails.
  AnalysisResult? get result => _result;
  ApiException? get error => _error;

  String? get fileName => _fileName;
  int? get fileSize => _fileBytes?.length;
  String? get fileError => _fileError;
  bool get hasFile => _fileBytes != null;

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
      _result = await _service.run(filename: _fileName!, bytes: _fileBytes!);
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

  /// Call on sign-out so the next user never sees the previous user's data.
  void reset() {
    _status = AnalysisStatus.idle;
    _result = null;
    _error = null;
    _fileName = null;
    _fileBytes = null;
    _fileError = null;
    notifyListeners();
  }
}
