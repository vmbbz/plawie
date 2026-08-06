import 'dart:convert';
import 'dart:io';

enum PaidProviderId {
  venice('venice'),
  blockrun('blockrun');

  const PaidProviderId(this.wireName);

  final String wireName;
}

class PaidProviderProxyException implements Exception {
  const PaidProviderProxyException(
    this.message, {
    this.code = 'paid_provider_proxy_error',
    this.statusCode = HttpStatus.badRequest,
  });

  final String message;
  final String code;
  final int statusCode;

  @override
  String toString() => 'PaidProviderProxyException($code): $message';
}

class PaidProviderProxyRoute {
  const PaidProviderProxyRoute._({
    required this.provider,
    required this.method,
    required this.path,
    required this.kind,
    this.enabled = true,
  });

  static const veniceModels = PaidProviderProxyRoute._(
    provider: PaidProviderId.venice,
    method: 'GET',
    path: '/venice/v1/models',
    kind: PaidProviderProxyRouteKind.models,
  );
  static const veniceChatCompletions = PaidProviderProxyRoute._(
    provider: PaidProviderId.venice,
    method: 'POST',
    path: '/venice/v1/chat/completions',
    kind: PaidProviderProxyRouteKind.chatCompletions,
  );
  static const veniceResponses = PaidProviderProxyRoute._(
    provider: PaidProviderId.venice,
    method: 'POST',
    path: '/venice/v1/responses',
    kind: PaidProviderProxyRouteKind.responses,
    enabled: false,
  );
  static const blockrunModels = PaidProviderProxyRoute._(
    provider: PaidProviderId.blockrun,
    method: 'GET',
    path: '/blockrun/v1/models',
    kind: PaidProviderProxyRouteKind.models,
  );
  static const blockrunChatCompletions = PaidProviderProxyRoute._(
    provider: PaidProviderId.blockrun,
    method: 'POST',
    path: '/blockrun/v1/chat/completions',
    kind: PaidProviderProxyRouteKind.chatCompletions,
  );
  static const blockrunResponses = PaidProviderProxyRoute._(
    provider: PaidProviderId.blockrun,
    method: 'POST',
    path: '/blockrun/v1/responses',
    kind: PaidProviderProxyRouteKind.responses,
    enabled: false,
  );

  static const all = <PaidProviderProxyRoute>[
    veniceModels,
    veniceChatCompletions,
    veniceResponses,
    blockrunModels,
    blockrunChatCompletions,
    blockrunResponses,
  ];

  final PaidProviderId provider;
  final String method;
  final String path;
  final PaidProviderProxyRouteKind kind;
  final bool enabled;

  static PaidProviderProxyRoute? match(String method, String path) {
    for (final route in all) {
      if (route.method == method && route.path == path) return route;
    }
    return null;
  }

  static List<PaidProviderProxyRoute> matchingPath(String path) =>
      all.where((route) => route.path == path).toList(growable: false);
}

enum PaidProviderProxyRouteKind {
  models,
  chatCompletions,
  responses,
}

class PaidProviderProxyRequest {
  const PaidProviderProxyRequest({
    required this.provider,
    required this.route,
    this.gatewayModelId,
    this.exactJsonBodyBytes,
    this.jsonBody,
  });

  final PaidProviderId provider;
  final PaidProviderProxyRoute route;

  /// Original namespaced model selected in OpenClaw. This is retained only as
  /// process-local authorization metadata; it is never sent upstream.
  final String? gatewayModelId;

  /// Canonical mapped request bytes generated once at the loopback boundary.
  /// Paid retries reuse this exact immutable sequence.
  final List<int>? exactJsonBodyBytes;
  final Map<String, dynamic>? jsonBody;

  List<int>? get encodedJsonBodyBytes {
    final exact = exactJsonBodyBytes;
    if (exact != null) return exact;
    final body = jsonBody;
    return body == null ? null : utf8.encode(jsonEncode(body));
  }
}

class PaidProviderProxyResponse {
  const PaidProviderProxyResponse({
    required this.statusCode,
    this.bodyBytes,
    this.bodyStream,
    this.headers = const <String, String>{},
  }) : assert(
          (bodyBytes == null) != (bodyStream == null),
          'Provide exactly one response body source.',
        );

  factory PaidProviderProxyResponse.json({
    int statusCode = HttpStatus.ok,
    required Map<String, dynamic> body,
    Map<String, String> headers = const <String, String>{},
  }) {
    return PaidProviderProxyResponse(
      statusCode: statusCode,
      bodyBytes: utf8.encode(jsonEncode(body)),
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
        ...headers,
      },
    );
  }

  factory PaidProviderProxyResponse.stream({
    required int statusCode,
    required Stream<List<int>> bodyStream,
    Map<String, String> headers = const <String, String>{},
  }) {
    return PaidProviderProxyResponse(
      statusCode: statusCode,
      bodyStream: bodyStream,
      headers: headers,
    );
  }

  final int statusCode;
  final List<int>? bodyBytes;
  final Stream<List<int>>? bodyStream;
  final Map<String, String> headers;

  Stream<List<int>> openBodyStream() {
    final stream = bodyStream;
    if (stream != null) return stream;
    return Stream<List<int>>.value(bodyBytes!);
  }
}

typedef PaidProviderProxyHandler = Future<PaidProviderProxyResponse> Function(
  PaidProviderProxyRequest request,
);

class PaidProviderRequestMapper {
  const PaidProviderRequestMapper._();

  static Map<String, dynamic> mapChatRequest(
    Map<String, dynamic> request, {
    required PaidProviderId provider,
  }) {
    final model = request['model'];
    final prefix = '${provider.wireName}/';
    if (model is! String ||
        !model.startsWith(prefix) ||
        model.length == prefix.length) {
      throw PaidProviderProxyException(
        'Expected a non-empty ${provider.wireName}/ model identifier.',
        code: 'invalid_provider_model',
      );
    }

    final copied = jsonDecode(jsonEncode(request));
    if (copied is! Map<String, dynamic>) {
      throw const PaidProviderProxyException(
        'Expected a JSON object.',
        code: 'invalid_request',
      );
    }
    copied['model'] = model.substring(prefix.length);
    return copied;
  }
}
