import 'dart:async';
import 'dart:convert';

import 'package:clawa/services/bridge/bridge_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('allows only exact HTTPS provider hosts and no alternate ports',
      () async {
    final service = BridgeHttpClient(client: MockClient((_) async {
      fail('blocked URI must not reach the client');
    }));

    for (final uri in <Uri>[
      Uri.parse('http://li.quest/v1/chains'),
      Uri.parse('https://evil.example/v1/chains'),
      Uri.parse('https://li.quest.evil.example/v1/chains'),
      Uri.parse('https://li.quest:444/v1/chains'),
      Uri.parse('https://user:pass@li.quest/v1/chains'),
    ]) {
      await expectLater(
        service.getJson(uri),
        throwsA(isA<BridgeHttpException>()
            .having((error) => error.code, 'code', 'host_not_allowed')),
      );
    }
  });

  test('sends bounded no-redirect JSON requests without credentials', () async {
    final service = BridgeHttpClient(client: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      expect(request.persistentConnection, isFalse);
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(request.headers.keys.join(','), isNot(contains('Authorization')));
      expect(jsonDecode(request.body), <String, Object?>{'amount': '1'});
      return http.Response(
        jsonEncode(<String, Object?>{'ok': true}),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
          'etag': '"catalog-v1"',
        },
      );
    }));

    final response = await service.postJson(
      Uri.parse('https://api.relay.link/quote'),
      <String, Object?>{'amount': '1'},
    );

    expect(response.json, <String, Object?>{'ok': true});
    expect(response.headers['etag'], '"catalog-v1"');
  });

  test('rejects redirects before following or parsing them', () async {
    final service = BridgeHttpClient(
        client: MockClient((_) async => http.Response('', 302,
            headers: {'location': 'https://evil.example'})));

    await expectLater(
      service.getJson(Uri.parse('https://li.quest/v1/chains')),
      throwsA(isA<BridgeHttpException>()
          .having((error) => error.code, 'code', 'redirect_rejected')),
    );
  });

  test('rejects oversized, non-JSON, and malformed responses', () async {
    Future<void> expectCode(http.Response response, String code) async {
      final service =
          BridgeHttpClient(client: MockClient((_) async => response));
      await expectLater(
        service.getJson(
          Uri.parse('https://li.quest/v1/chains'),
          maxBytes: 16,
        ),
        throwsA(isA<BridgeHttpException>()
            .having((error) => error.code, 'code', code)),
      );
    }

    await expectCode(
      http.Response(jsonEncode({'payload': 'x' * 64}), 200,
          headers: {'content-type': 'application/json'}),
      'response_too_large',
    );
    await expectCode(
      http.Response('<html></html>', 200,
          headers: {'content-type': 'text/html'}),
      'invalid_content_type',
    );
    await expectCode(
      http.Response('{broken', 200,
          headers: {'content-type': 'application/json'}),
      'invalid_json',
    );
  });

  test('maps request timeout without leaking the URL or body', () async {
    final service = BridgeHttpClient(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }),
    );

    await expectLater(
      service.postJson(
        Uri.parse('https://li.quest/v1/quote?secret=value'),
        <String, Object?>{'private': 'payload'},
      ),
      throwsA(
        isA<BridgeHttpException>()
            .having((error) => error.code, 'code', 'timeout')
            .having((error) => error.toString(), 'redaction',
                allOf(isNot(contains('secret')), isNot(contains('private')))),
      ),
    );
  });

  test('preserves retry-after on a bounded error response', () async {
    final service = BridgeHttpClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({'message': 'rate limited'}),
              429,
              headers: {
                'content-type': 'application/json',
                'retry-after': '12',
              },
            )));

    final response =
        await service.getJson(Uri.parse('https://api.relay.link/chains'));

    expect(response.statusCode, 429);
    expect(response.headers['retry-after'], '12');
  });
}
