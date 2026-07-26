import 'package:clawa/services/gateway_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Talk timeout and provider unavailability are transient failures', () {
    final gateway = GatewayService();

    expect(
      gateway.debugTalkSpeakFailureClassForTesting(
        'TimeoutException after 0:00:30 Future not completed',
      ),
      'transient',
    );
    expect(
      gateway.debugTalkSpeakFailureClassForTesting(
        'UNAVAILABLE TTS conversion failed: microsoft: Timed out',
      ),
      'transient',
    );
  });

  test('Talk configuration and account failures remain distinct', () {
    final gateway = GatewayService();

    expect(
      gateway.debugTalkSpeakFailureClassForTesting(
        'talk provider not configured',
      ),
      'configuration',
    );
    expect(
      gateway.debugTalkSpeakFailureClassForTesting(
        'HTTP 402 insufficient credits',
      ),
      'provider_account',
    );
    expect(
      gateway.debugTalkSpeakFailureClassForTesting('unknown method talk.speak'),
      'method_unavailable',
    );
  });
}
