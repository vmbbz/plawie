import 'package:clawa/services/gateway_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sessions.patch uses the upstream model field directly in params', () {
    final request = GatewayConnection.buildSessionPatchRequest(
      const {'model': 'openrouter/openrouter/free'},
      sessionKey: 'main',
    );

    expect(request['method'], 'sessions.patch');
    expect(request['params'], {
      'key': 'main',
      'model': 'openrouter/openrouter/free',
    });
    expect(
      (request['params'] as Map<String, dynamic>).containsKey('primaryModel'),
      isFalse,
    );
    expect(
      (request['params'] as Map<String, dynamic>).containsKey('patch'),
      isFalse,
    );
  });

  test('sessions.patch accepts current and legacy mutation acknowledgements',
      () {
    expect(
      GatewayConnection.isSessionPatchAcknowledged(
        const {'type': 'res', 'ok': true, 'payload': <String, dynamic>{}},
      ),
      isTrue,
    );
    expect(
      GatewayConnection.isSessionPatchAcknowledged(
        const {
          'type': 'res',
          'payload': {'ts': 1786580538180},
        },
      ),
      isTrue,
    );
  });

  test('sessions.patch fails closed for ambiguous or rejected responses', () {
    const rejected = <Map<String, dynamic>>[
      {
        'type': 'res',
        'ok': false,
        'payload': {'ts': 1786580538180}
      },
      {'type': 'res', 'error': 'model not allowed'},
      {'type': 'res', 'payload': <String, dynamic>{}},
      {
        'type': 'res',
        'payload': {'ts': 1786580538180, 'model': 'unexpected'}
      },
      {
        'type': 'res',
        'payload': {'ts': 0}
      },
      {
        'type': 'event',
        'payload': {'ts': 1786580538180}
      },
    ];

    for (final response in rejected) {
      expect(
        GatewayConnection.isSessionPatchAcknowledged(response),
        isFalse,
        reason: '$response must not authorize a provider request',
      );
    }
  });
}
