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
}
