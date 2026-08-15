import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const bridgeProviderHosts = <String>{'li.quest', 'api.relay.link'};

abstract interface class BridgeHttpTransport {
  Future<BridgeHttpResponse> getJson(
    Uri uri, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  });

  Future<BridgeHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  });
}

final class BridgeHttpResponse {
  const BridgeHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.json,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? json;
}

final class BridgeHttpException implements Exception {
  const BridgeHttpException(this.code, [this.statusCode]);

  final String code;
  final int? statusCode;

  @override
  String toString() => 'BridgeHttpException: $code';
}

final class BridgeHttpClient implements BridgeHttpTransport {
  BridgeHttpClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  @override
  Future<BridgeHttpResponse> getJson(
    Uri uri, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) =>
      _send('GET', uri, null, maxBytes, headers);

  @override
  Future<BridgeHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) =>
      _send('POST', uri, body, maxBytes, headers);

  Future<BridgeHttpResponse> _send(
    String method,
    Uri uri,
    Map<String, Object?>? body,
    int maxBytes,
    Map<String, String> extraHeaders,
  ) async {
    _validateUri(uri);
    if (maxBytes < 1 || maxBytes > 1024 * 1024) {
      throw const BridgeHttpException('invalid_response_limit');
    }
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false
      ..headers['Accept'] = 'application/json';
    for (final entry in extraHeaders.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'authorization' ||
          key == 'cookie' ||
          key == 'proxy-authorization') {
        throw const BridgeHttpException('credential_header_rejected');
      }
      request.headers[entry.key] = entry.value;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await _client.send(request).timeout(timeout);
      if (streamed.isRedirect ||
          (streamed.statusCode >= 300 && streamed.statusCode < 400)) {
        throw BridgeHttpException('redirect_rejected', streamed.statusCode);
      }
      final declaredLength = streamed.contentLength;
      if (declaredLength != null && declaredLength > maxBytes) {
        throw const BridgeHttpException('response_too_large');
      }
      final bytes = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in streamed.stream.timeout(timeout)) {
        total += chunk.length;
        if (total > maxBytes) {
          throw const BridgeHttpException('response_too_large');
        }
        bytes.add(chunk);
      }
      final responseHeaders = <String, String>{
        for (final entry in streamed.headers.entries)
          entry.key.toLowerCase(): entry.value,
      };
      final contentType = responseHeaders['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('application/json') &&
          !contentType.contains('+json')) {
        throw BridgeHttpException('invalid_content_type', streamed.statusCode);
      }
      final bodyBytes = bytes.takeBytes();
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bodyBytes));
      } on FormatException {
        throw BridgeHttpException('invalid_json', streamed.statusCode);
      }
      return BridgeHttpResponse(
        statusCode: streamed.statusCode,
        headers: Map<String, String>.unmodifiable(responseHeaders),
        json: decoded,
      );
    } on BridgeHttpException {
      rethrow;
    } on TimeoutException {
      throw const BridgeHttpException('timeout');
    } catch (_) {
      throw const BridgeHttpException('transport_failed');
    }
  }

  void _validateUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https' ||
        !bridgeProviderHosts.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      throw const BridgeHttpException('host_not_allowed');
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
