import 'blockrun_paid_provider_proxy_handler.dart';
import 'paid_provider_http_client.dart';
import 'paid_provider_loopback_credential_service.dart';
import 'paid_provider_proxy_models.dart';
import 'paid_provider_proxy_service.dart';

class PaidProviderGatewayException implements Exception {
  const PaidProviderGatewayException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PaidProviderGatewayException($code): $message';
}

class PaidProviderGatewayPreparation {
  const PaidProviderGatewayPreparation({
    required this.enabled,
    required this.providerId,
    required this.proxyUri,
  });

  final bool enabled;
  final String? providerId;
  final Uri? proxyUri;
}

/// Owns the narrow lifecycle boundary between the native OpenClaw Gateway and
/// the Dart loopback paid-provider transport. Configuration is mutated only
/// after the authenticated health check succeeds.
class PaidProviderGatewayCoordinator {
  PaidProviderGatewayCoordinator({
    required PaidProviderLoopbackCredentialService credentials,
    required PaidProviderProxyController proxy,
  })  : _credentials = credentials,
        _proxy = proxy;

  factory PaidProviderGatewayCoordinator.production() {
    final credentials = PaidProviderLoopbackCredentialService();
    final veniceClient = PaidProviderHttpClient();
    final blockRunClient = PaidProviderHttpClient();
    final venice = VenicePaidProviderProxyHandler(httpClient: veniceClient);
    final blockRun = BlockRunPaidProviderProxyHandler(
      httpClient: blockRunClient,
    );
    final proxy = PaidProviderProxyService(
      credentialService: credentials,
      readyProviders: () => PaidProviderId.values.toSet(),
      handler: (request) => switch (request.provider) {
        PaidProviderId.venice => venice(request),
        PaidProviderId.blockrun => blockRun(request),
      },
    );
    return PaidProviderGatewayCoordinator(
      credentials: credentials,
      proxy: proxy,
    );
  }

  static final PaidProviderGatewayCoordinator instance =
      PaidProviderGatewayCoordinator.production();

  static const Set<String> providerIds = <String>{'venice', 'blockrun'};

  final PaidProviderLoopbackCredentialService _credentials;
  final PaidProviderProxyController _proxy;

  bool get isRunning => _proxy.isRunning;

  String? providerForModel(String? modelId) {
    final value = modelId?.trim() ?? '';
    final separator = value.indexOf('/');
    if (separator <= 0) return null;
    final provider = value.substring(0, separator).toLowerCase();
    return providerIds.contains(provider) ? provider : null;
  }

  Future<PaidProviderGatewayPreparation> prepareGatewayConfig(
    Map<String, dynamic> config, {
    required String selectedModel,
  }) async {
    final providerId = providerForModel(selectedModel);
    if (providerId == null) {
      return const PaidProviderGatewayPreparation(
        enabled: false,
        providerId: null,
        proxyUri: null,
      );
    }

    if (!_proxy.isRunning) {
      final recovered = _recoverableCredential(config, providerId);
      if (recovered != null) {
        _credentials.restoreFromGatewayConfiguration(
          recovered,
          proxyStopped: true,
        );
      }
    }

    final wasRunning = _proxy.isRunning;
    late Uri proxyUri;
    try {
      proxyUri = await _proxy.start();
      if (!await _proxy.verifyHealth()) {
        throw const PaidProviderGatewayException(
          'proxy_health_failed',
          'The paid-provider proxy did not pass authenticated health checks.',
        );
      }
    } catch (error) {
      if (!wasRunning) {
        await _proxy.stop().catchError((_) {});
      }
      if (error is PaidProviderGatewayException) rethrow;
      throw const PaidProviderGatewayException(
        'proxy_start_failed',
        'The paid-provider proxy could not start on its private loopback port.',
      );
    }

    _applyGatewayProviders(config, proxyUri);
    return PaidProviderGatewayPreparation(
      enabled: true,
      providerId: providerId,
      proxyUri: proxyUri,
    );
  }

  void removeGatewayCapabilities(Map<String, dynamic> config) {
    final providers =
        config['models'] is Map ? (config['models'] as Map)['providers'] : null;
    if (providers is! Map) return;
    for (final providerId in providerIds) {
      final provider = providers[providerId];
      if (provider is Map) provider.remove('apiKey');
    }
  }

  Future<void> stopAfterGateway({required bool gatewayStopped}) async {
    if (!gatewayStopped) {
      throw StateError('Stop the Gateway before the paid-provider proxy.');
    }
    final attached = _proxy.attachedToExisting;
    await _proxy.stop();
    if (!attached) {
      _credentials.rotate(gatewayStopped: true, proxyStopped: true);
    }
  }

  bool hasCurrentCapability(
    Map<String, dynamic> config,
    String providerId,
  ) {
    if (!providerIds.contains(providerId) || !_proxy.isRunning) return false;
    final provider =
        config['models'] is Map && (config['models'] as Map)['providers'] is Map
            ? ((config['models'] as Map)['providers'] as Map)[providerId]
            : null;
    return provider is Map &&
        provider['apiKey'] == _credentials.credentialForGatewayConfiguration();
  }

  void _applyGatewayProviders(Map<String, dynamic> config, Uri proxyUri) {
    if (config['models'] is! Map) config['models'] = <String, dynamic>{};
    final models = config['models'] as Map;
    if (models['providers'] is! Map) {
      models['providers'] = <String, dynamic>{};
    }
    final providers = models['providers'] as Map;
    final capability = _credentials.credentialForGatewayConfiguration();

    for (final providerId in providerIds) {
      final existing = providers[providerId];
      final merged = existing is Map
          ? existing.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      final existingModels = merged['models'];
      merged['api'] = 'openai-completions';
      merged['baseUrl'] = proxyUri.resolve('$providerId/v1').toString();
      merged['apiKey'] = capability;
      merged['models'] = existingModels is List
          ? List<dynamic>.from(existingModels)
          : <dynamic>[];
      providers[providerId] = merged;
    }
  }

  String? _recoverableCredential(
    Map<String, dynamic> config,
    String selectedProvider,
  ) {
    final provider =
        config['models'] is Map && (config['models'] as Map)['providers'] is Map
            ? ((config['models'] as Map)['providers'] as Map)[selectedProvider]
            : null;
    if (provider is! Map ||
        provider['api'] != 'openai-completions' ||
        provider['apiKey'] is! String) {
      return null;
    }
    final baseUrl = Uri.tryParse(provider['baseUrl']?.toString() ?? '');
    final expectedPath = '/$selectedProvider/v1';
    if (baseUrl == null ||
        baseUrl.scheme != 'http' ||
        baseUrl.host != '127.0.0.1' ||
        baseUrl.port != _proxy.port ||
        baseUrl.path != expectedPath ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment) {
      return null;
    }
    final candidate = provider['apiKey'] as String;
    return PaidProviderLoopbackCredentialService.isValidGatewayCredential(
      candidate,
    )
        ? candidate
        : null;
  }
}
