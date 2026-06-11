import 'package:clawa/services/gateway_url_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips dashboard auth token from displayed URL fragment', () {
    expect(
      gatewayDisplayUrl('http://127.0.0.1:18789/#token=secret-token'),
      'http://127.0.0.1:18789/',
    );
  });

  test('strips dashboard auth token from displayed URL query', () {
    expect(
      gatewayDisplayUrl('http://127.0.0.1:18789/?token=secret-token'),
      'http://127.0.0.1:18789/',
    );
  });

  test('keeps non-token dashboard URL details visible', () {
    expect(
      gatewayDisplayUrl('http://127.0.0.1:18789/status?view=compact'),
      'http://127.0.0.1:18789/status?view=compact',
    );
  });
}
