import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/paid_provider_loopback_credential_service.dart';

void main() {
  test('issues a process-local 256-bit base64url capability', () {
    final service = PaidProviderLoopbackCredentialService(
      randomBytes: (length) => Uint8List.fromList(
        List<int>.generate(length, (index) => index),
      ),
    );

    final credential = service.credentialForGatewayConfiguration();

    expect(credential, hasLength(43));
    expect(credential, isNot(contains('=')));
    expect(
      service.matchesAuthorizationHeader('Bearer $credential'),
      isTrue,
    );
    expect(service.toString(), isNot(contains(credential)));
  });

  test('rejects missing, malformed, and incorrect authorization', () {
    final service = PaidProviderLoopbackCredentialService();
    final credential = service.credentialForGatewayConfiguration();

    expect(service.matchesAuthorizationHeader(null), isFalse);
    expect(service.matchesAuthorizationHeader(''), isFalse);
    expect(service.matchesAuthorizationHeader(credential), isFalse);
    expect(service.matchesAuthorizationHeader('Basic $credential'), isFalse);
    expect(
      service.matchesAuthorizationHeader('Bearer ${credential}x'),
      isFalse,
    );
  });

  test('rotation is blocked while the gateway or proxy is running', () {
    final service = PaidProviderLoopbackCredentialService();
    final before = service.credentialForGatewayConfiguration();

    expect(
      () => service.rotate(gatewayStopped: false, proxyStopped: true),
      throwsStateError,
    );
    expect(
      () => service.rotate(gatewayStopped: true, proxyStopped: false),
      throwsStateError,
    );
    expect(service.credentialForGatewayConfiguration(), before);

    service.rotate(gatewayStopped: true, proxyStopped: true);
    expect(service.credentialForGatewayConfiguration(), isNot(before));
  });
}
