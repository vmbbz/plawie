import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/paid_provider_gateway_coordinator.dart';
import 'package:clawa/services/paid_provider_loopback_credential_service.dart';
import 'package:clawa/services/paid_provider_proxy_service.dart';

void main() {
  test('read-only health inspection never starts a stopped proxy', () async {
    final stopped = _FakeProxy();
    final stoppedCoordinator = PaidProviderGatewayCoordinator(
      credentials: _credentials(0),
      proxy: stopped,
    );
    expect(await stoppedCoordinator.inspectHealth(), isNull);
    expect(stopped.events, isEmpty);

    final running = _FakeProxy(running: true, healthy: true);
    final runningCoordinator = PaidProviderGatewayCoordinator(
      credentials: _credentials(0),
      proxy: running,
    );
    expect(await runningCoordinator.inspectHealth(), isTrue);
    expect(running.events, <String>['health']);
  });

  test('starts and health-checks before injecting only paid providers',
      () async {
    final events = <String>[];
    final proxy = _FakeProxy(events: events);
    final credentials = _credentials(1);
    final coordinator = PaidProviderGatewayCoordinator(
      credentials: credentials,
      proxy: proxy,
    );
    final config = <String, dynamic>{
      'models': <String, dynamic>{
        'providers': <String, dynamic>{
          'openrouter': <String, dynamic>{
            'baseUrl': 'https://custom.example/v1',
            'apiKey': 'user-secret',
            'custom': true,
          },
          'blockrun': <String, dynamic>{
            'baseUrl': 'https://stale.example/v1',
            'api': 'stale-api',
            'apiKey': 'stale-capability',
            'models': <Map<String, dynamic>>[
              {'id': 'openai/gpt-5.5', 'name': 'GPT-5.5'},
            ],
            'customUiHint': 'preserve',
          },
        },
      },
    };

    final preparation = await coordinator.prepareGatewayConfig(
      config,
      selectedModel: 'blockrun/openai/gpt-5.5',
    );

    expect(events, <String>['start', 'health']);
    expect(preparation.enabled, isTrue);
    expect(preparation.providerId, 'blockrun');
    expect(preparation.proxyUri, Uri.parse('http://127.0.0.1:11436/'));

    final providers = config['models']['providers'] as Map;
    expect(providers['openrouter'], <String, dynamic>{
      'baseUrl': 'https://custom.example/v1',
      'apiKey': 'user-secret',
      'custom': true,
    });
    expect(providers['blockrun'], containsPair('customUiHint', 'preserve'));
    expect(
      providers['blockrun']['models'],
      <Map<String, dynamic>>[
        {'id': 'openai/gpt-5.5', 'name': 'GPT-5.5'},
      ],
    );
    expect(
      providers['blockrun']['baseUrl'],
      'http://127.0.0.1:11436/blockrun/v1',
    );
    expect(providers['blockrun']['api'], 'openai-completions');
    expect(
      providers['blockrun']['apiKey'],
      credentials.credentialForGatewayConfiguration(),
    );
    expect(
      providers['venice']['baseUrl'],
      'http://127.0.0.1:11436/venice/v1',
    );
    expect(
      providers['venice']['apiKey'],
      credentials.credentialForGatewayConfiguration(),
    );
  });

  test('restores an app-private capability before attaching to a live gateway',
      () async {
    final events = <String>[];
    final persisted = _credentials(9).credentialForGatewayConfiguration();
    final credentials = _credentials(1);
    final proxy = _FakeProxy(events: events);
    final coordinator = PaidProviderGatewayCoordinator(
      credentials: credentials,
      proxy: proxy,
    );
    final config = <String, dynamic>{
      'models': <String, dynamic>{
        'providers': <String, dynamic>{
          'venice': <String, dynamic>{
            'baseUrl': 'http://127.0.0.1:11436/venice/v1',
            'api': 'openai-completions',
            'apiKey': persisted,
            'models': <dynamic>[],
          },
        },
      },
    };

    await coordinator.prepareGatewayConfig(
      config,
      selectedModel: 'venice/llama-3.3-70b',
    );

    expect(events, <String>['start', 'health']);
    expect(credentials.credentialForGatewayConfiguration(), persisted);
    expect(
      config['models']['providers']['blockrun']['apiKey'],
      persisted,
    );
  });

  test('failed proxy health leaves Gateway config byte-equivalent', () async {
    final proxy = _FakeProxy(healthy: false);
    final coordinator = PaidProviderGatewayCoordinator(
      credentials: _credentials(2),
      proxy: proxy,
    );
    final config = <String, dynamic>{
      'models': <String, dynamic>{
        'providers': <String, dynamic>{
          'openai': <String, dynamic>{'apiKey': 'keep-me'},
        },
      },
    };
    final before = jsonEncode(config);

    await expectLater(
      coordinator.prepareGatewayConfig(
        config,
        selectedModel: 'blockrun/openai/gpt-5.5',
      ),
      throwsA(isA<PaidProviderGatewayException>()),
    );

    expect(jsonEncode(config), before);
    expect(proxy.events, <String>['start', 'health', 'stop']);
  });

  test('disable removes only Plawie-owned paid capabilities', () async {
    final credentials = _credentials(3);
    final before = credentials.credentialForGatewayConfiguration();
    final proxy = _FakeProxy(running: true);
    final coordinator = PaidProviderGatewayCoordinator(
      credentials: credentials,
      proxy: proxy,
    );
    final config = <String, dynamic>{
      'models': <String, dynamic>{
        'providers': <String, dynamic>{
          'openai': <String, dynamic>{'apiKey': 'user-key'},
          'venice': <String, dynamic>{
            'apiKey': before,
            'baseUrl': 'http://127.0.0.1:11436/venice/v1',
            'custom': 'keep',
          },
          'blockrun': <String, dynamic>{
            'apiKey': 'older-capability',
            'custom': 'keep-too',
          },
        },
      },
    };

    coordinator.removeGatewayCapabilities(config);
    expect(config['models']['providers']['openai']['apiKey'], 'user-key');
    expect(config['models']['providers']['venice']['apiKey'], isNull);
    expect(config['models']['providers']['venice']['custom'], 'keep');
    expect(config['models']['providers']['blockrun']['apiKey'], isNull);
    expect(config['models']['providers']['blockrun']['custom'], 'keep-too');

    await expectLater(
      coordinator.stopAfterGateway(gatewayStopped: false),
      throwsStateError,
    );
    expect(credentials.credentialForGatewayConfiguration(), before);

    await coordinator.stopAfterGateway(gatewayStopped: true);
    expect(proxy.events, contains('stop'));
    expect(credentials.credentialForGatewayConfiguration(), isNot(before));
  });
}

PaidProviderLoopbackCredentialService _credentials(int seed) {
  var generation = 0;
  return PaidProviderLoopbackCredentialService(
    randomBytes: (length) {
      final offset = generation++;
      return Uint8List.fromList(
        List<int>.generate(
          length,
          (index) => (seed + offset + index) & 0xff,
        ),
      );
    },
  );
}

class _FakeProxy implements PaidProviderProxyController {
  _FakeProxy({
    List<String>? events,
    this.healthy = true,
    bool running = false,
  })  : events = events ?? <String>[],
        _running = running;

  final List<String> events;
  final bool healthy;
  bool _running;

  @override
  bool get attachedToExisting => false;

  @override
  bool get isRunning => _running;

  @override
  bool get ownsServer => _running;

  @override
  int get port => 11436;

  @override
  Uri get uri => Uri.parse('http://127.0.0.1:11436/');

  @override
  Future<Uri> start() async {
    events.add('start');
    _running = true;
    return uri;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    _running = false;
  }

  @override
  Future<bool> verifyHealth() async {
    events.add('health');
    return healthy;
  }
}
