import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'paid_provider_proxy_models.dart';

/// Exact upstream origin policy for paid-provider traffic. Callers must still
/// disable redirect following on every request.
class PaidProviderUpstreamPolicy {
  const PaidProviderUpstreamPolicy._();

  static const Map<PaidProviderId, String> _hosts = {
    PaidProviderId.venice: 'api.venice.ai',
    PaidProviderId.blockrun: 'blockrun.ai',
  };

  static Uri validate(Uri uri, {required PaidProviderId provider}) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host != _hosts[provider] ||
        (uri.hasPort && uri.port != HttpClient.defaultHttpsPort)) {
      throw const PaidProviderProxyException(
        'Paid-provider upstream origin is not allowed.',
        code: 'upstream_origin_not_allowed',
      );
    }
    return uri;
  }
}

/// Relays the already-mapped Gateway request to one exact paid-provider route.
/// It never follows redirects and never accepts arbitrary upstream origins or
/// arbitrary credential headers.
class PaidProviderHttpClient {
  PaidProviderHttpClient({
    http.Client? client,
    this.connectTimeout = const Duration(seconds: 20),
    this.firstByteTimeout = const Duration(seconds: 120),
    this.streamingInactivityTimeout = const Duration(minutes: 10),
    this.maxResponseHeaderBytes = 64 * 1024,
    this.maxOrdinaryResponseBytes = 16 * 1024 * 1024,
    this.maxSseLineBytes = 1024 * 1024,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration connectTimeout;
  final Duration firstByteTimeout;
  final Duration streamingInactivityTimeout;
  final int maxResponseHeaderBytes;
  final int maxOrdinaryResponseBytes;
  final int maxSseLineBytes;

  bool _closed = false;

  Future<PaidProviderProxyResponse> send(
    PaidProviderProxyRequest proxyRequest, {
    Map<String, String> upstreamHeaders = const <String, String>{},
    List<int>? exactRequestBodyBytes,
  }) async {
    if (_closed) throw StateError('Paid-provider HTTP client is closed.');
    if (proxyRequest.route.provider != proxyRequest.provider) {
      throw const PaidProviderProxyException(
        'Paid-provider route and request do not match.',
        code: 'provider_route_mismatch',
      );
    }

    final uri = PaidProviderUpstreamPolicy.validate(
      upstreamUriFor(proxyRequest.route),
      provider: proxyRequest.provider,
    );
    final abortTrigger = Completer<void>();
    void abortUpstream() {
      if (!abortTrigger.isCompleted) abortTrigger.complete();
    }

    final request = http.AbortableRequest(
      proxyRequest.route.method,
      uri,
      abortTrigger: abortTrigger.future,
    )
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = true
      ..headers[HttpHeaders.acceptHeader] =
          'application/json, text/event-stream';

    if (proxyRequest.route.method == 'POST') {
      final body = proxyRequest.jsonBody;
      if (body == null) {
        throw const PaidProviderProxyException(
          'Paid-provider POST body is missing.',
          code: 'missing_request_body',
        );
      }
      request.headers[HttpHeaders.contentTypeHeader] =
          ContentType.json.mimeType;
      request.bodyBytes =
          exactRequestBodyBytes ?? proxyRequest.encodedJsonBodyBytes!;
    }
    _applyProviderHeaders(
      request.headers,
      proxyRequest.provider,
      upstreamHeaders,
    );

    late http.StreamedResponse upstream;
    try {
      upstream = await _client.send(request).timeout(connectTimeout);
    } on TimeoutException {
      abortUpstream();
      throw const PaidProviderProxyException(
        'Paid-provider connection timed out.',
        code: 'upstream_connect_timeout',
        statusCode: HttpStatus.gatewayTimeout,
      );
    } on PaidProviderProxyException {
      rethrow;
    } catch (_) {
      throw const PaidProviderProxyException(
        'Paid-provider connection failed.',
        code: 'upstream_connection_failed',
        statusCode: HttpStatus.badGateway,
      );
    }

    if (upstream.isRedirect ||
        (upstream.statusCode >= 300 && upstream.statusCode < 400)) {
      abortUpstream();
      await _cancelStream(upstream.stream);
      throw const PaidProviderProxyException(
        'Paid-provider redirects are not allowed.',
        code: 'upstream_redirect_rejected',
        statusCode: HttpStatus.badGateway,
      );
    }

    if (_headerByteLength(upstream.headers) > maxResponseHeaderBytes) {
      abortUpstream();
      await _cancelStream(upstream.stream);
      throw const PaidProviderProxyException(
        'Paid-provider response headers exceed the proxy limit.',
        code: 'upstream_headers_too_large',
        statusCode: HttpStatus.badGateway,
      );
    }

    final contentType = upstream.headers[HttpHeaders.contentTypeHeader] ?? '';
    final isSse = contentType.toLowerCase().startsWith('text/event-stream');
    if (!isSse &&
        upstream.contentLength != null &&
        upstream.contentLength! > maxOrdinaryResponseBytes) {
      abortUpstream();
      await _cancelStream(upstream.stream);
      throw const PaidProviderProxyException(
        'Paid-provider response exceeds the proxy limit.',
        code: 'upstream_response_too_large',
        statusCode: HttpStatus.badGateway,
      );
    }

    final guarded = await _prefetchAndGuard(
      upstream.stream,
      isSse: isSse,
      abortUpstream: abortUpstream,
    );
    return PaidProviderProxyResponse.stream(
      statusCode: upstream.statusCode,
      headers: _safeResponseHeaders(upstream.headers),
      bodyStream: guarded,
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }

  Uri upstreamUriFor(PaidProviderProxyRoute route) {
    final host = switch (route.provider) {
      PaidProviderId.venice => 'api.venice.ai',
      PaidProviderId.blockrun => 'blockrun.ai',
    };
    final path = switch (route.kind) {
      PaidProviderProxyRouteKind.models => '/api/v1/models',
      PaidProviderProxyRouteKind.chatCompletions => '/api/v1/chat/completions',
      PaidProviderProxyRouteKind.responses => '/api/v1/responses',
    };
    return Uri(scheme: 'https', host: host, path: path);
  }

  void _applyProviderHeaders(
    Map<String, String> target,
    PaidProviderId provider,
    Map<String, String> supplied,
  ) {
    final allowed = switch (provider) {
      PaidProviderId.venice => const {'x-sign-in-with-x'},
      PaidProviderId.blockrun => const {'payment-signature'},
    };
    for (final entry in supplied.entries) {
      final normalized = entry.key.trim().toLowerCase();
      if (!allowed.contains(normalized) || entry.value.isEmpty) {
        throw const PaidProviderProxyException(
          'Paid-provider upstream header is not allowed.',
          code: 'upstream_header_not_allowed',
        );
      }
      target[normalized] = entry.value;
    }
  }

  Future<Stream<List<int>>> _prefetchAndGuard(
    Stream<List<int>> source, {
    required bool isSse,
    required void Function() abortUpstream,
  }) async {
    final guard = _ResponseBodyGuard(
      isSse: isSse,
      maxOrdinaryBytes: maxOrdinaryResponseBytes,
      maxSseLineBytes: maxSseLineBytes,
    );
    final firstSignal = Completer<bool>();
    final pending = <List<int>>[];
    Object? pendingError;
    StackTrace? pendingStackTrace;
    var sourceDone = false;
    var prefetching = true;
    StreamController<List<int>>? output;
    Timer? inactivityTimer;
    StreamSubscription<List<int>>? subscription;

    void armInactivityTimer() {
      inactivityTimer?.cancel();
      inactivityTimer = Timer(streamingInactivityTimeout, () {
        final controller = output;
        if (controller == null || controller.isClosed) return;
        controller.addError(const PaidProviderProxyException(
          'Paid-provider response stream became inactive.',
          code: 'upstream_stream_inactive',
          statusCode: HttpStatus.gatewayTimeout,
        ));
        abortUpstream();
        unawaited(subscription?.cancel());
        unawaited(controller.close());
      });
    }

    subscription = source.listen(
      (chunk) {
        final copied = List<int>.unmodifiable(chunk);
        if (prefetching) {
          pending.add(copied);
          subscription?.pause();
          if (!firstSignal.isCompleted) firstSignal.complete(true);
          return;
        }
        try {
          guard.accept(copied);
          output?.add(copied);
          armInactivityTimer();
        } on Object catch (error, stackTrace) {
          output?.addError(error, stackTrace);
          abortUpstream();
          unawaited(subscription?.cancel());
          unawaited(output?.close());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (prefetching) {
          pendingError = error;
          pendingStackTrace = stackTrace;
          if (!firstSignal.isCompleted) {
            firstSignal.completeError(error, stackTrace);
          }
          return;
        }
        output?.addError(
          const PaidProviderProxyException(
            'Paid-provider response stream failed.',
            code: 'upstream_stream_failed',
            statusCode: HttpStatus.badGateway,
          ),
          stackTrace,
        );
        abortUpstream();
        unawaited(output?.close());
      },
      onDone: () {
        sourceDone = true;
        if (prefetching) {
          if (!firstSignal.isCompleted) firstSignal.complete(false);
          return;
        }
        inactivityTimer?.cancel();
        unawaited(output?.close());
      },
      cancelOnError: false,
    );

    bool hasFirst;
    try {
      hasFirst = await firstSignal.future.timeout(firstByteTimeout);
    } on TimeoutException {
      abortUpstream();
      await subscription.cancel();
      throw const PaidProviderProxyException(
        'Paid-provider first response byte timed out.',
        code: 'upstream_first_byte_timeout',
        statusCode: HttpStatus.gatewayTimeout,
      );
    } catch (_) {
      abortUpstream();
      await subscription.cancel();
      throw const PaidProviderProxyException(
        'Paid-provider response stream failed.',
        code: 'upstream_stream_failed',
        statusCode: HttpStatus.badGateway,
      );
    }
    if (!hasFirst) {
      await subscription.cancel();
      return const Stream<List<int>>.empty();
    }

    try {
      for (final chunk in pending) {
        guard.accept(chunk);
      }
    } on Object {
      abortUpstream();
      await subscription.cancel();
      rethrow;
    }

    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        output = controller;
        prefetching = false;
        for (final chunk in pending) {
          controller.add(chunk);
        }
        pending.clear();
        if (pendingError != null) {
          controller.addError(
            const PaidProviderProxyException(
              'Paid-provider response stream failed.',
              code: 'upstream_stream_failed',
              statusCode: HttpStatus.badGateway,
            ),
            pendingStackTrace,
          );
          abortUpstream();
          unawaited(subscription?.cancel());
          unawaited(controller.close());
        } else if (sourceDone) {
          unawaited(controller.close());
        } else {
          armInactivityTimer();
          subscription?.resume();
        }
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        inactivityTimer?.cancel();
        abortUpstream();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  int _headerByteLength(Map<String, String> headers) {
    var total = 0;
    headers.forEach((name, value) {
      total += utf8.encode(name).length + utf8.encode(value).length + 4;
    });
    return total;
  }

  Map<String, String> _safeResponseHeaders(Map<String, String> upstream) {
    final safe = <String, String>{};
    upstream.forEach((name, value) {
      final normalized = name.toLowerCase();
      if (normalized == HttpHeaders.contentTypeHeader ||
          normalized == 'x-request-id' ||
          normalized == 'request-id' ||
          normalized.startsWith('x-ratelimit-') ||
          normalized.startsWith('ratelimit-') ||
          normalized == 'x-balance-remaining' ||
          normalized == 'payment-required' ||
          normalized == 'x-payment-required' ||
          normalized == 'payment-response' ||
          normalized == 'x-payment-response' ||
          normalized == 'x-payment-receipt') {
        safe[normalized] = value;
      }
    });
    return safe;
  }

  Future<void> _cancelStream(Stream<List<int>> stream) async {
    final subscription = stream.listen((_) {});
    await subscription.cancel();
  }
}

class _ResponseBodyGuard {
  _ResponseBodyGuard({
    required this.isSse,
    required this.maxOrdinaryBytes,
    required this.maxSseLineBytes,
  });

  final bool isSse;
  final int maxOrdinaryBytes;
  final int maxSseLineBytes;

  var _totalBytes = 0;
  var _sseLineBytes = 0;

  void accept(List<int> chunk) {
    if (!isSse) {
      _totalBytes += chunk.length;
      if (_totalBytes > maxOrdinaryBytes) {
        throw const PaidProviderProxyException(
          'Paid-provider response exceeds the proxy limit.',
          code: 'upstream_response_too_large',
          statusCode: HttpStatus.badGateway,
        );
      }
      return;
    }

    for (final byte in chunk) {
      if (byte == 0x0A) {
        _sseLineBytes = 0;
      } else {
        _sseLineBytes++;
        if (_sseLineBytes > maxSseLineBytes) {
          throw const PaidProviderProxyException(
            'Paid-provider SSE line exceeds the proxy limit.',
            code: 'upstream_sse_line_too_large',
            statusCode: HttpStatus.badGateway,
          );
        }
      }
    }
  }
}
