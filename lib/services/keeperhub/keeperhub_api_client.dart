import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'keeperhub_models.dart';

class KeeperHubApiResponse {
  const KeeperHubApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  final int statusCode;
  final Map<String, dynamic> body;
  final Map<String, String> headers;

  String? get requestId =>
      headers['x-request-id'] ?? headers['x-vercel-id'] ?? headers['cf-ray'];

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Fixed-origin KeeperHub client. Session cookies exist only in this instance
/// and are never exposed to the Gateway, model, logs, or persistent storage.
class KeeperHubApiClient {
  KeeperHubApiClient({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  static final Uri baseUri = Uri.parse('https://app.keeperhub.com');
  static const _maxResponseBytes = 256 * 1024;
  static final RegExp _cookieBoundary = RegExp(
    r",(?=\s*[!#$%&'*+.^_`|~0-9A-Za-z-]+=)",
  );
  static final RegExp _cookieName = RegExp(r"^[!#\$%&'*+.^_`|~0-9A-Za-z-]+$");

  final http.Client _client;
  final Duration requestTimeout;
  final Map<String, String> _sessionCookies = <String, String>{};

  Future<KeeperHubApiResponse> requestNonce(String walletAddress) => _send(
        method: 'POST',
        path: '/api/auth/siwe/nonce',
        session: true,
        body: <String, dynamic>{
          'walletAddress': walletAddress,
          'chainId': 1,
        },
      );

  Future<KeeperHubApiResponse> verifySiwe({
    required String message,
    required String signature,
    required String walletAddress,
  }) =>
      _send(
        method: 'POST',
        path: '/api/auth/siwe/verify',
        session: true,
        body: <String, dynamic>{
          'message': message,
          'signature': signature,
          'walletAddress': walletAddress,
          'chainId': 1,
        },
      );

  Future<KeeperHubApiResponse> createOrganizationKey({
    required String name,
    String? signature,
  }) =>
      _send(
        method: 'POST',
        path: '/api/keys',
        session: true,
        body: <String, dynamic>{
          'name': name,
          if (signature != null) 'signature': signature,
        },
      );

  Future<KeeperHubApiResponse> readUser() => _send(
        method: 'GET',
        path: '/api/user',
        session: true,
      );

  Future<KeeperHubApiResponse> validateOrganizationKey(String apiKey) => _send(
        method: 'GET',
        path: '/api/keys',
        apiKey: apiKey,
      );

  Future<KeeperHubApiResponse> revokeOrganizationKey({
    required String apiKey,
    required String keyId,
  }) {
    final normalized = keyId.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{4,160}$').hasMatch(normalized)) {
      throw const KeeperHubException(
        'organization_key_id_invalid',
        'KeeperHub organization key ID is invalid.',
      );
    }
    return _send(
      method: 'DELETE',
      path: '/api/keys/$normalized',
      apiKey: apiKey,
    );
  }

  Future<KeeperHubApiResponse> simulateTransfer({
    required String apiKey,
    required Map<String, dynamic> transfer,
  }) =>
      _send(
        method: 'POST',
        path: '/api/execute/transfer',
        apiKey: apiKey,
        body: <String, dynamic>{...transfer, 'simulate': true},
      );

  Future<KeeperHubApiResponse> executeTransfer({
    required String apiKey,
    required Map<String, dynamic> transfer,
    required String idempotencyKey,
  }) =>
      _send(
        method: 'POST',
        path: '/api/execute/transfer',
        apiKey: apiKey,
        idempotencyKey: idempotencyKey,
        body: transfer,
      );

  Future<KeeperHubApiResponse> executionStatus({
    required String apiKey,
    required String executionId,
  }) {
    final normalized = executionId.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{8,160}$').hasMatch(normalized)) {
      throw const KeeperHubException(
        'execution_id_invalid',
        'KeeperHub execution ID is invalid.',
      );
    }
    return _send(
      method: 'GET',
      path: '/api/execute/$normalized/status',
      apiKey: apiKey,
    );
  }

  Future<KeeperHubApiResponse> _send({
    required String method,
    required String path,
    bool session = false,
    String? apiKey,
    String? idempotencyKey,
    Map<String, dynamic>? body,
  }) async {
    if (!path.startsWith('/api/') || path.contains('://')) {
      throw const KeeperHubException(
        'request_policy_error',
        'KeeperHub request path is not allowlisted.',
      );
    }
    if (session && apiKey != null) {
      throw const KeeperHubException(
        'request_policy_error',
        'A KeeperHub request cannot mix session and API-key authentication.',
      );
    }
    final uri = baseUri.resolve(path);
    if (uri.scheme != 'https' || uri.host != baseUri.host) {
      throw const KeeperHubException(
        'request_policy_error',
        'KeeperHub request origin is invalid.',
      );
    }
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (session) {
      request.headers['Origin'] = baseUri.toString();
      if (_sessionCookies.isNotEmpty) {
        request.headers['Cookie'] = _sessionCookies.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; ');
      }
    }
    if (apiKey != null) request.headers['Authorization'] = 'Bearer $apiKey';
    if (idempotencyKey != null) {
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(idempotencyKey)) {
        throw const KeeperHubException(
          'idempotency_key_invalid',
          'KeeperHub idempotency key is invalid.',
        );
      }
      request.headers['Idempotency-Key'] = idempotencyKey;
    }

    try {
      final streamed = await _client.send(request).timeout(requestTimeout);
      if (streamed.isRedirect ||
          (streamed.statusCode >= 300 && streamed.statusCode < 400)) {
        throw const KeeperHubException(
          'unexpected_redirect',
          'KeeperHub returned an unexpected redirect.',
        );
      }
      if (session) _captureCookies(streamed.headers['set-cookie']);
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in streamed.stream.timeout(requestTimeout)) {
        bytes.add(chunk);
        if (bytes.length > _maxResponseBytes) {
          throw const KeeperHubException(
            'response_too_large',
            'KeeperHub returned an oversized response.',
          );
        }
      }
      final text = utf8.decode(bytes.takeBytes(), allowMalformed: false);
      Map<String, dynamic> decoded = <String, dynamic>{};
      if (text.trim().isNotEmpty) {
        try {
          final value = jsonDecode(text);
          if (value is Map) decoded = Map<String, dynamic>.from(value);
        } on FormatException {
          decoded = <String, dynamic>{'code': 'non_json_response'};
        }
      }
      return KeeperHubApiResponse(
        statusCode: streamed.statusCode,
        body: decoded,
        headers: Map<String, String>.from(streamed.headers),
      );
    } on KeeperHubException {
      rethrow;
    } on TimeoutException {
      throw const KeeperHubException(
        'request_timeout',
        'KeeperHub did not respond before the secure request timed out.',
      );
    } on http.ClientException {
      throw const KeeperHubException(
        'connection_failed',
        'Could not establish a secure connection to KeeperHub.',
      );
    } on FormatException {
      throw const KeeperHubException(
        'response_invalid',
        'KeeperHub returned an invalid encoded response.',
      );
    }
  }

  void _captureCookies(String? header) {
    if (header == null || header.trim().isEmpty) return;
    for (final raw in header.split(_cookieBoundary)) {
      final pair = raw.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1);
      if (!_cookieName.hasMatch(name) || value.contains(RegExp(r'[\r\n;]'))) {
        continue;
      }
      if (value.isEmpty) {
        _sessionCookies.remove(name);
      } else {
        _sessionCookies[name] = value;
      }
    }
  }

  void close() {
    _sessionCookies.clear();
    _client.close();
  }
}
