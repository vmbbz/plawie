import 'dart:convert';

import '../preferences_service.dart';
import 'bridge_http_client.dart';
import 'bridge_models.dart';

final class BridgeCapabilityService {
  BridgeCapabilityService({
    required BridgeHttpTransport transport,
    required PreferencesService preferences,
    DateTime Function()? clock,
    this.lifiConnectedEnabled = BridgeFeatureConfig.lifiConnectedEnabled,
    this.relayDepositEnabled = BridgeFeatureConfig.relayDepositEnabled,
    this.reownEvmWalletsEnabled = BridgeFeatureConfig.reownEvmWalletsEnabled,
  })  : _transport = transport,
        _preferences = preferences,
        _clock = clock ?? DateTime.now;

  static const int schemaVersion = 1;
  static const Duration freshness = Duration(minutes: 10);

  final BridgeHttpTransport _transport;
  final PreferencesService _preferences;
  final DateTime Function() _clock;
  final bool lifiConnectedEnabled;
  final bool relayDepositEnabled;
  final bool reownEvmWalletsEnabled;

  BridgeCapabilitySnapshot? _memorySnapshot;
  bool? _memoryInternalWalletAvailable;
  String? _lifiEtag;
  String? _relayEtag;

  BridgeCapabilitySnapshot? get cachedSnapshot {
    final raw = _preferences.bridgeCapabilitySnapshotJson;
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final snapshot = BridgeCapabilitySnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return snapshot.schemaVersion == schemaVersion ? snapshot : null;
    } catch (_) {
      return null;
    }
  }

  Future<BridgeCapabilitySnapshot> refresh({
    required bool internalBaseWalletAvailable,
  }) async {
    final now = _clock().toUtc();
    final memory = _memorySnapshot;
    if (memory != null &&
        _memoryInternalWalletAvailable == internalBaseWalletAvailable &&
        now.difference(memory.refreshedAt) < freshness) {
      return memory;
    }

    final cached = cachedSnapshot;
    final cachedIsFresh = cached != null &&
        !now.isBefore(cached.refreshedAt) &&
        now.difference(cached.refreshedAt) < freshness;
    final results =
        await Future.wait<_ProviderCatalog>(<Future<_ProviderCatalog>>[
      lifiConnectedEnabled
          ? _guardProvider('lifi', () => _loadLifi(cached))
          : Future<_ProviderCatalog>.value(
              const _ProviderCatalog(
                  reason: 'LI.FI connected funding is disabled.'),
            ),
      relayDepositEnabled
          ? _guardProvider('relay', () => _loadRelay(cached))
          : Future<_ProviderCatalog>.value(
              const _ProviderCatalog(
                  reason: 'Relay deposit funding is disabled.'),
            ),
    ]);

    var lifi = results[0];
    var relay = results[1];
    var usedFallback = false;
    if (lifi.failed && cachedIsFresh && lifiConnectedEnabled) {
      lifi = _ProviderCatalog(
        connectedChains: cached.connectedChains
            .where((chain) => chain.id != BridgeConstants.baseChainId)
            .toList(),
        connectedTokens: <int, List<BridgeToken>>{
          for (final entry in cached.connectedTokensByChain.entries)
            if (entry.key != BridgeConstants.baseChainId)
              entry.key: entry.value,
        },
        reason: lifi.reason,
        failed: true,
      );
      usedFallback = true;
    }
    if (relay.failed && cachedIsFresh && relayDepositEnabled) {
      relay = _ProviderCatalog(
        relayChains: cached.relayChains,
        relayTokens: cached.relayTokensByChain,
        reason: relay.reason,
        failed: true,
      );
      usedFallback = true;
    }

    final connectedChains = <BridgeChain>[...lifi.connectedChains];
    final connectedTokens = <int, List<BridgeToken>>{
      ...lifi.connectedTokens,
    };
    final reasons = <String, String>{};
    if (lifi.reason != null) reasons['lifi'] = lifi.reason!;
    if (relay.reason != null) reasons['relay'] = relay.reason!;

    if (reownEvmWalletsEnabled && internalBaseWalletAvailable) {
      connectedChains.removeWhere(
        (chain) => chain.id == BridgeConstants.baseChainId,
      );
      connectedChains.add(_trustedChains[BridgeConstants.baseChainId]!);
      connectedTokens[BridgeConstants.baseChainId] = const <BridgeToken>[
        BridgeToken(
          chainId: BridgeConstants.baseChainId,
          address: BridgeConstants.baseUsdc,
          symbol: 'USDC',
          decimals: 6,
          solverDepositable: false,
        ),
      ];
    } else {
      reasons['direct_base'] = reownEvmWalletsEnabled
          ? 'Create or restore the internal Base wallet first.'
          : 'Compatible EVM wallets are disabled in this release.';
    }
    if (usedFallback) {
      reasons['execution'] =
          'Cached capabilities are display-only; a live quote is required before execution.';
    }

    connectedChains.sort((left, right) => left.id.compareTo(right.id));
    final relayChains = <BridgeChain>[...relay.relayChains]
      ..sort((left, right) => left.id.compareTo(right.id));
    final snapshot = BridgeCapabilitySnapshot(
      schemaVersion: schemaVersion,
      refreshedAt: usedFallback ? cached!.refreshedAt : now,
      connectedChains: List<BridgeChain>.unmodifiable(connectedChains),
      relayChains: List<BridgeChain>.unmodifiable(relayChains),
      connectedTokensByChain: _freezeTokenMap(connectedTokens),
      relayTokensByChain: _freezeTokenMap(relay.relayTokens),
      availabilityReasons: Map<String, String>.unmodifiable(reasons),
    );
    _memorySnapshot = snapshot;
    _memoryInternalWalletAvailable = internalBaseWalletAvailable;
    if (!usedFallback) {
      final saved = await _preferences.setBridgeCapabilitySnapshotJson(
        jsonEncode(snapshot.toJson()),
      );
      if (!saved) {
        throw const BridgePersistenceException(
          'Could not persist the bridge capability snapshot.',
        );
      }
    }
    return snapshot;
  }

  Future<_ProviderCatalog> _guardProvider(
    String provider,
    Future<_ProviderCatalog> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (_) {
      return _ProviderCatalog(
        failed: true,
        reason: '$provider capabilities could not be refreshed.',
      );
    }
  }

  Future<_ProviderCatalog> _loadLifi(
    BridgeCapabilitySnapshot? cached,
  ) async {
    final headers = _lifiEtag == null
        ? const <String, String>{}
        : <String, String>{'If-None-Match': _lifiEtag!};
    final chainResponse = await _transport.getJson(
      Uri.https('li.quest', '/v1/chains', <String, String>{
        'chainTypes': 'EVM,SVM',
      }),
      headers: headers,
    );
    if (chainResponse.statusCode == 304 && cached != null) {
      return _ProviderCatalog(
        connectedChains: cached.connectedChains
            .where((chain) => chain.id != BridgeConstants.baseChainId)
            .toList(),
        connectedTokens: <int, List<BridgeToken>>{
          for (final entry in cached.connectedTokensByChain.entries)
            if (entry.key != BridgeConstants.baseChainId)
              entry.key: entry.value,
        },
      );
    }
    _requireOk(chainResponse, 'lifi_chains');
    _lifiEtag = chainResponse.headers['etag'];
    final root = _asMap(chainResponse.json, 'lifi_chains');
    final rawChains = root['chains'];
    if (rawChains is! List) {
      throw const BridgeValidationException('invalid_lifi_chains');
    }
    final liveIds = <int>{};
    for (final raw in rawChains) {
      if (raw is! Map || raw['mainnet'] == false) continue;
      final id = raw['id'];
      if (id is num && _trustedChains.containsKey(id.toInt())) {
        liveIds.add(id.toInt());
      }
    }
    if (!liveIds.contains(BridgeConstants.baseChainId)) {
      throw const BridgeValidationException('lifi_base_unavailable');
    }
    final baseUsdc = await _resolveLifiToken(
      BridgeConstants.baseChainId,
      BridgeConstants.baseUsdc,
      expectedSymbol: 'USDC',
    );
    if (baseUsdc == null ||
        !_sameEvm(baseUsdc.address, BridgeConstants.baseUsdc)) {
      throw const BridgeValidationException('invalid_base_usdc');
    }

    final chains = <BridgeChain>[];
    final tokens = <int, List<BridgeToken>>{};
    for (final id in _lifiSourceChainIds) {
      if (!liveIds.contains(id)) continue;
      final chain = _trustedChains[id]!;
      final candidates = <String>{chain.nativeTokenSymbol, 'USDC'};
      final supported = <BridgeToken>[];
      for (final symbol in candidates) {
        final token =
            await _resolveLifiToken(id, symbol, expectedSymbol: symbol);
        if (token == null) continue;
        if (await _hasLifiConnection(chain, token, baseUsdc)) {
          supported.add(token);
        }
      }
      if (supported.isNotEmpty) {
        chains.add(chain);
        tokens[id] = supported;
      }
    }
    return _ProviderCatalog(
      connectedChains: chains,
      connectedTokens: tokens,
      reason:
          chains.isEmpty ? 'LI.FI advertises no trusted source route.' : null,
    );
  }

  Future<BridgeToken?> _resolveLifiToken(
    int chainId,
    String token, {
    required String expectedSymbol,
  }) async {
    final response = await _transport.getJson(
      Uri.https('li.quest', '/v1/token', <String, String>{
        'chain': chainId.toString(),
        'token': token,
      }),
    );
    if (response.statusCode == 404) return null;
    _requireOk(response, 'lifi_token');
    final json = _asMap(response.json, 'lifi_token');
    final resolvedChain = json['chainId'];
    final address = json['address']?.toString() ?? '';
    final symbol = json['symbol']?.toString().toUpperCase() ?? '';
    final decimals = json['decimals'];
    final chain = _trustedChains[chainId];
    if (chain == null ||
        resolvedChain is! num ||
        resolvedChain.toInt() != chainId ||
        symbol != expectedSymbol.toUpperCase() ||
        decimals is! num ||
        decimals.toInt() < 0 ||
        decimals.toInt() > 36 ||
        !_validAddress(address, chain.type)) {
      throw const BridgeValidationException('invalid_lifi_token');
    }
    return BridgeToken(
      chainId: chainId,
      address: address,
      symbol: symbol,
      decimals: decimals.toInt(),
      solverDepositable: false,
    );
  }

  Future<bool> _hasLifiConnection(
    BridgeChain source,
    BridgeToken fromToken,
    BridgeToken baseUsdc,
  ) async {
    final response = await _transport.getJson(
      Uri.https('li.quest', '/v1/connections', <String, String>{
        'fromChain': source.id.toString(),
        'toChain': BridgeConstants.baseChainId.toString(),
        'fromToken': fromToken.address,
        'toToken': baseUsdc.address,
        'chainTypes': 'EVM,SVM',
        'allowDestinationCall': 'false',
      }),
    );
    if (response.statusCode != 200) return false;
    final root = _asMap(response.json, 'lifi_connections');
    final connections = root['connections'];
    if (connections is! List) return false;
    return connections.any((raw) {
      if (raw is! Map) return false;
      return (raw['fromChainId'] as num?)?.toInt() == source.id &&
          (raw['toChainId'] as num?)?.toInt() == BridgeConstants.baseChainId &&
          _tokenListContains(raw['fromTokens'], fromToken, source.type) &&
          _tokenListContains(raw['toTokens'], baseUsdc, BridgeChainType.evm);
    });
  }

  Future<_ProviderCatalog> _loadRelay(
    BridgeCapabilitySnapshot? cached,
  ) async {
    final headers = _relayEtag == null
        ? const <String, String>{}
        : <String, String>{'If-None-Match': _relayEtag!};
    final response = await _transport.getJson(
      Uri.https('api.relay.link', '/chains'),
      headers: headers,
    );
    if (response.statusCode == 304 && cached != null) {
      return _ProviderCatalog(
        relayChains: cached.relayChains,
        relayTokens: cached.relayTokensByChain,
      );
    }
    _requireOk(response, 'relay_chains');
    _relayEtag = response.headers['etag'];
    final root = _asMap(response.json, 'relay_chains');
    final rawChains = root['chains'];
    if (rawChains is! List) {
      throw const BridgeValidationException('invalid_relay_chains');
    }
    final chains = <BridgeChain>[];
    final tokens = <int, List<BridgeToken>>{};
    for (final raw in rawChains) {
      if (raw is! Map) continue;
      final id = (raw['id'] as num?)?.toInt();
      final chain = id == null ? null : _trustedChains[id];
      if (chain == null ||
          !_relaySourceChainIds.contains(id) ||
          raw['disabled'] == true ||
          raw['blockProductionLagging'] == true ||
          raw['depositEnabled'] != true) {
        continue;
      }
      final rawCurrencies = raw['solverCurrencies'];
      if (rawCurrencies is! List || rawCurrencies.isEmpty) continue;
      final supported = <BridgeToken>[];
      for (final item in rawCurrencies) {
        if (item is! Map) continue;
        final address = item['address']?.toString() ?? '';
        final symbol = item['symbol']?.toString().trim() ?? '';
        final decimals = item['decimals'];
        if (symbol.isEmpty ||
            decimals is! num ||
            decimals.toInt() < 0 ||
            decimals.toInt() > 36 ||
            !_validAddress(address, chain.type)) {
          continue;
        }
        supported.add(BridgeToken(
          chainId: id!,
          address: address,
          symbol: symbol,
          decimals: decimals.toInt(),
          solverDepositable: true,
        ));
      }
      if (supported.isNotEmpty) {
        chains.add(chain);
        tokens[id!] = supported;
      }
    }
    return _ProviderCatalog(
      relayChains: chains,
      relayTokens: tokens,
      reason: chains.isEmpty
          ? 'Relay advertises no trusted solver-depositable source.'
          : null,
    );
  }
}

final class _ProviderCatalog {
  const _ProviderCatalog({
    this.connectedChains = const <BridgeChain>[],
    this.relayChains = const <BridgeChain>[],
    this.connectedTokens = const <int, List<BridgeToken>>{},
    this.relayTokens = const <int, List<BridgeToken>>{},
    this.reason,
    this.failed = false,
  });

  final List<BridgeChain> connectedChains;
  final List<BridgeChain> relayChains;
  final Map<int, List<BridgeToken>> connectedTokens;
  final Map<int, List<BridgeToken>> relayTokens;
  final String? reason;
  final bool failed;
}

const _trustedChains = <int, BridgeChain>{
  BridgeConstants.ethereumChainId: BridgeChain(
    id: BridgeConstants.ethereumChainId,
    key: 'eth',
    name: 'Ethereum',
    type: BridgeChainType.evm,
    nativeTokenSymbol: 'ETH',
  ),
  BridgeConstants.solanaChainId: BridgeChain(
    id: BridgeConstants.solanaChainId,
    key: 'sol',
    name: 'Solana',
    type: BridgeChainType.svm,
    nativeTokenSymbol: 'SOL',
  ),
  BridgeConstants.robinhoodChainId: BridgeChain(
    id: BridgeConstants.robinhoodChainId,
    key: 'out',
    name: 'Robinhood Chain',
    type: BridgeChainType.evm,
    nativeTokenSymbol: 'ETH',
  ),
  BridgeConstants.baseChainId: BridgeChain(
    id: BridgeConstants.baseChainId,
    key: 'bas',
    name: 'Base',
    type: BridgeChainType.evm,
    nativeTokenSymbol: 'ETH',
  ),
};

const _lifiSourceChainIds = <int>{
  BridgeConstants.ethereumChainId,
  BridgeConstants.solanaChainId,
  BridgeConstants.robinhoodChainId,
};
const _relaySourceChainIds = _lifiSourceChainIds;

Map<int, List<BridgeToken>> _freezeTokenMap(
  Map<int, List<BridgeToken>> source,
) =>
    Map<int, List<BridgeToken>>.unmodifiable(<int, List<BridgeToken>>{
      for (final entry in source.entries)
        entry.key: List<BridgeToken>.unmodifiable(entry.value),
    });

Map<String, dynamic> _asMap(Object? raw, String code) {
  if (raw is! Map) throw BridgeValidationException('invalid_$code');
  return Map<String, dynamic>.from(raw);
}

void _requireOk(BridgeHttpResponse response, String code) {
  if (response.statusCode != 200) {
    throw BridgeValidationException('${code}_http_${response.statusCode}');
  }
}

bool _tokenListContains(
  Object? raw,
  BridgeToken token,
  BridgeChainType type,
) {
  if (raw is! List) return false;
  return raw.any((item) {
    if (item is! Map) return false;
    return (item['chainId'] as num?)?.toInt() == token.chainId &&
        _sameAddress(item['address']?.toString() ?? '', token.address, type);
  });
}

bool _validAddress(String value, BridgeChainType type) => switch (type) {
      BridgeChainType.evm => RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value),
      BridgeChainType.svm =>
        RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(value),
    };

bool _sameAddress(String left, String right, BridgeChainType type) =>
    type == BridgeChainType.evm
        ? left.toLowerCase() == right.toLowerCase()
        : left == right;

bool _sameEvm(String left, String right) =>
    left.toLowerCase() == right.toLowerCase();
