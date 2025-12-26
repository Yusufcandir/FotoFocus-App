import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  final int statusCode; // 0 = network/timeout/unknown
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message; // keep SnackBars clean
}

class ApiService {
  ApiService({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage();

  final TokenStorage _tokenStorage;

  /// Builds a request URI from AppConstants.baseUrl + [path].
  /// IMPORTANT: preserves any path prefix in baseUrl (e.g. ".../api").
  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(AppConstants.baseUrl);

    final cleanPath = path.startsWith("/") ? path : "/$path";

    // Preserve baseUrl path prefix if present (e.g. "/api")
    String basePath = base.path;
    if (basePath.isEmpty) basePath = "";
    // remove trailing slash from basePath (except if it's just "/")
    if (basePath.length > 1 && basePath.endsWith("/")) {
      basePath = basePath.substring(0, basePath.length - 1);
    }
    // also normalize if basePath == "/"
    if (basePath == "/") basePath = "";

    final fullPath = "$basePath$cleanPath";

    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: fullPath,
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = <String, String>{
      "Accept": "application/json",
      "Content-Type": "application/json",
    };

    if (auth) {
      final token = await _tokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }
    }
    return headers;
  }

  dynamic _tryDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body; // non-json
    }
  }

  dynamic _handle(http.Response res) {
    final decoded = _tryDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded ?? <String, dynamic>{};
    }

    String message = "Request failed (${res.statusCode})";
    if (decoded is Map) {
      final m = decoded["message"] ?? decoded["error"];
      if (m != null) message = m.toString();
    } else if (decoded is String && decoded.trim().isNotEmpty) {
      message = decoded;
    }

    throw ApiException(res.statusCode, message);
  }

  Future<T> _safe<T>(Future<T> Function() call, {Duration? timeout}) async {
    try {
      if (timeout != null) return await call().timeout(timeout);
      return await call();
    } on SocketException {
      throw ApiException(0, "No internet connection.");
    } on TimeoutException {
      throw ApiException(0, "Request timed out. Please try again.");
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, "Unexpected error. Please try again.");
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final res = await _safe(
      () async => http.get(
        _buildUri(path, query),
        headers: await _headers(auth: auth),
      ),
      timeout: const Duration(seconds: 25),
    );
    return _handle(res);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    final res = await _safe(
      () async => http.post(
        _buildUri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body ?? {}),
      ),
      timeout: const Duration(seconds: 25),
    );
    return _handle(res);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    final res = await _safe(
      () async => http.put(
        _buildUri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body ?? {}),
      ),
      timeout: const Duration(seconds: 25),
    );
    return _handle(res);
  }

  Future<dynamic> delete(
    String path, {
    bool auth = true,
  }) async {
    final res = await _safe(
      () async => http.delete(
        _buildUri(path),
        headers: await _headers(auth: auth),
      ),
      timeout: const Duration(seconds: 25),
    );
    return _handle(res);
  }

  // ---------------- Multipart uploads ----------------

  Future<Map<String, dynamic>> multipartPost(
    String path, {
    required File file,
    String fileField = "image",
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    return multipart(
      path,
      fileField: fileField,
      filePath: file.path,
      fields: fields,
      auth: auth,
      method: "POST",
    );
  }

  Future<Map<String, dynamic>> multipart(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
    bool auth = true,
    String method = "POST",
  }) async {
    final request =
        http.MultipartRequest(method.toUpperCase(), _buildUri(path));

    if (auth) {
      final token = await _tokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers["Authorization"] = "Bearer $token";
      }
    }

    fields?.forEach((k, v) => request.fields[k] = v);
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));

    final streamed = await _safe(
      () => request.send(),
      timeout: const Duration(seconds: 40),
    );

    final response = await http.Response.fromStream(streamed);
    final decoded = _tryDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = "Upload failed (${response.statusCode})";
      if (decoded is Map) {
        final m = decoded["message"] ?? decoded["error"];
        if (m != null) message = m.toString();
      } else if (decoded is String && decoded.trim().isNotEmpty) {
        message = decoded;
      }
      throw ApiException(response.statusCode, message);
    }

    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded == null) return <String, dynamic>{};
    return <String, dynamic>{"data": decoded};
  }
}
