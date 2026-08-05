import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

enum BridgeChainType { evm, svm }

bool _isValidSolanaAddress(String value) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  if (!RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(value)) {
    return false;
  }
  var decoded = BigInt.zero;
  for (final codeUnit in value.codeUnits) {
    final digit = alphabet.indexOf(String.fromCharCode(codeUnit));
    if (digit < 0) return false;
    decoded = decoded * BigInt.from(58) + BigInt.from(digit);
  }
  var payloadBytes = 0;
  var remaining = decoded;
  while (remaining > BigInt.zero) {
    payloadBytes += 1;
    remaining >>= 8;
  }
  final leadingZeroBytes =
      value.codeUnits.takeWhile((unit) => unit == 49).length;
  return leadingZeroBytes + payloadBytes == 32;
}

class BridgeSourceChain {
  const BridgeSourceChain({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.nativeToken,
  });

  final int id;
  final String key;
  final String name;
  final BridgeChainType type;
  final String nativeToken;

  bool validAddress(String value) => switch (type) {
        BridgeChainType.evm => RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value),
        BridgeChainType.svm => _isValidSolanaAddress(value),
      };
}

class BridgeQuoteRequest {
  const BridgeQuoteRequest({
    required this.sourceChain,
    required this.sourceToken,
    required this.amount,
    required this.sourceAddress,
    required this.baseDestinationAddress,
  });

  final BridgeSourceChain sourceChain;
  final String sourceToken;
  final String amount;
  final String sourceAddress;
  final String baseDestinationAddress;
}

class BridgeQuote {
  const BridgeQuote({
    required this.quoteId,
    required this.sourceChain,
    required this.sourceToken,
    required this.sourceAmount,
    required this.destinationAmountMinimum,
    required this.destinationToken,
    required this.routeTool,
    required this.estimatedDurationSeconds,
    required this.estimatedFeesUsd,
    required this.quotedAt,
    required this.expiresAt,
    required this.externalCompletionUrl,
  });

  final String quoteId;
  final BridgeSourceChain sourceChain;
  final String sourceToken;
  final String sourceAmount;
  final String destinationAmountMinimum;
  final String destinationToken;
  final String routeTool;
  final int? estimatedDurationSeconds;
  final double? estimatedFeesUsd;
  final DateTime quotedAt;
  final DateTime expiresAt;
  final Uri externalCompletionUrl;

  Map<String, dynamic> toAgentJson() => <String, dynamic>{
        'quoteId': quoteId,
        'sourceChain': sourceChain.name,
        'sourceChainId': sourceChain.id,
        'sourceToken': sourceToken,
        'sourceAmount': sourceAmount,
        'destinationChain': 'Base',
        'destinationChainId': BridgeQuoteService.baseChainId,
        'destinationToken': destinationToken,
        'destinationAmountMinimum': destinationAmountMinimum,
        'routeTool': routeTool,
        if (estimatedDurationSeconds != null)
          'estimatedDurationSeconds': estimatedDurationSeconds,
        if (estimatedFeesUsd != null) 'estimatedFeesUsd': estimatedFeesUsd,
        'quotedAt': quotedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'requiresExternalSourceWallet': true,
        'mayApproveOrSign': false,
      };
}

class BridgeQuoteException implements Exception {
  const BridgeQuoteException(this.message, {this.httpStatus});
  final String message;
  final int? httpStatus;

  @override
  String toString() => message;
}

class _ResolvedBridgeToken {
  const _ResolvedBridgeToken({
    required this.address,
    required this.chainId,
    required this.symbol,
    required this.decimals,
  });

  final String address;
  final int chainId;
  final String symbol;
  final int decimals;
}

/// Quote-only inbound funding for the internal Base wallet.
///
/// LI.FI runtime discovery proves current chain/connection/route support. Raw
/// transaction calldata is discarded and cannot reach the internal signer.
/// The user completes the source-chain transaction in an external wallet.
class BridgeQuoteService {
  BridgeQuoteService({
    http.Client? client,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _clock = clock ?? DateTime.now;

  static const int ethereumChainId = 1;
  static const int robinhoodChainId = 4663;
  static const int baseChainId = 8453;
  static const int solanaChainId = 1151111081099710;
  static const int maxResponseBytes = 1024 * 1024;
  static const String baseUsdcContract =
      '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';

  static const List<BridgeSourceChain> sourceChains = <BridgeSourceChain>[
    BridgeSourceChain(
      id: ethereumChainId,
      key: 'eth',
      name: 'Ethereum',
      type: BridgeChainType.evm,
      nativeToken: 'ETH',
    ),
    BridgeSourceChain(
      id: solanaChainId,
      key: 'sol',
      name: 'Solana',
      type: BridgeChainType.svm,
      nativeToken: 'SOL',
    ),
    BridgeSourceChain(
      id: robinhoodChainId,
      key: 'out',
      name: 'Robinhood Chain',
      type: BridgeChainType.evm,
      nativeToken: 'ETH',
    ),
  ];

  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _clock;
  Set<int>? _supportedChainIds;
  DateTime? _chainsRefreshedAt;

  Future<BridgeQuote> quoteToBaseUsdc(BridgeQuoteRequest request) async {
    final sourceAddress = request.sourceAddress.trim();
    final destinationAddress = request.baseDestinationAddress.trim();
    if (!request.sourceChain.validAddress(sourceAddress)) {
      throw BridgeQuoteException(
        'Enter a valid ${request.sourceChain.name} source-wallet address.',
      );
    }
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(destinationAddress)) {
      throw const BridgeQuoteException(
        'A valid internal Base destination wallet is required.',
      );
    }
    final token = request.sourceToken.trim().toUpperCase();
    if (token != request.sourceChain.nativeToken && token != 'USDC') {
      throw const BridgeQuoteException(
        'Only the source native token or USDC is enabled in this first bridge lane.',
      );
    }
    final supported = await _supportedChains();
    if (!supported.contains(request.sourceChain.id) ||
        !supported.contains(baseChainId)) {
      throw BridgeQuoteException(
        '${request.sourceChain.name} to Base is not currently advertised by LI.FI.',
      );
    }
    final sourceToken = await _resolveToken(
      chainId: request.sourceChain.id,
      token: token,
      expectedSymbol: token,
      chainType: request.sourceChain.type,
    );
    final destinationToken = await _resolveToken(
      chainId: baseChainId,
      token: baseUsdcContract,
      expectedSymbol: 'USDC',
      chainType: BridgeChainType.evm,
    );
    final amountUnits = _decimalToUnits(request.amount, sourceToken.decimals);
    if (amountUnits <= BigInt.zero) {
      throw const BridgeQuoteException('Bridge amount must be positive.');
    }
    if (!await _hasConnection(
      request.sourceChain,
      sourceToken,
      destinationToken,
    )) {
      throw BridgeQuoteException(
        'LI.FI currently advertises no $token to Base USDC connection from ${request.sourceChain.name}.',
      );
    }

    final uri = Uri.https('li.quest', '/v1/quote', <String, String>{
      'fromChain': request.sourceChain.id.toString(),
      'toChain': baseChainId.toString(),
      'fromToken': sourceToken.address,
      'toToken': destinationToken.address,
      'fromAmount': amountUnits.toString(),
      'fromAddress': sourceAddress,
      'toAddress': destinationAddress,
      'slippage': '0.005',
    });
    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw BridgeQuoteException(
        'No live ${request.sourceChain.name} to Base USDC quote is available.',
        httpStatus: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const BridgeQuoteException('LI.FI returned an invalid quote.');
    }
    final quote = decoded.map((key, value) => MapEntry(key.toString(), value));
    final action = quote['action'] is Map
        ? Map<String, dynamic>.from(quote['action'] as Map)
        : const <String, dynamic>{};
    final estimate = quote['estimate'] is Map
        ? Map<String, dynamic>.from(quote['estimate'] as Map)
        : const <String, dynamic>{};
    final fromToken = action['fromToken'] is Map
        ? Map<String, dynamic>.from(action['fromToken'] as Map)
        : const <String, dynamic>{};
    final toToken = action['toToken'] is Map
        ? Map<String, dynamic>.from(action['toToken'] as Map)
        : const <String, dynamic>{};
    final fromChainId = (action['fromChainId'] as num?)?.toInt();
    final toChainId = (action['toChainId'] as num?)?.toInt();
    if (fromChainId != request.sourceChain.id ||
        toChainId != baseChainId ||
        !_sameAddress(
          action['fromAddress']?.toString(),
          sourceAddress,
          request.sourceChain.type,
        ) ||
        !_sameAddress(
          action['toAddress']?.toString(),
          destinationAddress,
          BridgeChainType.evm,
        ) ||
        !_matchesToken(fromToken, sourceToken, request.sourceChain.type) ||
        !_matchesToken(toToken, destinationToken, BridgeChainType.evm)) {
      throw const BridgeQuoteException(
        'LI.FI quote fields do not match the requested wallets, chains, and token contracts.',
      );
    }
    final returnedFromAmount = action['fromAmount']?.toString() ?? '';
    if (returnedFromAmount != amountUnits.toString()) {
      throw const BridgeQuoteException(
        'LI.FI quote amount does not match the requested amount.',
      );
    }
    final toAmountMin = BigInt.tryParse(
      estimate['toAmountMin']?.toString() ?? '',
    );
    if (toAmountMin == null || toAmountMin <= BigInt.zero) {
      throw const BridgeQuoteException(
        'LI.FI quote has no valid minimum received amount.',
      );
    }
    final quoteId = quote['id']?.toString().trim() ?? '';
    final routeTool = quote['toolDetails'] is Map
        ? (quote['toolDetails'] as Map)['name']?.toString().trim() ?? ''
        : quote['tool']?.toString().trim() ?? '';
    if (quoteId.isEmpty || routeTool.isEmpty) {
      throw const BridgeQuoteException(
        'LI.FI quote is missing its route identity.',
      );
    }
    final feeUsd = _sumUsd(estimate['feeCosts']);
    final gasUsd = _sumUsd(estimate['gasCosts']);
    final now = _clock().toUtc();
    return BridgeQuote(
      quoteId: quoteId,
      sourceChain: request.sourceChain,
      sourceToken: sourceToken.symbol,
      sourceAmount: _formatUnits(amountUnits, sourceToken.decimals),
      destinationAmountMinimum:
          _formatUnits(toAmountMin, destinationToken.decimals),
      destinationToken: destinationToken.symbol,
      routeTool: routeTool,
      estimatedDurationSeconds:
          (estimate['executionDuration'] as num?)?.toInt(),
      estimatedFeesUsd: feeUsd == null && gasUsd == null
          ? null
          : (feeUsd ?? 0) + (gasUsd ?? 0),
      quotedAt: now,
      expiresAt: now.add(const Duration(seconds: 60)),
      externalCompletionUrl: Uri.parse('https://jumper.exchange/'),
    );
  }

  Future<Set<int>> _supportedChains() async {
    final cachedAt = _chainsRefreshedAt;
    if (_supportedChainIds != null &&
        cachedAt != null &&
        _clock().toUtc().difference(cachedAt) < const Duration(minutes: 10)) {
      return _supportedChainIds!;
    }
    final response = await _get(
      Uri.https('li.quest', '/v1/chains', <String, String>{
        'chainTypes': 'EVM,SVM',
      }),
    );
    if (response.statusCode != 200) {
      throw BridgeQuoteException(
        'Could not verify LI.FI chain support.',
        httpStatus: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    final rawChains = decoded is Map ? decoded['chains'] : null;
    if (rawChains is! List) {
      throw const BridgeQuoteException('LI.FI chain catalog is invalid.');
    }
    final ids = <int>{};
    for (final raw in rawChains) {
      if (raw is! Map) continue;
      final mainnet = raw['mainnet'];
      final id = raw['id'];
      if (id is num && mainnet != false) ids.add(id.toInt());
    }
    _supportedChainIds = ids;
    _chainsRefreshedAt = _clock().toUtc();
    return ids;
  }

  Future<_ResolvedBridgeToken> _resolveToken({
    required int chainId,
    required String token,
    required String expectedSymbol,
    required BridgeChainType chainType,
  }) async {
    final response = await _get(
      Uri.https('li.quest', '/v1/token', <String, String>{
        'chain': chainId.toString(),
        'token': token,
      }),
    );
    if (response.statusCode != 200) {
      throw BridgeQuoteException(
        'Could not resolve $expectedSymbol on chain $chainId.',
        httpStatus: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const BridgeQuoteException('LI.FI token metadata is invalid.');
    }
    final resolved =
        decoded.map((key, value) => MapEntry(key.toString(), value));
    final resolvedChainId = (resolved['chainId'] as num?)?.toInt();
    final address = resolved['address']?.toString().trim() ?? '';
    final symbol = resolved['symbol']?.toString().trim().toUpperCase() ?? '';
    final decimals = (resolved['decimals'] as num?)?.toInt();
    final validAddress = chainType == BridgeChainType.evm
        ? RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address)
        : _isValidSolanaAddress(address);
    if (resolvedChainId != chainId ||
        symbol != expectedSymbol ||
        decimals == null ||
        decimals < 0 ||
        decimals > 36 ||
        !validAddress) {
      throw BridgeQuoteException(
        'LI.FI returned unexpected $expectedSymbol token metadata for chain $chainId.',
      );
    }
    return _ResolvedBridgeToken(
      address: address,
      chainId: resolvedChainId!,
      symbol: symbol,
      decimals: decimals,
    );
  }

  Future<bool> _hasConnection(
    BridgeSourceChain source,
    _ResolvedBridgeToken fromToken,
    _ResolvedBridgeToken toToken,
  ) async {
    final response = await _get(
      Uri.https('li.quest', '/v1/connections', <String, String>{
        'fromChain': source.id.toString(),
        'toChain': baseChainId.toString(),
        'fromToken': fromToken.address,
        'toToken': toToken.address,
        'chainTypes': 'EVM,SVM',
        'allowDestinationCall': 'false',
      }),
    );
    if (response.statusCode != 200) return false;
    final decoded = jsonDecode(response.body);
    final connections = decoded is Map ? decoded['connections'] : null;
    if (connections is! List) return false;
    return connections.any((raw) {
      if (raw is! Map) return false;
      final fromTokens = raw['fromTokens'];
      final toTokens = raw['toTokens'];
      return (raw['fromChainId'] as num?)?.toInt() == source.id &&
          (raw['toChainId'] as num?)?.toInt() == baseChainId &&
          _tokenListContains(fromTokens, fromToken, source.type) &&
          _tokenListContains(toTokens, toToken, BridgeChainType.evm);
    });
  }

  bool _tokenListContains(
    dynamic rawTokens,
    _ResolvedBridgeToken expected,
    BridgeChainType chainType,
  ) {
    if (rawTokens is! List) return false;
    return rawTokens.any((raw) {
      if (raw is! Map) return false;
      return (raw['chainId'] as num?)?.toInt() == expected.chainId &&
          _sameAddress(
            raw['address']?.toString(),
            expected.address,
            chainType,
          );
    });
  }

  bool _matchesToken(
    Map<String, dynamic> actual,
    _ResolvedBridgeToken expected,
    BridgeChainType chainType,
  ) {
    return (actual['chainId'] as num?)?.toInt() == expected.chainId &&
        actual['symbol']?.toString().trim().toUpperCase() == expected.symbol &&
        (actual['decimals'] as num?)?.toInt() == expected.decimals &&
        _sameAddress(
          actual['address']?.toString(),
          expected.address,
          chainType,
        );
  }

  bool _sameAddress(
    String? actual,
    String expected,
    BridgeChainType chainType,
  ) {
    if (actual == null) return false;
    return chainType == BridgeChainType.evm
        ? actual.toLowerCase() == expected.toLowerCase()
        : actual == expected;
  }

  Future<http.Response> _get(Uri uri) async {
    if (uri.scheme != 'https' || uri.host != 'li.quest') {
      throw const BridgeQuoteException('Bridge API host is not allowlisted.');
    }
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false
      ..headers['Accept'] = 'application/json';
    final streamed = await _client.send(request).timeout(
          const Duration(seconds: 25),
        );
    final bytes = BytesBuilder(copy: false);
    var size = 0;
    await for (final chunk
        in streamed.stream.timeout(const Duration(seconds: 25))) {
      size += chunk.length;
      if (size > maxResponseBytes) {
        throw const BridgeQuoteException('Bridge API response is too large.');
      }
      bytes.add(chunk);
    }
    return http.Response.bytes(
      bytes.takeBytes(),
      streamed.statusCode,
      headers: streamed.headers,
      reasonPhrase: streamed.reasonPhrase,
      request: request,
    );
  }

  BigInt _decimalToUnits(String value, int decimals) {
    final normalized = value.trim();
    final match = RegExp(r'^(\d{1,18})(?:\.(\d+))?$').firstMatch(normalized);
    if (match == null) {
      throw const BridgeQuoteException(
          'Enter a plain positive decimal amount.');
    }
    final fraction = match.group(2) ?? '';
    if (fraction.length > decimals) {
      throw BridgeQuoteException('Amount supports at most $decimals decimals.');
    }
    final whole = BigInt.parse(match.group(1)!);
    final fractionUnits = fraction.isEmpty
        ? BigInt.zero
        : BigInt.parse(fraction.padRight(decimals, '0'));
    return whole * BigInt.from(10).pow(decimals) + fractionUnits;
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

  double? _sumUsd(dynamic costs) {
    if (costs is! List) return null;
    var total = 0.0;
    var found = false;
    for (final raw in costs) {
      if (raw is! Map) continue;
      final amount = double.tryParse(raw['amountUSD']?.toString() ?? '');
      if (amount == null) continue;
      found = true;
      total += amount;
    }
    return found ? total : null;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
