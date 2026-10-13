/// Central place for backend settings.
///
/// Change the URL without editing code by running:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
/// (An Android emulator would use http://10.0.2.2:8000 instead.)
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// The analysis calls GitHub/OSV/registries for every package, so it is slow.
  static const Duration analysisTimeout = Duration(minutes: 3);

  /// Must match MAX_FILE_SIZE in backend/app/api/analysis.py (1 MB).
  static const int maxFileBytes = 1024 * 1024;
}
