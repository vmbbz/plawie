import 'dart:convert';

import 'package:clawa/services/bridge/bridge_capability_service.dart';
import 'package:clawa/services/bridge/bridge_http_client.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesService preferences;
  final now = DateTime.utc(2026, 8, 7, 12);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = PreferencesService();
    await preferences.init();
  });

  setUp(() async {
    await preferences.setBridgeCapabilitySnapshotJson(null);
  });

  test('intersects live LI.FI and Relay catalogs with shipped capabilities',
      () async {
    final transport = _FixtureTransport();
    final service = BridgeCapabilityService(
      transport: transport,
      preferences: preferences,
      clock: () => now,
      lifiConnectedEnabled: true,
      relayDepositEnabled: true,
      reownEvmWalletsEnabled: true,
    );

    final snapshot = await service.refresh(internalBaseWalletAvailable: true);

    expect(
      snapshot.connectedChains.map((chain) => chain.id),
      containsAll(<int>[
        BridgeConstants.ethereumChainId,
        BridgeConstants.solanaChainId,
        BridgeConstants.baseChainId,
      ]),
    );
    final directBaseToken =
        snapshot.connectedTokensFor(BridgeConstants.baseChainId).single;
    expect(directBaseToken.address, BridgeConstants.baseUsdc);
    expect(directBaseToken.symbol, 'USDC');
    expect(
      snapshot
          .relayTokensFor(BridgeConstants.ethereumChainId)
          .map((token) => token.symbol),
      contains('USDC'),
    );
    expect(
      snapshot
          .relayTokensFor(BridgeConstants.ethereumChainId)
          .every((token) => token.solverDepositable),
      isTrue,
    );
    expect(
      snapshot
          .connectedTokensFor(BridgeConstants.robinhoodChainId)
          .map((token) => token.symbol),
      containsAll(<String>['ETH', 'USDG']),
    );
    final robinhoodUsdg = snapshot
        .connectedTokensFor(BridgeConstants.robinhoodChainId)
        .singleWhere((token) => token.symbol == 'USDG');
    expect(robinhoodUsdg.address, BridgeConstants.robinhoodUsdg);
    expect(
      snapshot.relayChains
          .any((chain) => chain.id == BridgeConstants.robinhoodChainId),
      isFalse,
    );
    expect(preferences.bridgeCapabilitySnapshotJson, isNotNull);
    expect(
      BridgeCapabilitySnapshot.fromJson(
          jsonDecode(preferences.bridgeCapabilitySnapshotJson!)
              as Map<String, dynamic>),
      snapshot,
    );
  });

  test('direct Base funding is independent of LI.FI but requires wallet gate',
      () async {
    final disabled = BridgeCapabilityService(
      transport: _ThrowingTransport(),
      preferences: preferences,
      clock: () => now,
      lifiConnectedEnabled: false,
      relayDepositEnabled: false,
      reownEvmWalletsEnabled: false,
    );
    final noWallet = await disabled.refresh(internalBaseWalletAvailable: true);
    expect(noWallet.connectedChains, isEmpty);

    final enabled = BridgeCapabilityService(
      transport: _ThrowingTransport(),
      preferences: preferences,
      clock: () => now,
      lifiConnectedEnabled: false,
      relayDepositEnabled: false,
      reownEvmWalletsEnabled: true,
    );
    final direct = await enabled.refresh(internalBaseWalletAvailable: true);
    expect(
        direct.connectedTokensFor(BridgeConstants.baseChainId), hasLength(1));
    expect(direct.availabilityReasons['direct_base'], isNull);
  });

  test('rejects disabled lagging and non-deposit Relay chains', () async {
    final service = BridgeCapabilityService(
      transport: _FixtureTransport(relayAllUnavailable: true),
      preferences: preferences,
      clock: () => now,
      lifiConnectedEnabled: false,
      relayDepositEnabled: true,
      reownEvmWalletsEnabled: false,
    );

    final snapshot = await service.refresh(internalBaseWalletAvailable: false);

    expect(snapshot.relayChains, isEmpty);
    expect(snapshot.availabilityReasons['relay'], isNotEmpty);
  });

  test('uses a fresh persisted display when live refresh fails', () async {
    final first = BridgeCapabilityService(
      transport: _FixtureTransport(),
      preferences: preferences,
      clock: () => now,
      lifiConnectedEnabled: true,
      relayDepositEnabled: true,
      reownEvmWalletsEnabled: true,
    );
    final live = await first.refresh(internalBaseWalletAvailable: true);

    final fallback = BridgeCapabilityService(
      transport: _ThrowingTransport(),
      preferences: preferences,
      clock: () => now.add(const Duration(minutes: 5)),
      lifiConnectedEnabled: true,
      relayDepositEnabled: true,
      reownEvmWalletsEnabled: true,
    );
    final cached = await fallback.refresh(internalBaseWalletAvailable: true);

    expect(cached.connectedChains, live.connectedChains);
    expect(cached.relayChains, live.relayChains);
    expect(cached.availabilityReasons['execution'], contains('live quote'));
  });
}

final class _FixtureTransport implements BridgeHttpTransport {
  _FixtureTransport({this.relayAllUnavailable = false});

  final bool relayAllUnavailable;

  @override
  Future<BridgeHttpResponse> getJson(
    Uri uri, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (uri.host == 'li.quest' && uri.path == '/v1/chains') {
      return _ok({
        'chains': [
          {'id': 1, 'key': 'eth', 'name': 'Ethereum', 'chainType': 'EVM'},
          {
            'id': BridgeConstants.solanaChainId,
            'key': 'sol',
            'name': 'Solana',
            'chainType': 'SVM',
          },
          {
            'id': BridgeConstants.robinhoodChainId,
            'key': 'out',
            'name': 'Robinhood Chain',
            'chainType': 'EVM',
          },
          {'id': 8453, 'key': 'bas', 'name': 'Base', 'chainType': 'EVM'},
        ],
      });
    }
    if (uri.host == 'li.quest' && uri.path == '/v1/token') {
      final chain = int.parse(uri.queryParameters['chain']!);
      final token = uri.queryParameters['token']!;
      if (chain == 8453) {
        return _token(chain, BridgeConstants.baseUsdc, 'USDC', 6);
      }
      if (chain == BridgeConstants.ethereumChainId && token == 'ETH') {
        return _token(chain, _zeroAddress, 'ETH', 18);
      }
      if (chain == BridgeConstants.ethereumChainId && token == 'USDC') {
        return _token(chain, _ethereumUsdc, 'USDC', 6);
      }
      if (chain == BridgeConstants.solanaChainId && token == 'SOL') {
        return _token(chain, _solAddress, 'SOL', 9);
      }
      if (chain == BridgeConstants.solanaChainId && token == 'USDC') {
        return _token(chain, _solUsdc, 'USDC', 6);
      }
      if (chain == BridgeConstants.robinhoodChainId && token == 'ETH') {
        return _token(chain, _zeroAddress, 'ETH', 18);
      }
      if (chain == BridgeConstants.robinhoodChainId &&
          token.toLowerCase() == BridgeConstants.robinhoodUsdg.toLowerCase()) {
        return _token(chain, BridgeConstants.robinhoodUsdg, 'USDG', 6);
      }
      return const BridgeHttpResponse(
        statusCode: 404,
        headers: <String, String>{},
        json: <String, Object?>{},
      );
    }
    if (uri.host == 'li.quest' && uri.path == '/v1/connections') {
      return _ok({
        'connections': [
          {
            'fromChainId': int.parse(uri.queryParameters['fromChain']!),
            'toChainId': 8453,
            'fromTokens': [
              {
                'chainId': int.parse(uri.queryParameters['fromChain']!),
                'address': uri.queryParameters['fromToken'],
              },
            ],
            'toTokens': [
              {'chainId': 8453, 'address': BridgeConstants.baseUsdc},
            ],
          },
        ],
      });
    }
    if (uri.host == 'api.relay.link' && uri.path == '/chains') {
      return _ok({
        'chains': [
          {
            'id': 1,
            'name': 'ethereum',
            'disabled': relayAllUnavailable,
            'blockProductionLagging': false,
            'depositEnabled': true,
            'solverCurrencies': [
              {
                'symbol': 'USDC',
                'address': _ethereumUsdc,
                'decimals': 6,
              },
            ],
          },
          {
            'id': BridgeConstants.robinhoodChainId,
            'name': 'robinhood',
            'disabled': false,
            'blockProductionLagging': true,
            'depositEnabled': true,
            'solverCurrencies': [
              {'symbol': 'ETH', 'address': _zeroAddress, 'decimals': 18},
            ],
          },
        ],
      });
    }
    throw StateError('Unexpected fixture request: $uri');
  }

  @override
  Future<BridgeHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) =>
      throw UnimplementedError();

  BridgeHttpResponse _ok(Object json) => BridgeHttpResponse(
        statusCode: 200,
        headers: const <String, String>{'etag': '"fixture-v1"'},
        json: json,
      );

  BridgeHttpResponse _token(
          int chainId, String address, String symbol, int decimals) =>
      _ok({
        'chainId': chainId,
        'address': address,
        'symbol': symbol,
        'decimals': decimals,
      });
}

final class _ThrowingTransport implements BridgeHttpTransport {
  @override
  Future<BridgeHttpResponse> getJson(
    Uri uri, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) =>
      throw const BridgeHttpException('offline');

  @override
  Future<BridgeHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) =>
      throw const BridgeHttpException('offline');
}

const _zeroAddress = '0x0000000000000000000000000000000000000000';
const _ethereumUsdc = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const _solAddress = '11111111111111111111111111111111';
const _solUsdc = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
