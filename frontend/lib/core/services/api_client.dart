import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

enum ApiErrorKind {
  notSignedIn,
  sessionExpired,
  invalidRequest,
  forbidden,
  notFound,
  conflict,
  fileTooLarge,
  serverError,
  network,
  timeout,
  malformedResponse,
  unknown,
}

/// Every failure from the backend becomes one of these, so screens can show a
/// friendly message instead of a raw exception.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  String get title {
    switch (kind) {
      case ApiErrorKind.notSignedIn:
      case ApiErrorKind.sessionExpired:
        return 'Authentication required';
      case ApiErrorKind.invalidRequest:
        return 'Could not analyze this file';
      case ApiErrorKind.forbidden:
        return 'Not allowed';
      case ApiErrorKind.notFound:
        return 'Not found';
      case ApiErrorKind.conflict:
        return 'Request conflict';
      case ApiErrorKind.fileTooLarge:
        return 'File too large';
      case ApiErrorKind.serverError:
        return 'Server error';
      case ApiErrorKind.network:
        return 'Backend unavailable';
      case ApiErrorKind.timeout:
        return 'Request timed out';
      case ApiErrorKind.malformedResponse:
        return 'Unexpected response';
      case ApiErrorKind.unknown:
        return 'Something went wrong';
    }
  }

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _http;
  final String _baseUrl;

  /// Sends a multipart upload with the Firebase ID token.
  /// On a 401 it forces a token refresh and retries once.
  Future<Map<String, dynamic>> postMultipart(
      String path, {
        required String fileField,
        required String filename,
        required Uint8List bytes,
        Map<String, String> fields = const {},
        Duration timeout = ApiConfig.analysisTimeout,
        bool requiresAuth = true,
      }) async {
    Future<http.Response> attempt(bool forceRefresh) async {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'))
        ..fields.addAll(fields)
        ..files.add(
            http.MultipartFile.fromBytes(fileField, bytes, filename: filename));
      if (requiresAuth) {
        final token = await _token(forceRefresh);
        request.headers['Authorization'] = 'Bearer $token';
      }
      try {
        return await (() async {
          final streamed = await _http.send(request);
          return http.Response.fromStream(streamed);
        })()
            .timeout(timeout);
      } on TimeoutException {
        throw const ApiException(
          ApiErrorKind.timeout,
          'The analysis took too long. Try a smaller file, or try again.',
        );
      } on http.ClientException {
        throw ApiException(
          ApiErrorKind.network,
          'Could not reach the backend at $_baseUrl. '
              'Make sure the FastAPI server is running.',
        );
      }
    }

    var response = await attempt(false);
    if (requiresAuth && response.statusCode == 401) {
      response = await attempt(true);
    }
    return _decode(response);
  }

  static const Duration _jsonTimeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> getJson(String path,
      {Duration timeout = _jsonTimeout}) =>
      _sendJson('GET', path, timeout: timeout);

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {Duration timeout = _jsonTimeout}) =>
      _sendJson('POST', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body,
      {Duration timeout = _jsonTimeout}) =>
      _sendJson('PATCH', path, body: body, timeout: timeout);

  /// Authenticated JSON request. On a 401 it forces a token refresh and retries once.
  Future<Map<String, dynamic>> _sendJson(
      String method,
      String path, {
        Map<String, dynamic>? body,
        required Duration timeout,
      }) async {
    Future<http.Response> attempt(bool forceRefresh) async {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'));
      request.headers['Authorization'] = 'Bearer ${await _token(forceRefresh)}';
      request.headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      try {
        final streamed = await _http.send(request).timeout(timeout);
        return await http.Response.fromStream(streamed).timeout(timeout);
      } on TimeoutException {
        throw const ApiException(
          ApiErrorKind.timeout,
          'The request took too long. Please try again.',
        );
      } on http.ClientException {
        throw ApiException(
          ApiErrorKind.network,
          'Could not reach the backend at $_baseUrl. '
              'Make sure the FastAPI server is running.',
        );
      }
    }

    var response = await attempt(false);
    if (response.statusCode == 401) {
      response = await attempt(true);
    }
    return _decode(response);
  }

  Future<String> _token(bool forceRefresh) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ApiException(
        ApiErrorKind.notSignedIn,
        'You are not signed in. Please sign in and try again.',
      );
    }
    try {
      final token = await user.getIdToken(forceRefresh);
      if (token == null || token.isEmpty) {
        throw const ApiException(
          ApiErrorKind.sessionExpired,
          'Your session has expired. Please sign in again.',
        );
      }
      return token;
    } on FirebaseAuthException {
      throw const ApiException(
        ApiErrorKind.sessionExpired,
        'Your session has expired. Please sign in again.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response r) {
    final text = utf8.decode(r.bodyBytes, allowMalformed: true);

    if (r.statusCode >= 200 && r.statusCode < 300) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
      throw const ApiException(
        ApiErrorKind.malformedResponse,
        'The server returned a response the app could not read.',
      );
    }

    final detail = _extractDetail(text);
    switch (r.statusCode) {
      case 401:
        throw ApiException(
          ApiErrorKind.sessionExpired,
          'Your session has expired or is invalid. Please sign in again.',
          statusCode: 401,
        );
      case 403:
        throw ApiException(
          ApiErrorKind.forbidden,
          detail ?? 'You do not have permission to do that.',
          statusCode: 403,
        );
      case 404:
        throw ApiException(
          ApiErrorKind.notFound,
          detail ?? 'That item was not found.',
          statusCode: 404,
        );
      case 409:
        throw ApiException(
          ApiErrorKind.conflict,
          detail ?? 'The request conflicts with the current state.',
          statusCode: 409,
        );
      case 413:
        throw ApiException(
          ApiErrorKind.fileTooLarge,
          detail ?? 'The file is too large (limit is 1 MB).',
          statusCode: 413,
        );
      case 400:
      case 422:
        throw ApiException(
          ApiErrorKind.invalidRequest,
          detail ?? 'The server rejected this file.',
          statusCode: r.statusCode,
        );
      default:
        if (r.statusCode >= 500) {
          throw ApiException(
            ApiErrorKind.serverError,
            'The server hit an error (HTTP ${r.statusCode}). Please try again.',
            statusCode: r.statusCode,
          );
        }
        throw ApiException(
          ApiErrorKind.unknown,
          detail ?? 'Unexpected response (HTTP ${r.statusCode}).',
          statusCode: r.statusCode,
        );
    }
  }

  /// FastAPI errors look like {"detail": "text"} or {"detail": [{"msg": ...}]}.
  String? _extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        final d = decoded['detail'];
        if (d is String) return d;
        if (d is List) {
          return d
              .map((e) => e is Map && e['msg'] != null ? '${e['msg']}' : '$e')
              .join('; ');
        }
      }
    } catch (_) {}
    return null;
  }
}
