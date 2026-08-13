import 'package:clawa/services/paid_provider_proxy_models.dart';
import 'package:clawa/services/paid_provider_tool_probe_authorization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permit is exact-provider, exact-model, bounded, and closable', () {
    final authorization = PaidProviderToolProbeAuthorization(maxRequests: 2);
    authorization.authorize(
      provider: PaidProviderId.venice,
      modelId: 'venice/gemma-4-uncensored',
    );

    expect(
      authorization.consumeIfAuthorized(
        provider: PaidProviderId.blockrun,
        modelId: 'blockrun/gemma-4-uncensored',
      ),
      isFalse,
    );
    expect(
      authorization.consumeIfAuthorized(
        provider: PaidProviderId.venice,
        modelId: 'venice/another-model',
      ),
      isFalse,
    );
    expect(
      authorization.consumeIfAuthorized(
        provider: PaidProviderId.venice,
        modelId: 'venice/gemma-4-uncensored',
      ),
      isTrue,
    );
    expect(
      authorization.consumeIfAuthorized(
        provider: PaidProviderId.venice,
        modelId: 'venice/gemma-4-uncensored',
      ),
      isTrue,
    );
    expect(
      authorization.consumeIfAuthorized(
        provider: PaidProviderId.venice,
        modelId: 'venice/gemma-4-uncensored',
      ),
      isFalse,
    );
  });

  test('expired and explicitly closed permits cannot be consumed', () {
    var now = DateTime.utc(2026, 8, 13, 12);
    final authorization = PaidProviderToolProbeAuthorization(
      clock: () => now,
      lifetime: const Duration(minutes: 1),
    );
    authorization.authorize(
      provider: PaidProviderId.venice,
      modelId: 'venice/gemma-4-uncensored',
    );
    now = now.add(const Duration(minutes: 2));
    expect(
      authorization.consumeIfAuthorized(
        provider: PaidProviderId.venice,
        modelId: 'venice/gemma-4-uncensored',
      ),
      isFalse,
    );

    authorization.authorize(
      provider: PaidProviderId.venice,
      modelId: 'venice/gemma-4-uncensored',
    );
    authorization.close(
      provider: PaidProviderId.venice,
      modelId: 'venice/gemma-4-uncensored',
    );
    expect(
      authorization.consumeIfAuthorized(
        provider: PaidProviderId.venice,
        modelId: 'venice/gemma-4-uncensored',
      ),
      isFalse,
    );
  });

  test('invalid cross-provider model identity is rejected', () {
    final authorization = PaidProviderToolProbeAuthorization();
    expect(
      () => authorization.authorize(
        provider: PaidProviderId.venice,
        modelId: 'blockrun/gemma-4-uncensored',
      ),
      throwsArgumentError,
    );
  });
}
