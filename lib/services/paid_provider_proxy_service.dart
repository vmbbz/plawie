import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'paid_provider_loopback_credential_service.dart';
import 'paid_provider_http_client.dart';
import 'paid_provider_proxy_models.dart';
import 'paid_provider_turn_authorization_service.dart';
import 'provider_balance_service.dart';
import 'venice_wallet_auth_service.dart';

class PaidProviderProxyService {
  PaidProviderProxyService({
    required PaidProviderLoopbackCredentialService credentialService,
    required PaidProviderProxyHandler handler,
    InternetAddress? bindAddress,
    this.port = 11436,
    this.maxRequestBodyBytes = 4 * 1024 * 1024,
    Set<PaidProviderId> Function()? readyProviders,
  })  : _credentialService = credentialService,
        _handler = handler,
        _bindAddress = bindAddress ?? InternetAddress.loopbackIPv4,
        _readyProviders = readyProviders ?? _noReadyProviders;

  final PaidProviderLoopbackCredentialService _credentialService;
  final PaidProviderProxyHandler _handler;
  final Set<PaidProviderId> Function() _readyProviders;
  final InternetAddress _bindAddress;
  final int port;
  final int maxRequestBodyBytes;

  HttpServer? _server;
  Future<Uri>? _startFuture;

  bool get isRunning => _server != null;

  Uri get uri {
    final server = _server;
    if (server == null) throw StateError('Paid-provider proxy is not running.');
    return Uri.parse('http://${server.address.address}:${server.port}/');
  }

  Future<Uri> start() {
    if (_server != null) return Future<Uri>.value(uri);
    return _startFuture ??= _start();
  }

  Future<Uri> _start() async {
    if (_bindAddress.type != InternetAddressType.IPv4 ||
        _bindAddress.address != InternetAddress.loopbackIPv4.address) {
      _startFuture = null;
      throw StateError('Paid-provider proxy must bind to IPv4 loopback only.');
    }
    if (maxRequestBodyBytes <= 0) {
      _startFuture = null;
      throw StateError('Paid-provider proxy body limit must be positive.');
    }

    try {
      final server = await HttpServer.bind(
        _bindAddress,
        port,
        shared: false,
      );
      _server = server;
      server.listen(
        _handleRequest,
        onError: (_) {},
        cancelOnError: false,
      );
      return uri;
    } catch (_) {
      _server = null;
      _startFuture = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _startFuture = null;
    await server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (!_credentialService.matchesAuthorizationHeader(
        request.headers.value(HttpHeaders.authorizationHeader),
      )) {
        await _writeError(
          request.response,
          HttpStatus.unauthorized,
          'unauthorized',
          'A valid local gateway capability is required.',
        );
        return;
      }

      final path = request.uri.path;
      if (request.method == 'GET' && path == '/health') {
        final readyProviders = _readyProviders();
        await _writeResponse(
          request.response,
          PaidProviderProxyResponse.json(
            body: {
              'status': 'ok',
              'scope': 'paid_provider_proxy',
              'readyProviders': [
                for (final provider in PaidProviderId.values)
                  if (readyProviders.contains(provider)) provider.wireName,
              ],
              'providers': {
                for (final provider in PaidProviderId.values)
                  provider.wireName: {
                    'ready': readyProviders.contains(provider),
                    'errorCode': readyProviders.contains(provider)
                        ? null
                        : 'provider_not_ready',
                  },
              },
            },
          ),
        );
        return;
      }

      final route = PaidProviderProxyRoute.match(request.method, path);
      if (route == null) {
        final pathMatches = PaidProviderProxyRoute.matchingPath(path);
        if (pathMatches.isNotEmpty) {
          request.response.headers.set(
            HttpHeaders.allowHeader,
            pathMatches.map((candidate) => candidate.method).toSet().join(', '),
          );
          await _writeError(
            request.response,
            HttpStatus.methodNotAllowed,
            'method_not_allowed',
            'HTTP method is not allowed for this route.',
          );
        } else {
          await _writeError(
            request.response,
            HttpStatus.notFound,
            'route_not_found',
            'Route not found.',
          );
        }
        return;
      }

      if (!route.enabled) {
        await _writeError(
          request.response,
          HttpStatus.notImplemented,
          'route_not_enabled',
          'This paid-provider route is not enabled.',
        );
        return;
      }

      Map<String, dynamic>? jsonBody;
      String? gatewayModelId;
      if (route.method == 'POST') {
        jsonBody = await _readJsonObject(request);
        if (route.kind == PaidProviderProxyRouteKind.chatCompletions) {
          gatewayModelId = jsonBody['model']?.toString();
          jsonBody = PaidProviderRequestMapper.mapChatRequest(
            jsonBody,
            provider: route.provider,
          );
        }
      }

      final response = await _handler(PaidProviderProxyRequest(
        provider: route.provider,
        route: route,
        gatewayModelId: gatewayModelId,
        exactJsonBodyBytes: jsonBody == null
            ? null
            : List<int>.unmodifiable(utf8.encode(jsonEncode(jsonBody))),
        jsonBody: jsonBody,
      ));
      await _writeResponse(request.response, response);
    } on _RequestBodyTooLargeException {
      await _safeWriteError(
        request.response,
        HttpStatus.requestEntityTooLarge,
        'request_too_large',
        'Request body exceeds the local proxy limit.',
      );
    } on PaidProviderProxyException catch (error) {
      await _safeWriteError(
        request.response,
        error.statusCode,
        error.code,
        error.message,
      );
    } on FormatException {
      await _safeWriteError(
        request.response,
        HttpStatus.badRequest,
        'invalid_json',
        'Expected a valid JSON object.',
      );
    } catch (_) {
      await _safeWriteError(
        request.response,
        HttpStatus.internalServerError,
        'proxy_error',
        'Paid-provider proxy request failed.',
      );
    }
  }

  Future<Map<String, dynamic>> _readJsonObject(HttpRequest request) async {
    final contentLength = request.contentLength;
    if (contentLength > maxRequestBodyBytes) {
      throw const _RequestBodyTooLargeException();
    }
    final contentType = request.headers.contentType;
    if (contentType == null ||
        contentType.mimeType != ContentType.json.mimeType) {
      throw const PaidProviderProxyException(
        'Expected application/json.',
        code: 'invalid_content_type',
        statusCode: HttpStatus.unsupportedMediaType,
      );
    }

    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in request) {
      length += chunk.length;
      if (length > maxRequestBodyBytes) {
        throw const _RequestBodyTooLargeException();
      }
      builder.add(chunk);
    }
    final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
    if (decoded is! Map<String, dynamic>) {
      throw const PaidProviderProxyException(
        'Expected a JSON object.',
        code: 'invalid_request',
      );
    }
    return decoded;
  }

  Future<void> _writeError(
    HttpResponse response,
    int statusCode,
    String code,
    String message,
  ) {
    return _writeResponse(
      response,
      PaidProviderProxyResponse.json(
        statusCode: statusCode,
        body: {
          'error': {'code': code, 'message': message},
        },
      ),
    );
  }

  Future<void> _safeWriteError(
    HttpResponse response,
    int statusCode,
    String code,
    String message,
  ) async {
    try {
      await _writeError(response, statusCode, code, message);
    } catch (_) {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _writeResponse(
    HttpResponse response,
    PaidProviderProxyResponse proxyResponse,
  ) async {
    response.statusCode = proxyResponse.statusCode;
    proxyResponse.headers.forEach(response.headers.set);
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final bodyBytes = proxyResponse.bodyBytes;
    if (bodyBytes != null) response.contentLength = bodyBytes.length;
    await for (final chunk in proxyResponse.openBodyStream()) {
      response.add(chunk);
      await response.flush();
    }
    await response.close();
  }

  static Set<PaidProviderId> _noReadyProviders() => const {};
}

/// Venice-specific policy for the generic loopback proxy. Model payloads have
/// already been semantically mapped by [PaidProviderProxyService]; this layer
/// adds only bounded wallet identity and terminal balance bookkeeping.
class VenicePaidProviderProxyHandler {
  VenicePaidProviderProxyHandler({
    required PaidProviderHttpClient httpClient,
    VeniceWalletAuthService? walletAuth,
    PaidProviderTurnAuthorizationService? turnAuthorization,
    ProviderBalanceService? balances,
  })  : _httpClient = httpClient,
        _walletAuth = walletAuth ?? VeniceWalletAuthService(),
        _turnAuthorization =
            turnAuthorization ?? PaidProviderTurnAuthorizationService.instance,
        _balances = balances ?? ProviderBalanceService.instance;

  final PaidProviderHttpClient _httpClient;
  final VeniceWalletAuthService _walletAuth;
  final PaidProviderTurnAuthorizationService _turnAuthorization;
  final ProviderBalanceService _balances;

  Future<PaidProviderProxyResponse> call(
    PaidProviderProxyRequest request,
  ) async {
    if (request.provider != PaidProviderId.venice ||
        request.route.provider != PaidProviderId.venice) {
      throw const PaidProviderProxyException(
        'The Venice handler received another provider.',
        code: 'provider_route_mismatch',
      );
    }

    final isInference =
        request.route.kind == PaidProviderProxyRouteKind.chatCompletions;
    if (isInference) {
      final gatewayModelId = request.gatewayModelId?.trim() ?? '';
      try {
        _turnAuthorization.consumeForProxy(
          provider: PaidProviderId.venice,
          gatewayModelId: gatewayModelId,
        );
      } on PaidProviderTurnAuthorizationException catch (error) {
        throw PaidProviderProxyException(
          error.message,
          code: error.code,
          statusCode: HttpStatus.forbidden,
        );
      }
    }

    final upstreamUri = _httpClient.upstreamUriFor(request.route);
    late String identity;
    try {
      identity = await _walletAuth.authorize(
        request.route.method,
        upstreamUri,
      );
    } on VeniceWalletAuthException catch (error) {
      throw PaidProviderProxyException(
        error.message,
        code: error.code,
        statusCode: HttpStatus.serviceUnavailable,
      );
    }

    final response = await _httpClient.send(
      request,
      upstreamHeaders: <String, String>{
        'X-Sign-In-With-X': identity,
      },
    );
    if (!isInference) return response;

    final success = response.statusCode >= 200 && response.statusCode < 300;
    if (success) {
      final remaining = _header(response.headers, 'x-balance-remaining');
      if (remaining != null) {
        try {
          _balances.captureVeniceRemainingBalance(remaining);
        } catch (_) {
          // Provider metadata is advisory and cannot change chat delivery.
        }
      }
    }

    return PaidProviderProxyResponse.stream(
      statusCode: response.statusCode,
      headers: response.headers,
      bodyStream: _observeTerminalResponse(
        response.openBodyStream(),
        refreshBalance: success,
      ),
    );
  }

  Stream<List<int>> _observeTerminalResponse(
    Stream<List<int>> source, {
    required bool refreshBalance,
  }) async* {
    var completed = false;
    try {
      await for (final chunk in source) {
        yield chunk;
      }
      completed = true;
    } finally {
      if (completed && refreshBalance) {
        unawaited(_refreshBalanceSafely());
      }
    }
  }

  Future<void> _refreshBalanceSafely() async {
    try {
      await _balances.refresh('venice');
    } catch (_) {
      // A post-response balance refresh is never part of model delivery.
    }
  }

  String? _header(Map<String, String> headers, String name) {
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) return entry.value;
    }
    return null;
  }

  void close() => _httpClient.close();
}

class _RequestBodyTooLargeException implements Exception {
  const _RequestBodyTooLargeException();
}
