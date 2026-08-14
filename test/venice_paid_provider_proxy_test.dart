import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:clawa/services/paid_provider_http_client.dart';
import 'package:clawa/services/paid_provider_proxy_models.dart';
import 'package:clawa/services/paid_provider_proxy_service.dart';
import 'package:clawa/services/paid_provider_turn_authorization_service.dart';
import 'package:clawa/services/provider_balance_service.dart';
import 'package:clawa/services/venice_wallet_auth_service.dart';

void main() {
  const model = 'venice/llama-3.3-70b';
  final now = DateTime.utc(2026, 8, 6, 12);

  test('rejects inference before wallet auth when no foreground lease exists',
      () async {
    var authCalls = 0;
    final handler = VenicePaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        fail('upstream must not be called');
      })),
      walletAuth: _RecordingAuth(onAuthorize: (_, __) async {
        authCalls++;
        return 'identity';
      }),
      turnAuthorization: PaidProviderTurnAuthorizationService(
        clock: () => now,
      )..markAppForeground(),
      balances: _RecordingBalances(),
    );

    await expectLater(
      handler(_chatRequest(model)),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'foreground_turn_required',
        ),
      ),
    );
    expect(authCalls, 0);
    handler.close();
  });

  test('maps only the model and signs the exact Venice chat route', () async {
    late http.BaseRequest upstreamRequest;
    late Map<String, dynamic> upstreamBody;
    final leases = _authorized(now, model);
    final auth = _RecordingAuth(onAuthorize: (method, uri) async {
      expect(method, 'POST');
      expect(uri, Uri.parse('https://api.venice.ai/api/v1/chat/completions'));
      // Android wallet authentication can emit hidden/paused before returning
      // to the same activity. The already-authorized lease must survive that
      // native prompt, but it must not be usable while still backgrounded.
      leases.markAppBackground();
      leases.markAppForeground();
      return 'fresh-route-bound-identity';
    });
    final balances = _RecordingBalances();
    final handler = VenicePaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((request) async {
        upstreamRequest = request;
        upstreamBody = jsonDecode(
          utf8.decode(await request.finalize().toBytes()),
        ) as Map<String, dynamic>;
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('{"choices":[]}')),
          HttpStatus.ok,
          headers: {
            'content-type': 'application/json',
            'x-balance-remaining': '7.25',
          },
        );
      })),
      walletAuth: auth,
      turnAuthorization: leases,
      balances: balances,
    );

    final response = await handler(_chatRequest(model));
    final bytes = await response.openBodyStream().fold<List<int>>(
      <int>[],
      (all, chunk) => all..addAll(chunk),
    );
    await Future<void>.delayed(Duration.zero);

    expect(utf8.decode(bytes), '{"choices":[]}');
    expect(upstreamBody['model'], 'llama-3.3-70b');
    expect(upstreamBody['messages'][0]['content'], 'hello');
    expect(upstreamBody['tools'][0]['function']['name'], 'device.status');
    expect(
      upstreamRequest.headers['x-sign-in-with-x'],
      'fresh-route-bound-identity',
    );
    expect(upstreamRequest.headers, isNot(contains('sign-in-with-x')));
    expect(leases.activeLease?.remainingProxyCalls, 7);
    expect(balances.captured, ['7.25']);
    expect(balances.refreshes, ['venice']);
    handler.close();
  });

  test('preserves SSE tool-call bytes and refreshes only at terminal success',
      () async {
    final controller = StreamController<List<int>>();
    addTearDown(controller.close);
    final balances = _RecordingBalances();
    final handler = VenicePaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        scheduleMicrotask(() {
          controller.add(utf8.encode(
            'data: {"choices":[{"delta":{"tool_calls":[{"function":{"arguments":"{\\"x\\":1}"}}]}}]}\n\n',
          ));
        });
        return http.StreamedResponse(
          controller.stream,
          HttpStatus.ok,
          headers: {'content-type': 'text/event-stream'},
        );
      })),
      walletAuth: _RecordingAuth(),
      turnAuthorization: _authorized(now, model),
      balances: balances,
    );

    final response = await handler(_chatRequest(model, stream: true));
    final emitted = <int>[];
    final subscription = response.openBodyStream().listen(emitted.addAll);
    await Future<void>.delayed(Duration.zero);
    expect(balances.refreshes, isEmpty);
    controller.add(utf8.encode('data: [DONE]\n\n'));
    await controller.close();
    await subscription.asFuture<void>();
    await Future<void>.delayed(Duration.zero);

    expect(
      utf8.decode(emitted),
      contains('"tool_calls"'),
    );
    expect(utf8.decode(emitted), endsWith('data: [DONE]\n\n'));
    expect(balances.refreshes, ['venice']);
    handler.close();
  });

  test('wallet failure is stable and never reaches Venice', () async {
    var upstreamCalls = 0;
    final handler = VenicePaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        upstreamCalls++;
        return http.StreamedResponse(const Stream.empty(), 200);
      })),
      walletAuth: _RecordingAuth(onAuthorize: (_, __) async {
        throw const VeniceWalletAuthException(
          'wallet_not_ready',
          'A healthy wallet is required.',
        );
      }),
      turnAuthorization: _authorized(now, model),
      balances: _RecordingBalances(),
    );

    await expectLater(
      handler(_chatRequest(model)),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'wallet_not_ready',
        ),
      ),
    );
    expect(upstreamCalls, 0);
    handler.close();
  });

  test('relays upstream auth and provider errors without balance refresh',
      () async {
    for (final status in <int>[
      HttpStatus.unauthorized,
      HttpStatus.badGateway
    ]) {
      final balances = _RecordingBalances();
      final expected = utf8.encode('{"error":"upstream-$status"}');
      final handler = VenicePaidProviderProxyHandler(
        httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
          return http.StreamedResponse(
            Stream<List<int>>.value(expected),
            status,
            headers: {'content-type': 'application/json'},
          );
        })),
        walletAuth: _RecordingAuth(),
        turnAuthorization: _authorized(now, model),
        balances: balances,
      );

      final response = await handler(_chatRequest(model));
      final actual = await response.openBodyStream().fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      await Future<void>.delayed(Duration.zero);
      expect(response.statusCode, status);
      expect(actual, expected);
      expect(balances.refreshes, isEmpty);
      handler.close();
    }
  });

  test('balance refresh failure never changes a completed response', () async {
    final balances = _RecordingBalances(failRefresh: true);
    final handler = VenicePaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('{"ok":true}')),
          HttpStatus.ok,
          headers: {'content-type': 'application/json'},
        );
      })),
      walletAuth: _RecordingAuth(),
      turnAuthorization: _authorized(now, model),
      balances: balances,
    );

    final response = await handler(_chatRequest(model));
    final body = await response.openBodyStream().fold<List<int>>(
      <int>[],
      (all, chunk) => all..addAll(chunk),
    );
    await Future<void>.delayed(Duration.zero);

    expect(response.statusCode, HttpStatus.ok);
    expect(utf8.decode(body), '{"ok":true}');
    expect(balances.refreshes, ['venice']);
    handler.close();
  });
}

PaidProviderTurnAuthorizationService _authorized(
  DateTime now,
  String model,
) {
  final service = PaidProviderTurnAuthorizationService(
    clock: () => now,
    leaseIdFactory: () => 'lease-a',
  )..markAppForeground();
  service.authorizeForegroundUserTurn(
    conversationId: 'conversation-a',
    provider: PaidProviderId.venice,
    modelId: model,
  );
  return service;
}

PaidProviderProxyRequest _chatRequest(String model, {bool stream = false}) =>
    PaidProviderProxyRequest(
      provider: PaidProviderId.venice,
      route: PaidProviderProxyRoute.veniceChatCompletions,
      gatewayModelId: model,
      jsonBody: {
        'model': model.substring('venice/'.length),
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'tools': [
          {
            'type': 'function',
            'function': {'name': 'device.status'}
          },
        ],
        'stream': stream,
      },
    );

class _RecordingAuth extends VeniceWalletAuthService {
  _RecordingAuth({this.onAuthorize});

  final Future<String> Function(String method, Uri uri)? onAuthorize;

  @override
  Future<String> authorize(String method, Uri uri) =>
      onAuthorize?.call(method, uri) ?? Future<String>.value('identity');
}

class _RecordingBalances extends ProviderBalanceService {
  _RecordingBalances({this.failRefresh = false});

  final bool failRefresh;
  final List<String> captured = <String>[];
  final List<String> refreshes = <String>[];

  @override
  ProviderBalanceSnapshot? captureVeniceRemainingBalance(String value) {
    captured.add(value);
    return null;
  }

  @override
  Future<ProviderBalanceSnapshot> refresh(String providerId) async {
    refreshes.add(providerId);
    if (failRefresh) throw StateError('balance unavailable');
    return ProviderBalanceSnapshot(
      providerId: providerId,
      providerLabel: 'Venice',
      kind: ProviderBalanceKind.prepaidBalance,
      state: ProviderBalanceState.available,
      refreshedAt: DateTime.utc(2026, 8, 6),
      summary: 'available',
    );
  }
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._send);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
}
