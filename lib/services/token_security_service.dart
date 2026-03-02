import 'package:logger/logger.dart';
import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'jupiter_service.dart';
import 'jupiter_models.dart';

/// Token Security and Metadata Service
/// Based on SeekerClaw's token security implementation
class TokenSecurityService {
  static final TokenSecurityService _instance = TokenSecurityService._internal();
  factory TokenSecurityService() => _instance;
  TokenSecurityService._internal();

  final Logger _logger = Logger();
  final JupiterService _jupiterService = JupiterService();
  
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
    'So11111111111111111111111111111111111111112': 'SOL',
    'DezXAZ8z7PnaaSvvvB9DB1xbWEu1k7UPWbPmXMKsJ8': 'RAY',
    'SRMuApVNdxXokkq5xNvTgzDamCYF5y8eM4v9JNS6JvD': 'SRM',
  };

  /// Check token security
  Future<TokenSecurity> checkTokenSecurity(String mintAddress) async {
    try {
      _logger.i('Checking token security: $mintAddress');

      // Get token info from Jupiter
      final token = await _jupiterService.getTokenInfo(mintAddress);
      
      if (token == null) {
        return TokenSecurity(
          mint: mintAddress,
          isVerified: false,
          riskLevel: TokenRiskLevel.high,
          warnings: ['Token not found in Jupiter database'],
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

  /// Get token metadata
  Future<TokenMetadata> getTokenMetadata(String mintAddress) async {
    try {
      _logger.i('Getting token metadata: $mintAddress');

      final token = await _jupiterService.getTokenInfo(mintAddress);
      
      if (token == null) {
        return TokenMetadata(
          mint: mintAddress,
          name: 'Unknown Token',
          symbol: 'UNKNOWN',
          decimals: 0,
          logoURI: '',
          description: 'Token metadata not available',
          tags: [],
        );
      }

      return TokenMetadata(
        mint: mintAddress,
        name: token.name,
        symbol: token.symbol,
        decimals: (token.decimals * 1).toInt(),
        logoURI: token.logoURI,
        description: _generateDescription(token),
        tags: token.tags.split(',').map((tag) => tag.trim()).toList(),
      );
    } catch (e) {
      _logger.e('Failed to get token metadata: $e');
      return TokenMetadata(
        mint: mintAddress,
        name: 'Unknown Token',
        symbol: 'UNKNOWN',
        decimals: 0,
        logoURI: '',
        description: 'Failed to fetch metadata',
        tags: [],
      );
    }
  }

  /// Search tokens with security check
  Future<List<TokenSearchResult>> searchTokens(String query) async {
    try {
      _logger.i('Searching tokens: $query');

      final tokens = await _jupiterService.searchTokens(query);
      final results = <TokenSearchResult>[];

      for (final token in tokens) {
        final security = await checkTokenSecurity(token.address);
        results.add(TokenSearchResult(
          token: token,
          security: security,
        ));
      }

      // Sort by security (low risk first) then by liquidity
      results.sort((a, b) {
        final riskComparison = a.security.riskLevel.index.compareTo(b.security.riskLevel.index);
        if (riskComparison != 0) return riskComparison;
        return b.token.liquidity.compareTo(a.token.liquidity);
      });

      return results;
    } catch (e) {
      _logger.e('Failed to search tokens: $e');
      return [];
    }
  }

  /// Get token price
  Future<TokenPrice> getTokenPrice(String mintAddress) async {
    try {
      _logger.i('Getting token price: $mintAddress');

      final token = await _jupiterService.getTokenInfo(mintAddress);
      
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

  /// Validate transaction
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
      final fromToken = await _jupiterService.getTokenInfo(fromMint);
      final toToken = await _jupiterService.getTokenInfo(toMint);

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

  String _generateDescription(JupiterToken token) {
    final description = StringBuffer();
    description.write('${token.name} (${token.symbol})');
    
    if (token.verified) {
      description.write(' is a verified token');
    } else {
      description.write(' is an unverified token');
    }
    
    if (token.liquidity > Decimal.zero) {
      description.write(' with ${token.liquidity.toString()} in liquidity');
    }
    
    if (token.volume24h > Decimal.zero) {
      description.write(' and ${token.volume24h.toString()} in 24h volume');
    }
    
    return description.toString();
  }
}

/// Token security model
class TokenSecurity extends Equatable {
  final String mint;
  final bool isVerified;
  final TokenRiskLevel riskLevel;
  final List<String> warnings;

  const TokenSecurity({
    required this.mint,
    required this.isVerified,
    required this.riskLevel,
    required this.warnings,
  });

  @override
  List<Object?> get props => [mint, isVerified, riskLevel, warnings];
}

/// Token metadata model
class TokenMetadata extends Equatable {
  final String mint;
  final String name;
  final String symbol;
  final int decimals;
  final String logoURI;
  final String description;
  final List<String> tags;

  const TokenMetadata({
    required this.mint,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.logoURI,
    required this.description,
    required this.tags,
  });

  @override
  List<Object?> get props => [mint, name, symbol, decimals, logoURI, description, tags];
}

/// Token search result model
class TokenSearchResult extends Equatable {
  final JupiterToken token;
  final TokenSecurity security;

  const TokenSearchResult({
    required this.token,
    required this.security,
  });

  @override
  List<Object?> get props => [token, security];
}

/// Token price model
class TokenPrice extends Equatable {
  final String mint;
  final String symbol;
  final Decimal price;
  final Decimal priceChange24h;
  final Decimal volume24h;
  final Decimal liquidity;

  const TokenPrice({
    required this.mint,
    required this.symbol,
    required this.price,
    required this.priceChange24h,
    required this.volume24h,
    required this.liquidity,
  });

  @override
  List<Object?> get props => [mint, symbol, price, priceChange24h, volume24h, liquidity];
}

/// Transaction validation model
class TransactionValidation extends Equatable {
  final bool isValid;
  final List<String> warnings;
  final TransactionRiskLevel riskLevel;

  const TransactionValidation({
    required this.isValid,
    required this.warnings,
    required this.riskLevel,
  });

  @override
  List<Object?> get props => [isValid, warnings, riskLevel];
}

/// Token risk level enum
enum TokenRiskLevel {
  low,
  medium,
  high,
}

/// Transaction risk level enum
enum TransactionRiskLevel {
  low,
  medium,
  high,
}
