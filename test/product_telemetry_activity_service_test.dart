import 'dart:async';

import 'package:clawa/services/product_telemetry_activity_service.dart';
import 'package:clawa/services/product_telemetry_event.dart';
import 'package:clawa/services/product_telemetry_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = ProductAnalyticsConfig(
    host: 'https://eu.i.posthog.com',
    projectKey: 'phc_test_project_token',
    releaseChannel: 'test',
    appVersion: '2.3.0-test',
  );

  test('records foreground sessions and heartbeats only while visibly active',
      () async {
    final persistence = _MemoryPersistence(
      consent: ProductAnalyticsConsent.granted,
      installationId: 'plawie-install-test-identity',
    );
    final transport = _CaptureTransport();
    final telemetry = _telemetry(config, persistence, transport);
    await telemetry.initialize();
    await telemetry.flush();
    transport.captured.clear();

    final timers = <_FakeTimer>[];
    final activity = ProductTelemetryActivityService(
      telemetry: telemetry,
      observeBinding: false,
      timerFactory: _timerFactory(timers),
    )..start();

    await activity.updateLifecycleState(AppLifecycleState.resumed);
    await _drain(telemetry);

    expect(_count(transport, ProductTelemetryEventName.appForegrounded), 1);
    expect(_count(transport, ProductTelemetryEventName.appActiveHeartbeat), 1);
    final heartbeat = timers.singleWhere(
      (timer) =>
          timer.duration == ProductTelemetryActivityService.heartbeatInterval,
    );
    expect(heartbeat.isActive, isTrue);

    heartbeat.fire();
    await _drain(telemetry);
    expect(_count(transport, ProductTelemetryEventName.appActiveHeartbeat), 2);

    await activity.updateLifecycleState(AppLifecycleState.paused);
    final grace = timers.lastWhere(
      (timer) =>
          timer.duration == ProductTelemetryActivityService.backgroundGrace,
    );
    expect(heartbeat.isActive, isTrue);
    grace.fire();
    await _drain(telemetry);
    expect(heartbeat.isActive, isFalse);

    await activity.updateLifecycleState(AppLifecycleState.resumed);
    await _drain(telemetry);
    expect(_count(transport, ProductTelemetryEventName.appForegrounded), 2);
    expect(_count(transport, ProductTelemetryEventName.appActiveHeartbeat), 3);

    activity.dispose();
  });

  test('PiP transition stays in one session and heartbeats use PiP surface',
      () async {
    final transport = _CaptureTransport();
    final telemetry = _telemetry(
      config,
      _MemoryPersistence(
        consent: ProductAnalyticsConsent.granted,
        installationId: 'plawie-install-test-identity',
      ),
      transport,
    );
    await telemetry.initialize();
    await telemetry.flush();
    transport.captured.clear();

    final timers = <_FakeTimer>[];
    final activity = ProductTelemetryActivityService(
      telemetry: telemetry,
      observeBinding: false,
      timerFactory: _timerFactory(timers),
    )..start();

    await activity.updateLifecycleState(AppLifecycleState.resumed);
    await activity.updateLifecycleState(AppLifecycleState.paused);
    final entryGrace = timers.lastWhere(
      (timer) =>
          timer.duration == ProductTelemetryActivityService.backgroundGrace,
    );
    await activity.setPictureInPictureActive(true);
    entryGrace.fire();

    final heartbeat = timers.singleWhere(
      (timer) =>
          timer.duration == ProductTelemetryActivityService.heartbeatInterval,
    );
    heartbeat.fire();
    await _drain(telemetry);

    expect(_count(transport, ProductTelemetryEventName.appForegrounded), 1);
    final heartbeatEvents = transport.captured
        .where((event) =>
            event.name == ProductTelemetryEventName.appActiveHeartbeat)
        .toList();
    expect(heartbeatEvents.last.properties['surface'], 'pip');

    await activity.setPictureInPictureActive(false);
    final exitGrace = timers.lastWhere(
      (timer) =>
          timer.duration == ProductTelemetryActivityService.backgroundGrace &&
          timer.isActive,
    );
    exitGrace.fire();
    await _drain(telemetry);
    expect(heartbeat.isActive, isFalse);

    activity.dispose();
  });

  test('consent enables active measurement and opt-out stops it', () async {
    final persistence = _MemoryPersistence();
    final transport = _CaptureTransport();
    final telemetry = _telemetry(config, persistence, transport);
    await telemetry.initialize();

    final timers = <_FakeTimer>[];
    final activity = ProductTelemetryActivityService(
      telemetry: telemetry,
      observeBinding: false,
      timerFactory: _timerFactory(timers),
    )..start();
    await activity.updateLifecycleState(AppLifecycleState.resumed);

    expect(transport.captured, isEmpty);
    expect(timers, isEmpty);
    expect(persistence.installationId, isNull);

    await telemetry.setConsent(ProductAnalyticsConsent.granted);
    await _drain(telemetry);
    expect(
      transport.captured.map((event) => event.name),
      containsAllInOrder(<ProductTelemetryEventName>[
        ProductTelemetryEventName.appFirstOpened,
        ProductTelemetryEventName.appOpened,
        ProductTelemetryEventName.appForegrounded,
        ProductTelemetryEventName.appActiveHeartbeat,
      ]),
    );
    final heartbeat = timers.singleWhere(
      (timer) =>
          timer.duration == ProductTelemetryActivityService.heartbeatInterval,
    );
    expect(heartbeat.isActive, isTrue);

    await telemetry.setConsent(ProductAnalyticsConsent.denied);
    expect(heartbeat.isActive, isFalse);
    expect(persistence.installationId, isNull);
    expect(persistence.pendingEvents, isEmpty);

    activity.dispose();
  });
}

ProductTelemetryService _telemetry(
  ProductAnalyticsConfig config,
  _MemoryPersistence persistence,
  _CaptureTransport transport,
) {
  var nextId = 0;
  return ProductTelemetryService(
    config: config,
    persistence: persistence,
    transport: transport,
    idGenerator: () => 'safe-event-${nextId++}',
    clock: () => DateTime.utc(2026, 8, 16, 12),
  );
}

Future<void> _drain(ProductTelemetryService telemetry) async {
  await Future<void>.delayed(Duration.zero);
  await telemetry.flush();
  await Future<void>.delayed(Duration.zero);
  await telemetry.flush();
}

int _count(
  _CaptureTransport transport,
  ProductTelemetryEventName name,
) {
  return transport.captured.where((event) => event.name == name).length;
}

ProductTelemetryTimerFactory _timerFactory(List<_FakeTimer> timers) {
  return (
    Duration duration,
    VoidCallback callback, {
    required bool periodic,
  }) {
    final timer = _FakeTimer(
      duration: duration,
      callback: callback,
      periodic: periodic,
    );
    timers.add(timer);
    return timer;
  };
}

class _FakeTimer implements Timer {
  _FakeTimer({
    required this.duration,
    required this.callback,
    required this.periodic,
  });

  final Duration duration;
  final VoidCallback callback;
  final bool periodic;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _tick++;
    if (!periodic) _active = false;
    callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

class _MemoryPersistence implements ProductTelemetryPersistence {
  _MemoryPersistence({
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

class _CaptureTransport implements ProductTelemetryTransport {
  final List<ProductTelemetryEvent> captured = <ProductTelemetryEvent>[];

  @override
  bool get isConfigured => true;

  @override
  Future<void> capture({
    required QueuedProductTelemetryEvent queuedEvent,
    required String installationId,
    required String sessionId,
  }) async {
    captured.add(queuedEvent.event);
  }
}
