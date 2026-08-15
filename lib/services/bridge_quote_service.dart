import 'package:http/http.dart' as http;

import 'bridge/bridge_http_client.dart';
import 'bridge/bridge_models.dart' as domain;
import 'bridge/lifi_bridge_service.dart';

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

/// Estimate-only inbound funding for the internal Base wallet.
///
/// The shared LI.FI service performs strict runtime discovery and quote-field
/// validation. This compatibility API receives only [domain.BridgeEstimate],
/// so executable transaction payloads cannot cross into chat or the internal
/// Base signer.
class BridgeQuoteService {
  BridgeQuoteService({
    http.Client? client,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _clock = clock ?? DateTime.now {
    _transport = BridgeHttpClient(client: _client);
    _lifi = LifiBridgeService(transport: _transport, clock: _clock);
  }

  static const int ethereumChainId = domain.BridgeConstants.ethereumChainId;
  static const int robinhoodChainId = domain.BridgeConstants.robinhoodChainId;
  static const int baseChainId = domain.BridgeConstants.baseChainId;
  static const int solanaChainId = domain.BridgeConstants.solanaChainId;
  static const int maxResponseBytes = 1024 * 1024;
  static const String baseUsdcContract = domain.BridgeConstants.baseUsdc;

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
  late final BridgeHttpClient _transport;
  late final LifiBridgeService _lifi;

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
    final symbol = request.sourceToken.trim().toUpperCase();
    if (symbol != request.sourceChain.nativeToken && symbol != 'USDC') {
      throw const BridgeQuoteException(
        'Only the source native token or USDC is enabled in this first bridge lane.',
      );
    }
    final decimals = symbol == 'USDC'
        ? 6
        : request.sourceChain.type == BridgeChainType.svm
            ? 9
            : 18;
    final amountUnits = _decimalToUnits(request.amount, decimals);
    if (amountUnits <= BigInt.zero) {
      throw const BridgeQuoteException('Bridge amount must be positive.');
    }

    try {
      final estimate = await _lifi.estimate(
        domain.BridgeFundingRequest(
          method: domain.BridgeFundingMethod.connectedWallet,
          sourceChain: domain.BridgeChain(
            id: request.sourceChain.id,
            key: request.sourceChain.key,
            name: request.sourceChain.name,
            type: _domainType(request.sourceChain.type),
            nativeTokenSymbol: request.sourceChain.nativeToken,
          ),
          sourceToken: domain.BridgeToken(
            chainId: request.sourceChain.id,
            address: symbol,
            symbol: symbol,
            decimals: decimals,
            solverDepositable: false,
          ),
          amount: request.amount.trim(),
          amountUnits: amountUnits.toString(),
          baseDestinationAddress: destinationAddress,
          sourceAddress: sourceAddress,
        ),
      );
      return BridgeQuote(
        quoteId: estimate.quoteId,
        sourceChain: request.sourceChain,
        sourceToken: estimate.request.sourceToken.symbol,
        sourceAmount: _formatUnits(
          BigInt.parse(estimate.request.amountUnits),
          estimate.request.sourceToken.decimals,
        ),
        destinationAmountMinimum: estimate.minimumOutputDisplay,
        destinationToken: 'USDC',
        routeTool: estimate.routeTool,
        estimatedDurationSeconds: estimate.estimatedDurationSeconds,
        estimatedFeesUsd: estimate.estimatedFeesUsd,
        quotedAt: estimate.quotedAt,
        expiresAt: estimate.expiresAt,
        externalCompletionUrl: Uri.parse('https://jumper.exchange/'),
      );
    } on BridgeHttpException catch (error) {
      throw BridgeQuoteException(
        'Could not load a verified LI.FI quote.',
        httpStatus: error.statusCode,
      );
    } on domain.BridgeValidationException catch (error) {
      throw BridgeQuoteException(_messageForValidation(error.code));
    }
  }

  domain.BridgeChainType _domainType(BridgeChainType type) => switch (type) {
        BridgeChainType.evm => domain.BridgeChainType.evm,
        BridgeChainType.svm => domain.BridgeChainType.svm,
      };

  BigInt _decimalToUnits(String value, int decimals) {
    final normalized = value.trim();
    final match = RegExp(r'^(\d{1,18})(?:\.(\d+))?$').firstMatch(normalized);
    if (match == null) {
      throw const BridgeQuoteException(
        'Enter a plain positive decimal amount.',
      );
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

  String _messageForValidation(String code) => switch (code) {
        'unsupported_source_chain' ||
        'route_not_advertised' =>
          'The requested route is not currently advertised by LI.FI.',
        'invalid_bridge_amount' => 'Bridge amount must be positive.',
        'source_token_mismatch' ||
        'invalid_lifi_token' =>
          'LI.FI returned unexpected source-token metadata.',
        'invalid_base_usdc' => 'LI.FI returned unexpected Base USDC metadata.',
        _ => 'LI.FI returned a quote that did not match the requested route.',
      };

  void dispose() {
    _transport.dispose();
    if (_ownsClient) _client.close();
  }
}
