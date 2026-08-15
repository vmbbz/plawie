import 'package:clawa/services/gateway_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts a token from an OpenClaw dashboard fragment', () {
    expect(
      GatewayService.extractGatewayTokenFromDashboardUrl(
        'http://127.0.0.1:18789/#token=fragment-secret',
      ),
      'fragment-secret',
    );
  });

  test('extracts a token from a query URL for legacy integrations', () {
    expect(
      GatewayService.extractGatewayTokenFromDashboardUrl(
        'http://127.0.0.1:18789/?token=query-secret',
      ),
      'query-secret',
    );
  });

  test(
    'does not invent an auth token for an unauthenticated local Gateway',
    () {
      expect(
        GatewayService.extractGatewayTokenFromDashboardUrl(
          'http://127.0.0.1:18789/',
        ),
        isNull,
      );
    },
  );
}
