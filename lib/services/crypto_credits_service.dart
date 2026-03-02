import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// SOL → LI.FI Bridge → OpenRouter Credits pipeline
/// Adapted from clawbot for OpenClaw integration
class CryptoCreditsService {
  final Logger _logger = Logger();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // API endpoints
  static const String _lifiBaseUrl = 'https://li.quest/v1';
  static const String _openRouterBaseUrl = 'https://openrouter.ai/api/v1';

  // Solana chain info for LI.FI
  static const String _solanaChainId = 'SOL';
  static const String _solNativeAddress = '11111111111111111111111111111111';
  static const String _solUsdcAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  // Destination (Base L2)
  static const int _baseChainId = 8453;
  static const String _baseEthAddress = '0x0000000000000000000000000000000000000000';

  // State
  String? _openRouterApiKey;
  double _creditsBalance = 0.0;
  double _creditsUsed = 0.0;

  double get creditsBalance => _creditsBalance;
  double get creditsUsed => _creditsUsed;
  double get creditsRemaining => _creditsBalance - _creditsUsed;
  String? get apiKey => _openRouterApiKey;

  // Stream for reactive UI
  final _creditsController = StreamController<CreditState>.broadcast();
  Stream<CreditState> get creditsStream => _creditsController.stream;

  Future<void> initialize() async {
    _openRouterApiKey = await _storage.read(key: 'openrouter_api_key');
    if (_openRouterApiKey != null) {
      await refreshCredits();
    }
  }

  /// Store the OpenRouter API key
  Future<void> setApiKey(String apiKey) async {
    _openRouterApiKey = apiKey;
    await _storage.write(key: 'openrouter_api_key', value: apiKey);
    await refreshCredits();
  }

  /// Clear the API key
  Future<void> clearApiKey() async {
    _openRouterApiKey = null;
    _creditsBalance = 0;
    _creditsUsed = 0;
    await _storage.delete(key: 'openrouter_api_key');
    _emitState();
  }

  /// Fetch current credit balance from OpenRouter
  Future<void> refreshCredits() async {
    if (_openRouterApiKey == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_openRouterBaseUrl/credits'),
        headers: {
          'Authorization': 'Bearer $_openRouterApiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final creditsData = data['data'];
        _creditsBalance = (creditsData['total_credits'] as num?)?.toDouble() ?? 0.0;
        _creditsUsed = (creditsData['total_usage'] as num?)?.toDouble() ?? 0.0;
        _logger.i('Credits: \$$_creditsBalance total, \$$_creditsUsed used');
        _emitState();
      } else {
        _logger.w('Failed to fetch credits: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching credits: $e');
    }
  }

  /// Get a bridge quote from LI.FI: SOL → ETH on Base
  Future<LiFiQuote> getBridgeQuote({
    required String fromAddress,
    required String toAddress,
    required String fromAmountWei,
    String fromToken = 'SOL',
  }) async {
    final tokenAddress = fromToken == 'USDC' ? _solUsdcAddress : _solNativeAddress;

    final queryParams = {
      'fromChain': _solanaChainId,
      'toChain': _baseChainId.toString(),
      'fromToken': tokenAddress,
      'toToken': _baseEthAddress,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'fromAmount': fromAmountWei,
    };

    final uri = Uri.parse('$_lifiBaseUrl/quote').replace(queryParameters: queryParams);

    _logger.i('Getting LI.FI quote: $uri');

    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LiFiQuote.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw LiFiException(
        error['message'] ?? 'Failed to get quote',
        statusCode: response.statusCode,
      );
    }
  }

  /// Convert USD amount to SOL lamports (approximate)
  Future<BigInt> usdToLamports(double usdAmount) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final solPrice = data['solana']['usd'] as double;
        final solAmount = usdAmount / solPrice;
        // 1 SOL = 1,000,000,000 lamports
        return BigInt.from((solAmount * 1e9).round());
      } else {
        throw Exception('Failed to fetch SOL price');
      }
    } catch (e) {
      _logger.e('Error converting USD to lamports: $e');
      // Fallback: assume $100 per SOL
      return BigInt.from((usdAmount * 1e7).round());
    }
  }

  /// Create a Coinbase charge to convert bridged ETH to OpenRouter credits
  Future<CoinbaseCharge> createCoinbaseCharge({
    required double usdAmount,
    required String senderAddress,
    int chainId = _baseChainId,
  }) async {
    if (_openRouterApiKey == null) {
      throw Exception('OpenRouter API key not set');
    }

    final response = await http.post(
      Uri.parse('$_openRouterBaseUrl/credits/coinbase'),
      headers: {
        'Authorization': 'Bearer $_openRouterApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'amount': usdAmount,
        'sender': senderAddress,
        'chain_id': chainId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return CoinbaseCharge.fromJson(data);
    } else {
      throw Exception('Failed to create Coinbase charge: ${response.body}');
    }
  }

  void _emitState() {
    _creditsController.add(CreditState(
      balance: _creditsBalance,
      used: _creditsUsed,
      remaining: creditsRemaining,
    ));
  }

  void dispose() {
    _creditsController.close();
  }
}

class CreditState {
  final double balance;
  final double used;
  final double remaining;

  CreditState({
    required this.balance,
    required this.used,
    required this.remaining,
  });
}

class LiFiQuote {
  final String id;
  final String fromAmount;
  final String toAmount;
  final String fromToken;
  final String toToken;
  final Map<String, dynamic> transactionRequest;

  LiFiQuote({
    required this.id,
    required this.fromAmount,
    required this.toAmount,
    required this.fromToken,
    required this.toToken,
    required this.transactionRequest,
  });

  factory LiFiQuote.fromJson(Map<String, dynamic> json) {
    return LiFiQuote(
      id: json['id'] ?? '',
      fromAmount: json['fromAmount'] ?? '',
      toAmount: json['toAmount'] ?? '',
      fromToken: json['fromToken'] ?? '',
      toToken: json['toToken'] ?? '',
      transactionRequest: json['transactionRequest'] ?? {},
    );
  }
}

class CoinbaseCharge {
  final String id;
  final String hostedUrl;
  final String address;
  final double amount;
  final String status;

  CoinbaseCharge({
    required this.id,
    required this.hostedUrl,
    required this.address,
    required this.amount,
    required this.status,
  });

  factory CoinbaseCharge.fromJson(Map<String, dynamic> json) {
    return CoinbaseCharge(
      id: json['id'] ?? '',
      hostedUrl: json['hosted_url'] ?? '',
      address: json['address'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? '',
    );
  }
}

class LiFiException implements Exception {
  final String message;
  final int? statusCode;

  LiFiException(this.message, {this.statusCode});

  @override
  String toString() => 'LiFiException: $message';
}
