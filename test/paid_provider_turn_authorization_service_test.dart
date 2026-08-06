import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/paid_provider_proxy_models.dart';
import 'package:clawa/services/paid_provider_turn_authorization_service.dart';

void main() {
  final start = DateTime.utc(2026, 8, 6, 12);

  test('only foreground UI can open a model-bound Venice turn lease', () {
    var now = start;
    final service = PaidProviderTurnAuthorizationService(
      clock: () => now,
      leaseIdFactory: () => 'lease-a',
    );

    expect(
      () => service.authorizeForegroundUserTurn(
        conversationId: 'conversation-a',
        provider: PaidProviderId.venice,
        modelId: 'venice/llama-3.3-70b',
      ),
      throwsA(
        isA<PaidProviderTurnAuthorizationException>().having(
          (error) => error.code,
          'code',
          'app_not_foreground',
        ),
      ),
    );

    service.markAppForeground();
    final lease = service.authorizeForegroundUserTurn(
      conversationId: 'conversation-a',
      provider: PaidProviderId.venice,
      modelId: 'venice/llama-3.3-70b',
    );

    expect(lease.leaseId, 'lease-a');
    expect(lease.conversationId, 'conversation-a');
    expect(lease.remainingProxyCalls, 8);
    expect(lease.expiresAt, start.add(const Duration(minutes: 10)));

    final consumed = service.consumeForProxy(
      provider: PaidProviderId.venice,
      gatewayModelId: 'venice/llama-3.3-70b',
    );
    expect(consumed.remainingProxyCalls, 7);

    now = start.add(const Duration(minutes: 11));
    expect(
      () => service.consumeForProxy(
        provider: PaidProviderId.venice,
        gatewayModelId: 'venice/llama-3.3-70b',
      ),
      throwsA(
        isA<PaidProviderTurnAuthorizationException>().having(
          (error) => error.code,
          'code',
          'foreground_turn_expired',
        ),
      ),
    );
  });

  test('lease rejects another model and closes immediately on background', () {
    final service = PaidProviderTurnAuthorizationService(
      clock: () => start,
      leaseIdFactory: () => 'lease-a',
    )..markAppForeground();
    service.authorizeForegroundUserTurn(
      conversationId: 'conversation-a',
      provider: PaidProviderId.venice,
      modelId: 'venice/model-a',
    );

    expect(
      () => service.consumeForProxy(
        provider: PaidProviderId.venice,
        gatewayModelId: 'venice/model-b',
      ),
      throwsA(
        isA<PaidProviderTurnAuthorizationException>().having(
          (error) => error.code,
          'code',
          'foreground_turn_mismatch',
        ),
      ),
    );

    service.markAppBackground();
    expect(service.activeLease, isNull);
    expect(
      () => service.consumeForProxy(
        provider: PaidProviderId.venice,
        gatewayModelId: 'venice/model-a',
      ),
      throwsA(
        isA<PaidProviderTurnAuthorizationException>().having(
          (error) => error.code,
          'code',
          'foreground_turn_required',
        ),
      ),
    );
  });

  test('eighth proxy call is allowed and ninth is rejected', () {
    final service = PaidProviderTurnAuthorizationService(
      clock: () => start,
      leaseIdFactory: () => 'lease-a',
    )..markAppForeground();
    service.authorizeForegroundUserTurn(
      conversationId: 'conversation-a',
      provider: PaidProviderId.venice,
      modelId: 'venice/model-a',
    );

    for (var index = 0; index < 8; index++) {
      service.consumeForProxy(
        provider: PaidProviderId.venice,
        gatewayModelId: 'venice/model-a',
      );
    }
    expect(service.activeLease?.remainingProxyCalls, 0);
    expect(
      () => service.consumeForProxy(
        provider: PaidProviderId.venice,
        gatewayModelId: 'venice/model-a',
      ),
      throwsA(
        isA<PaidProviderTurnAuthorizationException>().having(
          (error) => error.code,
          'code',
          'foreground_turn_exhausted',
        ),
      ),
    );
  });

  test('runtime closes only the exact lease it received', () {
    var nextId = 0;
    final service = PaidProviderTurnAuthorizationService(
      clock: () => start,
      leaseIdFactory: () => 'lease-${++nextId}',
    )..markAppForeground();
    final first = service.authorizeForegroundUserTurn(
      conversationId: 'conversation-a',
      provider: PaidProviderId.venice,
      modelId: 'venice/model-a',
    );
    final second = service.authorizeForegroundUserTurn(
      conversationId: 'conversation-b',
      provider: PaidProviderId.venice,
      modelId: 'venice/model-b',
    );

    service.closeLease(first.leaseId);
    expect(service.activeLease?.leaseId, second.leaseId);
    service.closeLease(second.leaseId);
    expect(service.activeLease, isNull);
  });
}
