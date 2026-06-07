import 'dart:async';

import 'package:http/http.dart' as http;

import '../../models/node_frame.dart';
import 'capability_handler.dart';

class XurlCapability extends CapabilityHandler {
  XurlCapability({http.Client? client}) : _client = client ?? http.Client();

  static const int _maxPreviewChars = 4096;
  final http.Client _client;

  @override
  String get name => 'xurl';

  @override
  List<String> get commands => const ['request'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    if (canonical != 'xurl.request') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown xurl command: $command',
      });
    }

    final uri = _uriFromParams(params);
    if (uri == null) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_URL',
        'message': 'xurl.request requires an absolute http or https URL.',
      });
    }

    final method = _method(params['method']);
    if (method == null) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_METHOD',
        'message': 'xurl.request supports GET, HEAD, and POST.',
      });
    }
    if (method == 'POST' && isLoopbackHostForPolicy(uri.host)) {
      return NodeFrame.response('', error: {
        'code': 'LOCAL_POST_BLOCKED',
        'message':
            'xurl.request does not allow POST requests to local app control endpoints.',
      });
    }

    try {
      final startedAt = DateTime.now();
      final headers = _headers(params['headers']);
      final body = params['body']?.toString();
      final response = await _send(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      final contentType = response.headers['content-type'];
      final preview = _bodyPreview(response.body);

      return NodeFrame.response('', payload: {
        'runtime': 'app-native-http',
        'method': method,
        'url': uri.toString(),
        'statusCode': response.statusCode,
        'reasonPhrase': response.reasonPhrase,
        'contentType': contentType,
        'bytes': response.bodyBytes.length,
        'bodyPreview': preview,
        'elapsedMs': elapsedMs,
        if (response.headers.isNotEmpty)
          'headers': _safeHeaderSubset(response.headers),
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'XURL_TIMEOUT',
        'message': 'xurl.request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'XURL_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<http.Response> _send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String? body,
  }) {
    return switch (method) {
      'HEAD' => _client.head(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: body ?? ''),
      _ => _client.get(uri, headers: headers),
    };
  }

  static String _canonicalCommand(String command) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '.');
    return switch (normalized) {
      'xurl' || 'request' || 'xurl.request' => 'xurl.request',
      _ => normalized,
    };
  }

  static Uri? _uriFromParams(Map<String, dynamic> params) {
    final raw =
        (params['url'] ?? params['uri'] ?? params['target'])?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    return uri;
  }

  static String? _method(dynamic value) {
    final method = value?.toString().trim().toUpperCase();
    return switch (method == null || method.isEmpty ? 'GET' : method) {
      'GET' => 'GET',
      'HEAD' => 'HEAD',
      'POST' => 'POST',
      _ => null,
    };
  }

  static bool isLoopbackHostForPolicy(String host) {
    final normalized =
        host.trim().toLowerCase().replaceAll('[', '').replaceAll(']', '');
    if (normalized == 'localhost' ||
        normalized == '::1' ||
        normalized == '0:0:0:0:0:0:0:1') {
      return true;
    }
    if (normalized.startsWith('::ffff:')) {
      return isLoopbackHostForPolicy(normalized.substring('::ffff:'.length));
    }
    if (normalized.startsWith('0:0:0:0:0:ffff:')) {
      return isLoopbackHostForPolicy(
        normalized.substring('0:0:0:0:0:ffff:'.length),
      );
    }
    return _isIpv4Loopback(normalized);
  }

  static bool _isIpv4Loopback(String host) {
    final address = _legacyIpv4Address(host);
    if (address == null) return false;
    return ((address >> 24) & 0xff) == 127;
  }

  static int? _legacyIpv4Address(String host) {
    final parts = host.split('.');
    if (parts.isEmpty || parts.length > 4) return null;
    final values = <int>[];
    for (final part in parts) {
      final value = _legacyIpv4Part(part);
      if (value == null) return null;
      values.add(value);
    }
    return switch (values.length) {
      1 when values[0] <= 0xffffffff => values[0],
      2 when values[0] <= 0xff && values[1] <= 0xffffff =>
        (values[0] << 24) | values[1],
      3 when values[0] <= 0xff && values[1] <= 0xff && values[2] <= 0xffff =>
        (values[0] << 24) | (values[1] << 16) | values[2],
      4 when values.every((value) => value <= 0xff) =>
        (values[0] << 24) | (values[1] << 16) | (values[2] << 8) | values[3],
      _ => null,
    };
  }

  static int? _legacyIpv4Part(String part) {
    if (part.isEmpty) return null;
    if (part.startsWith('+') || part.startsWith('-')) return null;
    if (part.startsWith('0x') || part.startsWith('0X')) {
      final value = part.substring(2);
      if (value.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
        return null;
      }
      return int.tryParse(value, radix: 16);
    }
    if (part.length > 1 && part.startsWith('0')) {
      final value = part.substring(1);
      if (value.isEmpty) return 0;
      if (!RegExp(r'^[0-7]+$').hasMatch(value)) return null;
      return int.tryParse(value, radix: 8);
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(part)) return null;
    return int.tryParse(part);
  }

  static Map<String, String> _headers(dynamic value) {
    final headers = <String, String>{'Accept': '*/*'};
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().trim();
        final headerValue = entry.value?.toString().trim();
        if (key.isNotEmpty && headerValue != null && headerValue.isNotEmpty) {
          headers[key] = headerValue;
        }
      }
    }
    return headers;
  }

  static String _bodyPreview(String body) {
    if (body.length <= _maxPreviewChars) return body;
    return body.substring(0, _maxPreviewChars);
  }

  static Map<String, String> _safeHeaderSubset(Map<String, String> headers) {
    const allowed = {
      'content-type',
      'content-length',
      'etag',
      'last-modified',
      'location',
      'server',
    };
    return {
      for (final entry in headers.entries)
        if (allowed.contains(entry.key.toLowerCase())) entry.key: entry.value,
    };
  }
}
