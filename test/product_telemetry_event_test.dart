import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/product_telemetry_event.dart';

void main() {
  final occurredAt = DateTime.utc(2026, 8, 15, 13);

  test('serializes bounded operational properties only', () {
    final event = ProductTelemetryEvent(
      name: ProductTelemetryEventName.providerPaymentSettled,
      occurredAt: occurredAt,
      releaseVersion: '2.3.0-preview.4',
      releaseChannel: 'android-preview',
      properties: const <String, Object?>{
        'providerId': 'venice',
        'lane': 'providerTopUp',
        'status': 'settled',
        'amountBucket': '1-5_usdc',
        'feeScheduleVersion': 1,
        'reconciled': false,
      },
    );

    final json = event.toJson();

    expect(json['schemaVersion'], 1);
    expect(json['name'], 'provider_payment_settled');
    expect(json['properties'], isA<Map<String, Object>>());
    expect(jsonEncode(json), isNot(contains('wallet')));
    expect(jsonEncode(json), isNot(contains('signature')));
  });

  test('round-trips the event contract', () {
    final original = ProductTelemetryEvent(
      name: ProductTelemetryEventName.voiceTurnCompleted,
      occurredAt: occurredAt,
      properties: const <String, Object?>{
        'mode': 'continuous',
        'durationBucket': '10-30s',
      },
    );

    final restored = ProductTelemetryEvent.fromJson(original.toJson());

    expect(restored.name, original.name);
    expect(restored.occurredAt, original.occurredAt);
    expect(restored.properties, original.properties);
  });

  test('rejects sensitive or unapproved property names', () {
    for (final key in <String>[
      'prompt',
      'transcript',
      'walletAddress',
      'txHash',
      'signature',
      'apiKey',
      'rawPayload',
    ]) {
      expect(
        () => ProductTelemetryEvent(
          name: ProductTelemetryEventName.gatewayFailed,
          occurredAt: occurredAt,
          properties: <String, Object?>{key: 'blocked'},
        ),
        throwsArgumentError,
        reason: key,
      );
    }
  });

  test('rejects nested, negative, and oversized values', () {
    expect(
      () => ProductTelemetryEvent(
        name: ProductTelemetryEventName.gatewayFailed,
        occurredAt: occurredAt,
        properties: const <String, Object?>{
          'errorCode': <String>['not-allowed'],
        },
      ),
      throwsArgumentError,
    );
    expect(
      () => ProductTelemetryEvent(
        name: ProductTelemetryEventName.gatewayFailed,
        occurredAt: occurredAt,
        properties: const <String, Object?>{'feeScheduleVersion': -1},
      ),
      throwsArgumentError,
    );
    expect(
      () => ProductTelemetryEvent(
        name: ProductTelemetryEventName.gatewayFailed,
        occurredAt: occurredAt,
        properties: <String, Object?>{
          'errorCode': 'x' * 129,
        },
      ),
      throwsArgumentError,
    );
  });

  test('recorder does not send without consent', () async {
    var calls = 0;
    final recorder = ProductTelemetryRecorder(
      sender: (_) async => calls++,
    );

    await recorder.record(
      ProductTelemetryEvent(
        name: ProductTelemetryEventName.appFirstOpened,
        occurredAt: occurredAt,
      ),
    );

    expect(calls, 0);
  });

  test('recorder sends only after consent and swallows sender failure',
      () async {
    var calls = 0;
    final recorder = ProductTelemetryRecorder(
      consentGranted: true,
      sender: (_) async {
        calls++;
        throw StateError('analytics unavailable');
      },
    );

    await recorder.record(
      ProductTelemetryEvent(
        name: ProductTelemetryEventName.gatewayReady,
        occurredAt: occurredAt,
      ),
    );

    expect(calls, 1);
  });
}
