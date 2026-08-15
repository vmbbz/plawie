import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'bridge_http_client.dart';
import 'bridge_models.dart';

final class LifiBridgeService {
  LifiBridgeService({
    required BridgeHttpTransport transport,
    DateTime Function()? clock,
  })  : _transport = transport,
        _clock = clock ?? DateTime.now;

  final BridgeHttpTransport _transport;
  final DateTime Function() _clock;
  Set<int>? _supportedChainIds;
  DateTime? _chainsRefreshedAt;

  Future<BridgeEstimate> estimate(BridgeFundingRequest request) async =>
      (await _loadQuote(request, includeTransaction: false)).estimate;

  Future<BridgeExecutableQuote> executableQuote(
    BridgeFundingRequest request, {
    required String connectedSourceAddress,
  }) async {
    final connectedRequest = BridgeFundingRequest(
      method: request.method,
      sourceChain: request.sourceChain,
      sourceToken: request.sourceToken,
      amount: request.amount,
      amountUnits: request.amountUnits,
      baseDestinationAddress: request.baseDestinationAddress,
      sourceAddress: connectedSourceAddress,
      refundAddress: request.refundAddress,
      selfCustodyConfirmed: request.selfCustodyConfirmed,
    );
    final parsed = await _loadQuote(
      connectedRequest,
      includeTransaction: true,
    );
    final payload = parsed.payload;
    if (payload == null) {
      throw const BridgeValidationException('transaction_request_missing');
    }
    return BridgeExecutableQuote(
      estimate: parsed.estimate,
      connectedSourceAddress: connectedSourceAddress,
      destinationChainId: BridgeConstants.baseChainId,
      destinationToken: parsed.destinationToken,
      payload: payload,
      fingerprint: _fingerprint(payload),
    );
  }

  Future<BridgeToken> resolveToken(int chainId, String token) async {
    final chain = _chains[chainId];
    if (chain == null) {
      throw const BridgeValidationException('unsupported_source_chain');
    }
    final response = await _transport.getJson(
      Uri.https('li.quest', '/v1/token', <String, String>{
        'chain': chainId.toString(),
        'token': token,
      }),
    );
    _requireOk(response, 'token');
    final json = _asMap(response.json, 'token');
    final resolvedChainId = _strictInt(json['chainId']);
    final address = json['address']?.toString().trim() ?? '';
    final symbol = json['symbol']?.toString().trim().toUpperCase() ?? '';
    final decimals = _strictInt(json['decimals']);
    if (resolvedChainId != chainId ||
        symbol.isEmpty ||
        decimals == null ||
        decimals < 0 ||
        decimals > 36 ||
        !_validAddress(address, chain.type)) {
      throw const BridgeValidationException('invalid_lifi_token');
    }
    return BridgeToken(
      chainId: chainId,
      address: address,
      symbol: symbol,
      decimals: decimals,
      solverDepositable: false,
    );
  }

  Future<_ParsedLifiQuote> _loadQuote(
    BridgeFundingRequest request, {
    required bool includeTransaction,
  }) async {
    final sourceAddress = request.sourceAddress?.trim() ?? '';
    final baseAddress = request.baseDestinationAddress.trim();
    if (!_chains.containsKey(request.sourceChain.id) ||
        request.sourceChain.type != _chains[request.sourceChain.id]!.type ||
        !_validAddress(sourceAddress, request.sourceChain.type) ||
        !_validAddress(baseAddress, BridgeChainType.evm)) {
      throw const BridgeValidationException('invalid_bridge_request');
    }
    final supported = await _supportedChains();
    if (!supported.contains(request.sourceChain.id) ||
        !supported.contains(BridgeConstants.baseChainId)) {
      throw const BridgeValidationException('route_not_advertised');
    }
    final sourceToken = await resolveToken(
      request.sourceChain.id,
      request.sourceToken.address,
    );
    final symbolicRequest = request.sourceToken.address.toUpperCase() ==
        request.sourceToken.symbol.toUpperCase();
    if (sourceToken.symbol != request.sourceToken.symbol.toUpperCase() ||
        sourceToken.decimals != request.sourceToken.decimals ||
        (!symbolicRequest &&
            !_sameAddress(sourceToken.address, request.sourceToken.address,
                request.sourceChain.type))) {
      throw const BridgeValidationException('source_token_mismatch');
    }
    final baseUsdc = await resolveToken(
      BridgeConstants.baseChainId,
      BridgeConstants.baseUsdc,
    );
    if (baseUsdc.symbol != 'USDC' ||
        baseUsdc.decimals != 6 ||
        !_sameAddress(
          baseUsdc.address,
          BridgeConstants.baseUsdc,
          BridgeChainType.evm,
        )) {
      throw const BridgeValidationException('invalid_base_usdc');
    }
    final amountUnits = BigInt.tryParse(request.amountUnits);
    if (amountUnits == null || amountUnits <= BigInt.zero) {
      throw const BridgeValidationException('invalid_bridge_amount');
    }
    if (!await _hasConnection(request.sourceChain, sourceToken, baseUsdc)) {
      throw const BridgeValidationException('route_not_advertised');
    }
    final response = await _transport.getJson(
      Uri.https('li.quest', '/v1/quote', <String, String>{
        'fromChain': request.sourceChain.id.toString(),
        'toChain': BridgeConstants.baseChainId.toString(),
        'fromToken': sourceToken.address,
        'toToken': baseUsdc.address,
        'fromAmount': amountUnits.toString(),
        'fromAddress': sourceAddress,
        'toAddress': baseAddress,
        'slippage': '0.005',
      }),
      maxBytes: 1024 * 1024,
    );
    _requireOk(response, 'quote');
    final root = _asMap(response.json, 'quote');
    final action = _asMap(root['action'], 'quote_action');
    final estimateJson = _asMap(root['estimate'], 'quote_estimate');
    final fromToken = _asMap(action['fromToken'], 'quote_from_token');
    final toToken = _asMap(action['toToken'], 'quote_to_token');
    if (_strictInt(action['fromChainId']) != request.sourceChain.id ||
        _strictInt(action['toChainId']) != BridgeConstants.baseChainId ||
        !_sameAddress(action['fromAddress']?.toString() ?? '', sourceAddress,
            request.sourceChain.type) ||
        !_sameAddress(action['toAddress']?.toString() ?? '', baseAddress,
            BridgeChainType.evm) ||
        action['fromAmount']?.toString() != amountUnits.toString() ||
        !_matchesToken(fromToken, sourceToken, request.sourceChain.type) ||
        !_matchesToken(toToken, baseUsdc, BridgeChainType.evm)) {
      throw const BridgeValidationException('quote_mismatch');
    }
    final returnedSlippage =
        double.tryParse(estimateJson['slippage']?.toString() ?? '0.005');
    if (returnedSlippage == null ||
        !returnedSlippage.isFinite ||
        (returnedSlippage - 0.005).abs() > 1e-12) {
      throw const BridgeValidationException('quote_slippage_mismatch');
    }
    final minimum =
        BigInt.tryParse(estimateJson['toAmountMin']?.toString() ?? '');
    final quoteId = root['id']?.toString().trim() ?? '';
    // LI.FI's root `tool` is the canonical status API identifier. The
    // human-facing toolDetails.name can contain casing, spaces, or composite
    // labels that the /status `bridge` query does not accept.
    final routeTool = root['tool']?.toString().trim() ?? '';
    if (minimum == null ||
        minimum <= BigInt.zero ||
        quoteId.isEmpty ||
        routeTool.isEmpty) {
      throw const BridgeValidationException('invalid_lifi_estimate');
    }
    final approvalAddress = estimateJson['approvalAddress']?.toString().trim();
    if (approvalAddress != null &&
        approvalAddress.isNotEmpty &&
        !_validAddress(approvalAddress, BridgeChainType.evm)) {
      throw const BridgeValidationException('invalid_approval_address');
    }
    final now = _clock().toUtc();
    final normalizedRequest = BridgeFundingRequest(
      method: request.method,
      sourceChain: request.sourceChain,
      sourceToken: sourceToken,
      amount: request.amount,
      amountUnits: amountUnits.toString(),
      baseDestinationAddress: baseAddress,
      sourceAddress: sourceAddress,
      refundAddress: request.refundAddress,
      selfCustodyConfirmed: request.selfCustodyConfirmed,
    );
    final estimate = BridgeEstimate(
      provider: 'lifi',
      quoteId: quoteId,
      request: normalizedRequest,
      minimumOutputUnits: minimum.toString(),
      minimumOutputDisplay: _formatUnits(minimum, baseUsdc.decimals),
      routeTool: routeTool,
      quotedAt: now,
      expiresAt: now.add(const Duration(seconds: 60)),
      approvalAddress: approvalAddress == null || approvalAddress.isEmpty
          ? null
          : approvalAddress,
      estimatedDurationSeconds: _strictInt(estimateJson['executionDuration']),
      estimatedFeesUsd: _combinedUsd(estimateJson),
    );
    final payload = includeTransaction
        ? _parsePayload(
            request.sourceChain,
            sourceAddress,
            _asMap(root['transactionRequest'], 'transaction_request'),
            estimate.approvalAddress,
          )
        : null;
    return _ParsedLifiQuote(
      estimate: estimate,
      destinationToken: baseUsdc,
      payload: payload,
    );
  }

  BridgeExecutionPayload _parsePayload(
    BridgeChain source,
    String sourceAddress,
    Map<String, dynamic> transaction,
    String? approvalAddress,
  ) {
    if (source.type == BridgeChainType.evm) {
      return EvmBridgeExecutionPayload(
        chainId: _parseInt(transaction['chainId']),
        from: transaction['from']?.toString() ?? '',
        to: transaction['to']?.toString() ?? '',
        valueHex: transaction['value']?.toString() ?? '',
        dataHex: transaction['data']?.toString() ?? '',
        gasLimitHex: transaction['gasLimit']?.toString() ??
            transaction['gas']?.toString() ??
            '',
        approvalAddress: approvalAddress,
      );
    }
    if (transaction.keys.any((key) => key != 'data')) {
      throw const BridgeValidationException(
          'unexpected_solana_transaction_field');
    }
    return SolanaBridgeExecutionPayload(
      from: sourceAddress,
      base64Transaction: transaction['data']?.toString() ?? '',
    );
  }

  String _fingerprint(BridgeExecutionPayload payload) {
    if (payload is EvmBridgeExecutionPayload) {
      final canonical = <Object?>[
        payload.chainId,
        payload.from.toLowerCase(),
        payload.to.toLowerCase(),
        _normalizeQuantity(payload.valueHex),
        payload.dataHex.toLowerCase(),
      ].join('|');
      return sha256.convert(utf8.encode(canonical)).toString();
    }
    final solana = payload as SolanaBridgeExecutionPayload;
    try {
      return sha256.convert(base64Decode(solana.base64Transaction)).toString();
    } on FormatException {
      throw const BridgeValidationException('invalid_solana_transaction');
    }
  }

  Future<Set<int>> _supportedChains() async {
    final now = _clock().toUtc();
    if (_supportedChainIds != null &&
        _chainsRefreshedAt != null &&
        now.difference(_chainsRefreshedAt!) < const Duration(minutes: 10)) {
      return _supportedChainIds!;
    }
    final response = await _transport.getJson(
      Uri.https('li.quest', '/v1/chains', <String, String>{
        'chainTypes': 'EVM,SVM',
      }),
    );
    _requireOk(response, 'chains');
    final root = _asMap(response.json, 'chains');
    final raw = root['chains'];
    if (raw is! List) {
      throw const BridgeValidationException('invalid_lifi_chains');
    }
    final ids = <int>{};
    for (final item in raw) {
      if (item is! Map || item['mainnet'] == false) continue;
      final id = _strictInt(item['id']);
      if (id != null) ids.add(id);
    }
    _supportedChainIds = Set<int>.unmodifiable(ids);
    _chainsRefreshedAt = now;
    return _supportedChainIds!;
  }

  Future<bool> _hasConnection(
    BridgeChain source,
    BridgeToken fromToken,
    BridgeToken toToken,
  ) async {
    final response = await _transport.getJson(
      Uri.https('li.quest', '/v1/connections', <String, String>{
        'fromChain': source.id.toString(),
        'toChain': BridgeConstants.baseChainId.toString(),
        'fromToken': fromToken.address,
        'toToken': toToken.address,
        'chainTypes': 'EVM,SVM',
        'allowDestinationCall': 'false',
      }),
    );
    if (response.statusCode != 200) return false;
    final root = _asMap(response.json, 'connections');
    final connections = root['connections'];
    if (connections is! List) return false;
    return connections.any((item) {
      if (item is! Map) return false;
      return _strictInt(item['fromChainId']) == source.id &&
          _strictInt(item['toChainId']) == BridgeConstants.baseChainId &&
          _tokenListContains(item['fromTokens'], fromToken, source.type) &&
          _tokenListContains(item['toTokens'], toToken, BridgeChainType.evm);
    });
  }
}

final class _ParsedLifiQuote {
  const _ParsedLifiQuote({
    required this.estimate,
    required this.destinationToken,
    required this.payload,
  });

  final BridgeEstimate estimate;
  final BridgeToken destinationToken;
  final BridgeExecutionPayload? payload;
}

const _chains = <int, BridgeChain>{
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

Map<String, dynamic> _asMap(Object? raw, String code) {
  if (raw is! Map) throw BridgeValidationException('invalid_lifi_$code');
  return Map<String, dynamic>.from(raw);
}

void _requireOk(BridgeHttpResponse response, String code) {
  if (response.statusCode != 200) {
    throw BridgeValidationException('lifi_${code}_http_${response.statusCode}');
  }
}

bool _matchesToken(
  Map<String, dynamic> raw,
  BridgeToken token,
  BridgeChainType type,
) =>
    _strictInt(raw['chainId']) == token.chainId &&
    raw['symbol']?.toString().toUpperCase() == token.symbol.toUpperCase() &&
    _strictInt(raw['decimals']) == token.decimals &&
    _sameAddress(raw['address']?.toString() ?? '', token.address, type);

bool _tokenListContains(Object? raw, BridgeToken token, BridgeChainType type) {
  if (raw is! List) return false;
  return raw.any((item) =>
      item is Map &&
      _strictInt(item['chainId']) == token.chainId &&
      _sameAddress(item['address']?.toString() ?? '', token.address, type));
}

bool _validAddress(String value, BridgeChainType type) => switch (type) {
      BridgeChainType.evm => RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value),
      BridgeChainType.svm => _isValidSolanaAddress(value),
    };

bool _sameAddress(String left, String right, BridgeChainType type) =>
    type == BridgeChainType.evm
        ? left.toLowerCase() == right.toLowerCase()
        : left == right;

bool _isValidSolanaAddress(String value) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  if (!RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(value)) return false;
  var decoded = BigInt.zero;
  for (final unit in value.codeUnits) {
    final digit = alphabet.indexOf(String.fromCharCode(unit));
    if (digit < 0) return false;
    decoded = decoded * BigInt.from(58) + BigInt.from(digit);
  }
  var payloadBytes = 0;
  var remaining = decoded;
  while (remaining > BigInt.zero) {
    payloadBytes += 1;
    remaining >>= 8;
  }
  final leadingZeros = value.codeUnits.takeWhile((unit) => unit == 49).length;
  return leadingZeros + payloadBytes == 32;
}

int _parseInt(Object? raw) {
  return _strictInt(raw) ?? -1;
}

int? _strictInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) {
    final value = raw.toDouble();
    if (!value.isFinite || value != value.truncateToDouble()) return null;
    return raw.toInt();
  }
  final value = raw?.toString() ?? '';
  if (!RegExp(r'^-?\d+$').hasMatch(value)) return null;
  return int.tryParse(value);
}

String _normalizeQuantity(String value) {
  if (!RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value)) return value.toLowerCase();
  final parsed = BigInt.parse(value.substring(2), radix: 16);
  return '0x${parsed.toRadixString(16)}';
}

String _formatUnits(BigInt value, int decimals) {
  final divisor = BigInt.from(10).pow(decimals);
  final whole = value ~/ divisor;
  final fraction = (value % divisor)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
}

double? _combinedUsd(Map<String, dynamic> estimate) {
  double? sum(Object? raw) {
    if (raw is! List) return null;
    var found = false;
    var total = 0.0;
    for (final item in raw) {
      if (item is! Map) continue;
      final value = double.tryParse(item['amountUSD']?.toString() ?? '');
      if (value == null || !value.isFinite) continue;
      found = true;
      total += value;
    }
    return found ? total : null;
  }

  final fees = sum(estimate['feeCosts']);
  final gas = sum(estimate['gasCosts']);
  return fees == null && gas == null ? null : (fees ?? 0) + (gas ?? 0);
}
