import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';

/// Jupiter Quote model
class JupiterQuote extends Equatable {
  final String inputMint;
  final String outputMint;
  final String inAmount;
  final String outAmount;
  final double priceImpactPct;
  final Map<String, dynamic> routeMap;
  final String? slippage;

  const JupiterQuote({
    required this.inputMint,
    required this.outputMint,
    required this.inAmount,
    required this.outAmount,
    required this.priceImpactPct,
    required this.routeMap,
    this.slippage,
  });

  factory JupiterQuote.fromJson(Map<String, dynamic> json) {
    return JupiterQuote(
      inputMint: json['inputMint'] as String,
      outputMint: json['outputMint'] as String,
      inAmount: json['inAmount'] as String,
      outAmount: json['outAmount'] as String,
      priceImpactPct: (json['priceImpactPct'] as num).toDouble(),
      routeMap: json['routeMap'] as Map<String, dynamic>,
      slippage: json['slippage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inputMint': inputMint,
      'outputMint': outputMint,
      'inAmount': inAmount,
      'outAmount': outAmount,
      'priceImpactPct': priceImpactPct,
      'routeMap': routeMap,
      'slippage': slippage,
    };
  }

  @override
  List<Object?> get props => [
        inputMint,
        outputMint,
        inAmount,
        outAmount,
        priceImpactPct,
        routeMap,
        slippage,
      ];
}

/// Jupiter Swap Transaction model
class JupiterSwapTransaction extends Equatable {
  final String swapTransaction;
  final String lastValidBlockHeight;
  final Map<String, dynamic> prioritizedFeeLookupTable;
  final Map<String, dynamic> computeUnitPriceMicroLamports;
  final bool rewrap;

  const JupiterSwapTransaction({
    required this.swapTransaction,
    required this.lastValidBlockHeight,
    required this.prioritizedFeeLookupTable,
    required this.computeUnitPriceMicroLamports,
    required this.rewrap,
  });

  factory JupiterSwapTransaction.fromJson(Map<String, dynamic> json) {
    return JupiterSwapTransaction(
      swapTransaction: json['swapTransaction'] as String,
      lastValidBlockHeight: json['lastValidBlockHeight'] as String,
      prioritizedFeeLookupTable: json['prioritizedFeeLookupTable'] as Map<String, dynamic>,
      computeUnitPriceMicroLamports: json['computeUnitPriceMicroLamports'] as Map<String, dynamic>,
      rewrap: json['rewrap'] as bool,
    );
  }

  @override
  List<Object?> get props => [
        swapTransaction,
        lastValidBlockHeight,
        prioritizedFeeLookupTable,
        computeUnitPriceMicroLamports,
        rewrap,
      ];
}

/// Jupiter Limit Order Quote model
class JupiterLimitOrderQuote extends Equatable {
  final String inputMint;
  final String outputMint;
  final String amount;
  final String side;
  final double price;
  final String orderId;

  const JupiterLimitOrderQuote({
    required this.inputMint,
    required this.outputMint,
    required this.amount,
    required this.side,
    required this.price,
    required this.orderId,
  });

  factory JupiterLimitOrderQuote.fromJson(Map<String, dynamic> json) {
    return JupiterLimitOrderQuote(
      inputMint: json['inputMint'] as String,
      outputMint: json['outputMint'] as String,
      amount: json['amount'] as String,
      side: json['side'] as String,
      price: (json['price'] as num).toDouble(),
      orderId: json['orderId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inputMint': inputMint,
      'outputMint': outputMint,
      'amount': amount,
      'side': side,
      'price': price,
      'orderId': orderId,
    };
  }

  @override
  List<Object?> get props => [
        inputMint,
        outputMint,
        amount,
        side,
        price,
        orderId,
      ];
}

/// Jupiter DCA Quote model
class JupiterDCAQuote extends Equatable {
  final String inputMint;
  final String outputMint;
  final String totalAmount;
  final int frequency;
  final int cycles;
  final String orderId;

  const JupiterDCAQuote({
    required this.inputMint,
    required this.outputMint,
    required this.totalAmount,
    required this.frequency,
    required this.cycles,
    required this.orderId,
  });

  factory JupiterDCAQuote.fromJson(Map<String, dynamic> json) {
    return JupiterDCAQuote(
      inputMint: json['inputMint'] as String,
      outputMint: json['outputMint'] as String,
      totalAmount: json['totalAmount'] as String,
      frequency: json['frequency'] as int,
      cycles: json['cycles'] as int,
      orderId: json['orderId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inputMint': inputMint,
      'outputMint': outputMint,
      'totalAmount': totalAmount,
      'frequency': frequency,
      'cycles': cycles,
      'orderId': orderId,
    };
  }

  @override
  List<Object?> get props => [
        inputMint,
        outputMint,
        totalAmount,
        frequency,
        cycles,
        orderId,
      ];
}

/// Jupiter Limit Order model
class JupiterLimitOrder extends Equatable {
  final String orderId;
  final String inputMint;
  final String outputMint;
  final String amount;
  final String side;
  final double price;
  final String status;
  final DateTime createdAt;

  const JupiterLimitOrder({
    required this.orderId,
    required this.inputMint,
    required this.outputMint,
    required this.amount,
    required this.side,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  factory JupiterLimitOrder.fromJson(Map<String, dynamic> json) {
    return JupiterLimitOrder(
      orderId: json['orderId'] as String,
      inputMint: json['inputMint'] as String,
      outputMint: json['outputMint'] as String,
      amount: json['amount'] as String,
      side: json['side'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'inputMint': inputMint,
      'outputMint': outputMint,
      'amount': amount,
      'side': side,
      'price': price,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        orderId,
        inputMint,
        outputMint,
        amount,
        side,
        price,
        status,
        createdAt,
      ];
}

/// Jupiter DCA Order model
class JupiterDCAOrder extends Equatable {
  final String orderId;
  final String inputMint;
  final String outputMint;
  final String totalAmount;
  final int frequency;
  final int cycles;
  final String status;
  final DateTime createdAt;

  const JupiterDCAOrder({
    required this.orderId,
    required this.inputMint,
    required this.outputMint,
    required this.totalAmount,
    required this.frequency,
    required this.cycles,
    required this.status,
    required this.createdAt,
  });

  factory JupiterDCAOrder.fromJson(Map<String, dynamic> json) {
    return JupiterDCAOrder(
      orderId: json['orderId'] as String,
      inputMint: json['inputMint'] as String,
      outputMint: json['outputMint'] as String,
      totalAmount: json['totalAmount'] as String,
      frequency: json['frequency'] as int,
      cycles: json['cycles'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'inputMint': inputMint,
      'outputMint': outputMint,
      'totalAmount': totalAmount,
      'frequency': frequency,
      'cycles': cycles,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        orderId,
        inputMint,
        outputMint,
        totalAmount,
        frequency,
        cycles,
        status,
        createdAt,
      ];
}

/// Jupiter Token model
class JupiterToken extends Equatable {
  final String address;
  final String chainId;
  final String name;
  final String symbol;
  final String logoURI;
  final bool verified;
  final int decimals;
  final Decimal price;
  final Decimal liquidity;
  final Decimal volume24h;
  final String tags;

  const JupiterToken({
    required this.address,
    required this.chainId,
    required this.name,
    required this.symbol,
    required this.logoURI,
    required this.verified,
    required this.decimals,
    required this.price,
    required this.liquidity,
    required this.volume24h,
    required this.tags,
  });

  factory JupiterToken.fromJson(Map<String, dynamic> json) {
    return JupiterToken(
      address: json['address'] as String,
      chainId: json['chainId'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      logoURI: json['logoURI'] as String,
      verified: json['verified'] as bool,
      decimals: (json['decimals'] as num).toInt(),
      price: Decimal.parse(json['price'].toString()),
      liquidity: Decimal.parse(json['liquidity'].toString()),
      volume24h: Decimal.parse(json['volume24h'].toString()),
      tags: json['tags'].toString(),
    );
  }

  @override
  List<Object?> get props => [
        address,
        chainId,
        name,
        symbol,
        logoURI,
        verified,
        decimals,
        price,
        liquidity,
        volume24h,
        tags,
      ];
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

  Map<String, dynamic> toJson() {
    return {
      'mint': mint,
      'symbol': symbol,
      'price': price.toString(),
      'priceChange24h': priceChange24h.toString(),
      'volume24h': volume24h.toString(),
      'liquidity': liquidity.toString(),
    };
  }

  @override
  List<Object?> get props => [
        mint,
        symbol,
        price,
        priceChange24h,
        volume24h,
        liquidity,
      ];
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
  List<Object?> get props => [
        isValid,
        warnings,
        riskLevel,
      ];
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
  List<Object?> get props => [
        mint,
        isVerified,
        riskLevel,
        warnings,
      ];
}

/// Transaction risk level enum
enum TransactionRiskLevel {
  low,
  medium,
  high,
}

/// Token risk level enum
enum TokenRiskLevel {
  low,
  medium,
  high,
}

/// Jupiter exception class
class JupiterException implements Exception {
  final String message;
  const JupiterException(this.message);
}
