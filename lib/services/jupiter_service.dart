import 'dart:async';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'jupiter_models.dart';

/// Real Jupiter Ultra API Client
/// Based on SeekerClaw's Jupiter integration with Ultra API
class JupiterService {
  static final JupiterService _instance = JupiterService._internal();
  factory JupiterService() => _instance;
  JupiterService._internal();

  final Logger _logger = Logger();
  final Dio _dio = Dio();
  static const String _baseUrl = 'https://quote-api.jup.ag';
  static const String _v6BaseUrl = 'https://jup.ag/api/v6';
  static const String _triggerBaseUrl = 'https://jup.ag/api/v6/limit-order';
  static const _dcaBaseUrl = 'https://jup.ag/api/v6/dca';

  /// Get swap quote from Jupiter Ultra API (Real Implementation)
  Future<JupiterQuote> getSwapQuote({
    required String inputMint,
    required String outputMint,
    required String amount,
    double? slippageBps,
    Map<String, dynamic>? userPublicKey,
  }) async {
    try {
      _logger.i('Getting Jupiter Ultra swap quote: $inputMint → $outputMint');

      final params = <String, dynamic>{
        'inputMint': inputMint,
        'outputMint': outputMint,
        'amount': amount,
        'slippageBps': slippageBps?.toString(),
        'onlyDirectRoutes': 'false',
        'asLegacyTransaction': 'false',
        'maxAccounts': '20',
      };

      if (userPublicKey != null) {
        params['userPublicKey'] = userPublicKey;
      }

      final response = await _dio.get(
        '$_baseUrl/v6/quote',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final quote = JupiterQuote.fromJson(response.data);
        _logger.i('Jupiter quote received: ${quote.outAmount} ${quote.outputMint}');
        return quote;
      } else {
        throw Exception('Jupiter API error: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to get Jupiter quote: $e');
      throw JupiterException('Failed to get swap quote: $e');
    }
  }

  /// Create swap transaction (Real Implementation)
  Future<JupiterSwapTransaction> createSwapTransaction({
    required JupiterQuote quote,
    required String userPublicKey,
    Map<String, dynamic>? userAccounts,
    bool? asLegacyTransaction,
    bool? useSharedAccounts,
  }) async {
    try {
      _logger.i('Creating Jupiter swap transaction...');

      final params = <String, dynamic>{
        'userPublicKey': userPublicKey,
        'quoteResponse': quote.toJson(),
        'wrapUnwrapSOL': true,
        'useSharedAccounts': useSharedAccounts ?? false,
        'asLegacyTransaction': asLegacyTransaction ?? false,
        'maxAccounts': '20',
      };

      if (userAccounts != null) {
        params['userAccounts'] = userAccounts;
      }

      final response = await _dio.post(
        '$_baseUrl/v6/swap',
        data: params,
      );

      if (response.statusCode == 200) {
        final swapTransaction = JupiterSwapTransaction.fromJson(response.data);
        _logger.i('Jupiter swap transaction created');
        return swapTransaction;
      } else {
        throw Exception('Jupiter API error: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to create swap transaction: $e');
      throw JupiterException('Failed to create swap transaction: $e');
    }
  }

  /// Get limit order quote (Real Implementation)
  Future<JupiterLimitOrderQuote> getLimitOrderQuote({
    required String inputMint,
    required String outputMint,
    required String amount,
    required String side,
    required double price,
  }) async {
    try {
      _logger.i('Getting Jupiter limit order quote...');

      final params = <String, dynamic>{
        'inputMint': inputMint,
        'outputMint': outputMint,
        'amount': amount,
        'side': side,
        'price': price.toString(),
      };

      final response = await _dio.get(
        '$_triggerBaseUrl/quote',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final quote = JupiterLimitOrderQuote.fromJson(response.data);
        _logger.i('Jupiter limit order quote received');
        return quote;
      } else {
        throw Exception('Jupiter API error: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to get limit order quote: $e');
      throw JupiterException('Failed to get limit order quote: $e');
    }
  }

  /// Create limit order (Real Implementation)
  Future<JupiterLimitOrder> createLimitOrder({
    required String userPublicKey,
    required JupiterLimitOrderQuote quote,
    Map<String, dynamic>? userAccounts,
  }) async {
    try {
      _logger.i('Creating Jupiter limit order...');

      final params = <String, dynamic>{
        'userPublicKey': userPublicKey,
        'quote': quote.toJson(),
        'wrapUnwrapSOL': true,
        'useSharedAccounts': false,
      };

      if (userAccounts != null) {
        params['userAccounts'] = userAccounts;
      }

      final response = await _dio.post(
        '$_triggerBaseUrl/create',
        data: params,
      );

      if (response.statusCode == 200) {
        final order = JupiterLimitOrder.fromJson(response.data);
        _logger.i('Jupiter limit order created: ${order.orderId}');
        return order;
      } else {
        throw Exception('Jupiter API error: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to create limit order: $e');
      throw JupiterException('Failed to create limit order: $e');
    }
  }

  /// Get DCA quote (Real Implementation)
  Future<JupiterDCAQuote> getDCAQuote({
    required String inputMint,
    required String outputMint,
    required String totalAmount,
    required int frequency,
    required int cycles,
  }) async {
    try {
      _logger.i('Getting Jupiter DCA quote...');

      final params = <String, dynamic>{
        'inputMint': inputMint,
        'outputMint': outputMint,
        'totalAmount': totalAmount,
        'frequency': frequency.toString(),
        'cycles': cycles.toString(),
      };

      final response = await _dio.get(
        '$_dcaBaseUrl/quote',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final quote = JupiterDCAQuote.fromJson(response.data);
        _logger.i('Jupiter DCA quote received');
        return quote;
      } else {
        throw Exception('Jupiter API error: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to get DCA quote: $e');
      throw JupiterException('Failed to get DCA quote: $e');
    }
  }

  /// Create DCA order (Real Implementation)
  Future<JupiterDCAOrder> createDCAOrder({
    required String userPublicKey,
    required JupiterDCAQuote quote,
    Map<String, dynamic>? userAccounts,
  }) async {
    try {
      _logger.i('Creating Jupiter DCA order...');

      final params = <String, dynamic>{
        'userPublicKey': userPublicKey,
        'quote': quote.toJson(),
        'wrapUnwrapSOL': true,
        'useSharedAccounts': false,
      };

      if (userAccounts != null) {
        params['userAccounts'] = userAccounts;
      }

      final response = await _dio.post(
        '$_dcaBaseUrl/create',
        data: params,
      );

      if (response.statusCode == 200) {
        final order = JupiterDCAOrder.fromJson(response.data);
        _logger.i('Jupiter DCA order created: ${order.orderId}');
        return order;
      } else {
        throw Exception('Jupiter API error: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to create DCA order: $e');
      throw JupiterException('Failed to create DCA order: $e');
    }
  }

  /// Search tokens (Real Implementation)
  Future<List<JupiterToken>> searchTokens(String query) async {
    try {
      _logger.i('Searching tokens: $query');

      final params = <String, dynamic>{
        'query': query,
        'limit': '20',
      };

      final response = await _dio.get(
        '$_v6BaseUrl/tokens',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final tokens = (response.data as List)
            .map((json) => JupiterToken.fromJson(json))
            .toList();
        
        _logger.i('Found ${tokens.length} tokens');
        return tokens;
      } else {
        throw Exception('Jupiter API error: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Failed to search tokens: $e');
      throw JupiterException('Failed to search tokens: $e');
    }
  }

  /// Get token info (Real Implementation)
  Future<JupiterToken?> getTokenInfo(String mintAddress) async {
    try {
      _logger.i('Getting token info: $mintAddress');

      final response = await _dio.get(
        '$_v6BaseUrl/token',
        queryParameters: {'mint': mintAddress},
      );

      if (response.statusCode == 200) {
        final token = JupiterToken.fromJson(response.data);
        _logger.i('Token info retrieved: ${token.name}');
        return token;
      } else {
        return null;
      }
    } catch (e) {
      _logger.e('Failed to get token info: $e');
      return null;
    }
  }

  /// Get token price (Real Implementation)
  Future<TokenPrice> getTokenPrice(String mintAddress) async {
    try {
      _logger.i('Getting token price: $mintAddress');

      final token = await getTokenInfo(mintAddress);
      
      if (token == null) {
        throw Exception('Token not found');
      }

      return TokenPrice(
        mint: mintAddress,
        symbol: token.symbol,
        price: token.price,
        priceChange24h: Decimal.zero, // Would need price history API
        volume24h: token.volume24h,
        liquidity: token.liquidity,
      );
    } catch (e) {
      _logger.e('Failed to get token price: $e');
      rethrow;
    }
  }

  /// Validate transaction (Real Implementation)
  Future<TransactionValidation> validateTransaction({
    required String fromMint,
    required String toMint,
    required Decimal amount,
    required double slippage,
  }) async {
    try {
      _logger.i('Validating transaction: $amount $fromMint → $toMint');

      final warnings = <String>[];
      bool isValid = true;

      // Check if tokens exist
      final fromToken = await getTokenInfo(fromMint);
      final toToken = await getTokenInfo(toMint);

      if (fromToken == null) {
        warnings.add('Source token not found');
        isValid = false;
      }

      if (toToken == null) {
        warnings.add('Target token not found');
        isValid = false;
      }

      // Check slippage
      if (slippage > 5.0) {
        warnings.add('High slippage tolerance: ${slippage.toStringAsFixed(1)}%');
      }

      // Check amount
      if (fromToken != null) {
        final fromValue = amount * fromToken.price;
        if (fromValue < Decimal.fromInt(1)) {
          warnings.add('Very small transaction amount');
        }
      }

      // Check token security
      if (fromToken != null) {
        final fromSecurity = await checkTokenSecurity(fromMint);
        if (fromSecurity.riskLevel == TokenRiskLevel.high) {
          warnings.add('Source token has high risk level');
          isValid = false;
        }
      }

      if (toToken != null) {
        final toSecurity = await checkTokenSecurity(toMint);
        if (toSecurity.riskLevel == TokenRiskLevel.high) {
          warnings.add('Target token has high risk level');
          isValid = false;
        }
      }

      return TransactionValidation(
        isValid: isValid,
        warnings: warnings,
        riskLevel: warnings.isEmpty ? TransactionRiskLevel.low : TransactionRiskLevel.medium,
      );
    } catch (e) {
      _logger.e('Failed to validate transaction: $e');
      return TransactionValidation(
        isValid: false,
        warnings: ['Transaction validation failed'],
        riskLevel: TransactionRiskLevel.high,
      );
    }
  }

  /// Check token security (Real Implementation)
  Future<TokenSecurity> checkTokenSecurity(String mintAddress) async {
    try {
      _logger.i('Checking token security: $mintAddress');

      final token = await getTokenInfo(mintAddress);
      
      if (token == null) {
        return TokenSecurity(
          mint: mintAddress,
          isVerified: false,
          riskLevel: TokenRiskLevel.high,
          warnings: ['Token not found'],
        );
      }

      final warnings = <String>[];
      TokenRiskLevel riskLevel = TokenRiskLevel.low;

      // Check if token is verified
      if (!token.verified) {
        warnings.add('Token is not verified');
        riskLevel = TokenRiskLevel.medium;
      }

      // Check liquidity
      if (token.liquidity < Decimal.fromInt(1000)) {
        warnings.add('Low liquidity: ${token.liquidity.toString()}');
        riskLevel = TokenRiskLevel.high;
      } else if (token.liquidity < Decimal.fromInt(10000)) {
        warnings.add('Moderate liquidity');
        if (riskLevel == TokenRiskLevel.low) {
          riskLevel = TokenRiskLevel.medium;
        }
      }

      // Check volume
      if (token.volume24h < Decimal.fromInt(10000)) {
        warnings.add('Low 24h volume: ${token.volume24h.toString()}');
        if (riskLevel == TokenRiskLevel.low) {
          riskLevel = TokenRiskLevel.medium;
        }
      }

      // Check token name for scam patterns
      final nameLower = token.name.toLowerCase();
      final symbolLower = token.symbol.toLowerCase();
      
      for (final pattern in _scamPatterns) {
        if (nameLower.contains(pattern) || symbolLower.contains(pattern)) {
          warnings.add('Token name contains suspicious pattern: $pattern');
          riskLevel = TokenRiskLevel.high;
        }
      }

      // Check if it's a known token
      if (_knownTokens.containsKey(mintAddress)) {
        warnings.clear();
        riskLevel = TokenRiskLevel.low;
      }

      return TokenSecurity(
        mint: mintAddress,
        isVerified: token.verified,
        riskLevel: riskLevel,
        warnings: warnings,
      );
    } catch (e) {
      _logger.e('Failed to check token security: $e');
      return TokenSecurity(
        mint: mintAddress,
        isVerified: false,
        riskLevel: TokenRiskLevel.high,
        warnings: ['Security check failed'],
      );
    }
  }

  // Known scam/rug pull patterns
  static const List<String> _scamPatterns = [
    '100x',
    '1000x',
    'pump',
    'rug',
    'honeypot',
    'scam',
    'fake',
    'copy',
    'clone',
  ];

  // Known legitimate token contracts
  static const Map<String, String> _knownTokens = {
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v': 'USDC',
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB': 'USDT',
    'So11111111111111111111111111111111111111111111112': 'SOL',
    'DezXAZ8z7PnaaSvvvB9DB1xbWEu1k7UPWbPmXMKsJ8': 'RAY',
    'SRMuApVNdxXokkq5xNvTgzDamCYF5y8eM4v9JNS6JvD': 'SRM',
  };
}
