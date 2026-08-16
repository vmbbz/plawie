import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clawa/services/product_telemetry_event.dart';
import 'package:clawa/services/product_telemetry_service.dart';

void main() {
  const config = ProductAnalyticsConfig(
    host: 'https://eu.i.posthog.com',
    projectKey: 'phc_test_project_token',
    releaseChannel: 'test',
    appVersion: '2.3.0-test',
  );

  test('configuration is fail-closed and requires an HTTPS ingest host', () {
    expect(config.captureUri.toString(), 'https://eu.i.posthog.com/i/v0/e/');
    expect(config.isConfigured, isTrue);
    expect(
      const ProductAnalyticsConfig(
        host: 'http://eu.i.posthog.com',
        projectKey: 'phc_test',
        releaseChannel: 'test',
        appVersion: 'test',
      ).isConfigured,
      isFalse,
    );
    expect(
      const ProductAnalyticsConfig(
        host: 'https://eu.i.posthog.com',
        projectKey: '',
        releaseChannel: 'test',
        appVersion: 'test',
      ).isConfigured,
      isFalse,
    );
    expect(
      const ProductAnalyticsConfig(
        host: 'https://eu.i.posthog.com/custom/path',
        projectKey: 'phc_test_project_token',
        releaseChannel: 'test',
        appVersion: 'test',
      ).isConfigured,
      isFalse,
    );
    expect(
      const ProductAnalyticsConfig(
        host: 'https://eu.i.posthog.com',
        projectKey: 'phx_secret_key',
        releaseChannel: 'test',
        appVersion: 'test',
      ).isConfigured,
      isFalse,
    );
  });

  test('PostHog transport sends an anonymous allowlisted event', () async {
    late Uri requestUri;
    late Map<String, dynamic> requestBody;
    final transport = PostHogProductTelemetryTransport(
      config: config,
      client: MockClient((request) async {
        requestUri = request.url;
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );
    final queued = QueuedProductTelemetryEvent(
      eventId: 'event-1',
      event: ProductTelemetryEvent(
        name: ProductTelemetryEventName.gatewayReady,
        occurredAt: DateTime.utc(2026, 8, 16, 12),
        releaseVersion: '2.3.0-test',
        releaseChannel: 'test',
        properties: const <String, Object?>{
          'source': 'gateway_state_stream',
          'mode': 'native_gateway',
        },
      ),
    );

    await transport.capture(
      queuedEvent: queued,
      installationId: 'plawie-install-random',
      sessionId: 'session-random',
    );

    expect(requestUri.toString(), 'https://eu.i.posthog.com/i/v0/e/');
    expect(requestBody['event'], 'gateway_ready');
    expect(requestBody['distinct_id'], 'plawie-install-random');
    final properties = requestBody['properties'] as Map<String, dynamic>;
    expect(properties[r'$process_person_profile'], isFalse);
    expect(properties[r'$geoip_disable'], isTrue);
    expect(properties[r'$session_id'], 'session-random');
    expect(properties['plawieEventId'], 'event-1');
    expect(properties['platform'], 'android');
    expect(jsonEncode(requestBody), isNot(contains('prompt')));
    expect(jsonEncode(requestBody), isNot(contains('transcript')));
    expect(jsonEncode(requestBody), isNot(contains('walletAddress')));
  });

  test('service creates identity only after consent and clears it on denial',
      () async {
    final persistence = _MemoryTelemetryPersistence();
    final transport = _FakeTelemetryTransport();
    var nextId = 0;
    final service = ProductTelemetryService(
      config: config,
      persistence: persistence,
      transport: transport,
      idGenerator: () => 'random-${nextId++}',
      clock: () => DateTime.utc(2026, 8, 16, 12),
    );

    await service.initialize();
    expect(service.consent, ProductAnalyticsConsent.undecided);
    expect(persistence.installationId, isNull);
    expect(transport.captured, isEmpty);

    expect(
      await service.setConsent(ProductAnalyticsConsent.granted),
      isTrue,
    );
    await service.flush();

    expect(persistence.installationId, startsWith('plawie-install-random-'));
    expect(
      transport.captured.map((capture) => capture.event.name),
      containsAllInOrder(<ProductTelemetryEventName>[
        ProductTelemetryEventName.appFirstOpened,
        ProductTelemetryEventName.appOpened,
      ]),
    );
    expect(
      transport.captured.map((capture) => capture.installationId).toSet(),
      hasLength(1),
    );

    await service.record(
      ProductTelemetryEventName.agentTurnCompleted,
      properties: const <String, Object?>{
        'providerId': 'venice',
        'outcome': 'success',
      },
    );
    await service.flush();
    expect(
      transport.captured.last.event.name,
      ProductTelemetryEventName.agentTurnCompleted,
    );

    expect(
      await service.setConsent(ProductAnalyticsConsent.denied),
      isTrue,
    );
    expect(persistence.installationId, isNull);
    expect(persistence.pendingEvents, isEmpty);
    expect(persistence.onceKeys, isEmpty);
  });

  test('failed delivery stays queued and retries without product failure',
      () async {
    final persistence = _MemoryTelemetryPersistence(
      consent: ProductAnalyticsConsent.granted,
      installationId: 'plawie-install-existing',
    );
    final transport = _FakeTelemetryTransport()..fail = true;
    var nextId = 0;
    final service = ProductTelemetryService(
      config: config,
      persistence: persistence,
      transport: transport,
      idGenerator: () => 'retry-${nextId++}',
      clock: () => DateTime.utc(2026, 8, 16, 12),
    );

    await service.initialize();
    await service.flush();
    expect(service.pendingEventCount, 2);

    transport.fail = false;
    await service.flush();
    expect(service.pendingEventCount, 0);
    expect(transport.captured, hasLength(2));
  });

  test('session-once events are atomic and the queue preserves early events',
      () async {
    final persistence = _MemoryTelemetryPersistence(
      consent: ProductAnalyticsConsent.granted,
      installationId: 'plawie-install-existing',
    );
    final transport = _FakeTelemetryTransport()..fail = true;
    var nextId = 0;
    final service = ProductTelemetryService(
      config: config,
      persistence: persistence,
      transport: transport,
      idGenerator: () => 'bounded-${nextId++}',
      clock: () => DateTime.utc(2026, 8, 16, 12),
    );

    await service.initialize();
    await Future.wait(<Future<bool>>[
      service.recordSessionOnce(
        ProductTelemetryEventName.ttsFailed,
        sessionKey: 'tts_runtime_error',
        properties: const <String, Object?>{
          'errorCode': 'tts_runtime_error',
        },
      ),
      service.recordSessionOnce(
        ProductTelemetryEventName.ttsFailed,
        sessionKey: 'tts_runtime_error',
        properties: const <String, Object?>{
          'errorCode': 'tts_runtime_error',
        },
      ),
    ]);
    for (var index = 0;
        index < ProductTelemetryService.maxPendingEvents;
        index++) {
      await service.record(
        ProductTelemetryEventName.gatewayFailed,
        properties: const <String, Object?>{
          'errorCode': 'gateway_state_error',
        },
      );
    }
    await service.flush();

    expect(service.pendingEventCount, ProductTelemetryService.maxPendingEvents);
    expect(
      persistence.pendingEvents.where(
          (queued) => queued.event.name == ProductTelemetryEventName.ttsFailed),
      hasLength(1),
    );
    expect(
      persistence.pendingEvents.first.event.name,
      ProductTelemetryEventName.appFirstOpened,
    );
  });

  test('stored external-looking identifiers are replaced, not reused',
      () async {
    final persistence = _MemoryTelemetryPersistence(
      consent: ProductAnalyticsConsent.granted,
      installationId: '0x1234567890abcdef1234567890abcdef12345678',
    );
    var nextId = 0;
    final service = ProductTelemetryService(
      config: config,
      persistence: persistence,
      transport: _FakeTelemetryTransport(),
      idGenerator: () => 'safe-random-${nextId++}',
    );

    await service.initialize();
    await service.flush();

    expect(
        persistence.installationId, startsWith('plawie-install-safe-random'));
    expect(persistence.installationId, isNot(startsWith('0x')));
  });

  test('declined consent clears stale analytics state during startup',
      () async {
    final persistence = _MemoryTelemetryPersistence(
      consent: ProductAnalyticsConsent.denied,
      installationId: 'plawie-install-stale-id',
    )
      ..pendingEvents = <QueuedProductTelemetryEvent>[
        QueuedProductTelemetryEvent(
          eventId: 'stale-event',
          event: ProductTelemetryEvent(
            name: ProductTelemetryEventName.appOpened,
            occurredAt: DateTime.utc(2026, 8, 16, 12),
          ),
        ),
      ]
      ..onceKeys = <String>{'stale_once_key'};
    final service = ProductTelemetryService(
      config: config,
      persistence: persistence,
      transport: _FakeTelemetryTransport(),
      idGenerator: () => 'unused-random-id',
    );

    await service.initialize();

    expect(persistence.installationId, isNull);
    expect(persistence.pendingEvents, isEmpty);
    expect(persistence.onceKeys, isEmpty);
  });

  test('unconfigured build and rejected properties never enqueue', () async {
    final persistence = _MemoryTelemetryPersistence();
    final transport = _FakeTelemetryTransport(configured: false);
    final service = ProductTelemetryService(
      config: const ProductAnalyticsConfig(
        host: '',
        projectKey: '',
        releaseChannel: 'test',
        appVersion: 'test',
      ),
      persistence: persistence,
      transport: transport,
      idGenerator: () => 'random',
    );

    await service.initialize();
    await service.setConsent(ProductAnalyticsConsent.granted);
    expect(service.pendingEventCount, 0);
    expect(transport.captured, isEmpty);

    final configuredService = ProductTelemetryService(
      config: config,
      persistence: _MemoryTelemetryPersistence(
        consent: ProductAnalyticsConsent.granted,
        installationId: 'plawie-install-existing',
      ),
      transport: _FakeTelemetryTransport(),
      idGenerator: () => 'event-id',
    );
    await configuredService.initialize();
    expect(
      await configuredService.record(
        ProductTelemetryEventName.gatewayFailed,
        properties: const <String, Object?>{'prompt': 'blocked'},
      ),
      isFalse,
    );
  });

  test('duration buckets are stable and bounded', () {
    expect(ProductTelemetryBuckets.duration(const Duration(seconds: 1)),
        'under_2s');
    expect(
        ProductTelemetryBuckets.duration(const Duration(seconds: 9)), '2_10s');
    expect(ProductTelemetryBuckets.duration(const Duration(seconds: 29)),
        '10_30s');
    expect(ProductTelemetryBuckets.duration(const Duration(seconds: 90)),
        '30_120s');
    expect(ProductTelemetryBuckets.duration(const Duration(minutes: 3)),
        'over_120s');
  });
}

class _MemoryTelemetryPersistence implements ProductTelemetryPersistence {
  _MemoryTelemetryPersistence({
    this.consent = ProductAnalyticsConsent.undecided,
    this.installationId,
  });

  ProductAnalyticsConsent consent;
  String? installationId;
  List<QueuedProductTelemetryEvent> pendingEvents =
      <QueuedProductTelemetryEvent>[];
  Set<String> onceKeys = <String>{};

  @override
  Future<ProductAnalyticsConsent> readConsent() async => consent;

  @override
  Future<void> writeConsent(ProductAnalyticsConsent value) async {
    consent = value;
  }

  @override
  Future<String?> readInstallationId() async => installationId;

  @override
  Future<void> writeInstallationId(String? value) async {
    installationId = value;
  }

  @override
  Future<List<QueuedProductTelemetryEvent>> readPendingEvents() async =>
      List<QueuedProductTelemetryEvent>.from(pendingEvents);

  @override
  Future<void> writePendingEvents(
    List<QueuedProductTelemetryEvent> events,
  ) async {
    pendingEvents = List<QueuedProductTelemetryEvent>.from(events);
  }

  @override
  Future<Set<String>> readOnceKeys() async => Set<String>.from(onceKeys);

  @override
  Future<void> writeOnceKeys(Set<String> keys) async {
    onceKeys = Set<String>.from(keys);
  }
}

class _TelemetryCapture {
  const _TelemetryCapture({
    required this.event,
    required this.installationId,
    required this.sessionId,
  });

  final ProductTelemetryEvent event;
  final String installationId;
  final String sessionId;
}

class _FakeTelemetryTransport implements ProductTelemetryTransport {
  _FakeTelemetryTransport({this.configured = true});

  final bool configured;
  bool fail = false;
  final List<_TelemetryCapture> captured = <_TelemetryCapture>[];

  @override
  bool get isConfigured => configured;

  @override
  Future<void> capture({
    required QueuedProductTelemetryEvent queuedEvent,
    required String installationId,
    required String sessionId,
  }) async {
    if (fail) {
      throw const ProductTelemetryTransportException('offline');
    }
    captured.add(
      _TelemetryCapture(
        event: queuedEvent.event,
        installationId: installationId,
        sessionId: sessionId,
      ),
    );
  }
}
