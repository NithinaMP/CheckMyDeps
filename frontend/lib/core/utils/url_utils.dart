import 'package:url_launcher/url_launcher.dart';

/// Returns a Uri only for real http/https links; otherwise null.
Uri? safeWebUri(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final ok = (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.contains('.');
  return ok ? uri : null;
}

Future<void> openExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
