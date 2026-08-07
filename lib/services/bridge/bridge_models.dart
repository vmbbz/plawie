import 'package:equatable/equatable.dart';

enum BridgeChainType { evm, svm }

enum BridgeFundingMethod { connectedWallet, relayDeposit, externalJumper }

enum ExternalWalletTransport {
  reownEvm,
  solanaMwa,
  reownSolanaPhantom,
  reownSolanaSolflare,
  baseAccountMwp,
}

enum BridgeFundingState {
  draft,
  checkingCapabilities,
  connectingWallet,
  collectingRefundAddress,
  quoting,
  awaitingPlawieReview,
  awaitingDeposit,
  awaitingExternalWallet,
  depositDetected,
  submitted,
  sourcePending,
  destinationPending,
  completed,
  failed,
  refunded,
  partial,
  expired,
  cancelled,
}

abstract final class BridgeConstants {
  static const int ethereumChainId = 1;
  static const int baseChainId = 8453;
  static const int robinhoodChainId = 4663;
  static const int solanaChainId = 1151111081099710;
  static const String baseUsdc = '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';
}

abstract final class BridgeFeatureConfig {
  static const bool lifiConnectedEnabled = bool.fromEnvironment(
    'ENABLE_LIFI_CONNECTED_BRIDGE',
    defaultValue: false,
  );
  static const bool relayDepositEnabled = bool.fromEnvironment(
    'ENABLE_RELAY_DEPOSIT_BRIDGE',
    defaultValue: false,
  );
  static const bool reownEvmWalletsEnabled = bool.fromEnvironment(
    'ENABLE_REOWN_EVM_WALLETS',
    defaultValue: false,
  );
  static const bool solanaMwaWalletsEnabled = bool.fromEnvironment(
    'ENABLE_SOLANA_MWA_WALLETS',
    defaultValue: false,
  );
  static const bool reownSolanaFallbackEnabled = bool.fromEnvironment(
    'ENABLE_REOWN_SOLANA_FALLBACK',
    defaultValue: false,
  );
  static const bool baseAccountMwpEnabled = bool.fromEnvironment(
    'ENABLE_BASE_ACCOUNT_MWP',
    defaultValue: false,
  );
}

class BridgeValidationException implements Exception {
  const BridgeValidationException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => message.isEmpty
      ? 'BridgeValidationException: $code'
      : 'BridgeValidationException: $code ($message)';
}

class BridgePersistenceException implements Exception {
  const BridgePersistenceException(this.message);

  final String message;

  @override
  String toString() => 'BridgePersistenceException: $message';
}

sealed class BridgeExecutionPayload extends Equatable {
  const BridgeExecutionPayload();
}

final class EvmBridgeExecutionPayload extends BridgeExecutionPayload {
  const EvmBridgeExecutionPayload({
    required this.chainId,
    required this.from,
    required this.to,
    required this.valueHex,
    required this.dataHex,
    required this.gasLimitHex,
    required this.approvalAddress,
  });

  final int chainId;
  final String from;
  final String to;
  final String valueHex;
  final String dataHex;
  final String gasLimitHex;
  final String? approvalAddress;

  @override
  List<Object?> get props => <Object?>[
        chainId,
        from,
        to,
        valueHex,
        dataHex,
        gasLimitHex,
        approvalAddress,
      ];
}

final class SolanaBridgeExecutionPayload extends BridgeExecutionPayload {
  const SolanaBridgeExecutionPayload({
    required this.from,
    required this.base64Transaction,
  });

  final String from;
  final String base64Transaction;

  @override
  List<Object?> get props => <Object?>[from, base64Transaction];
}

final class BridgeChain extends Equatable {
  const BridgeChain({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.nativeTokenSymbol,
  });

  final int id;
  final String key;
  final String name;
  final BridgeChainType type;
  final String nativeTokenSymbol;

  @override
  List<Object?> get props => <Object?>[
        id,
        key,
        name,
        type,
        nativeTokenSymbol,
      ];
}

final class BridgeToken extends Equatable {
  const BridgeToken({
    required this.chainId,
    required this.address,
    required this.symbol,
    required this.decimals,
    required this.solverDepositable,
  });

  final int chainId;
  final String address;
  final String symbol;
  final int decimals;
  final bool solverDepositable;

  @override
  List<Object?> get props => <Object?>[
        chainId,
        address,
        symbol,
        decimals,
        solverDepositable,
      ];
}

final class BridgeFundingRequest extends Equatable {
  const BridgeFundingRequest({
    required this.method,
    required this.sourceChain,
    required this.sourceToken,
    required this.amount,
    required this.amountUnits,
    required this.baseDestinationAddress,
    this.sourceAddress,
    this.refundAddress,
    this.selfCustodyConfirmed = false,
  });

  final BridgeFundingMethod method;
  final BridgeChain sourceChain;
  final BridgeToken sourceToken;
  final String amount;
  final String amountUnits;
  final String baseDestinationAddress;
  final String? sourceAddress;
  final String? refundAddress;
  final bool selfCustodyConfirmed;

  @override
  List<Object?> get props => <Object?>[
        method,
        sourceChain,
        sourceToken,
        amount,
        amountUnits,
        baseDestinationAddress,
        sourceAddress,
        refundAddress,
        selfCustodyConfirmed,
      ];
}

final class BridgeEstimate extends Equatable {
  const BridgeEstimate({
    required this.provider,
    required this.quoteId,
    required this.request,
    required this.minimumOutputUnits,
    required this.minimumOutputDisplay,
    required this.routeTool,
    required this.quotedAt,
    required this.expiresAt,
    this.approvalAddress,
    this.estimatedDurationSeconds,
    this.estimatedFeesUsd,
  });

  final String provider;
  final String quoteId;
  final BridgeFundingRequest request;
  final String minimumOutputUnits;
  final String minimumOutputDisplay;
  final String routeTool;
  final DateTime quotedAt;
  final DateTime expiresAt;
  final String? approvalAddress;
  final int? estimatedDurationSeconds;
  final double? estimatedFeesUsd;

  @override
  List<Object?> get props => <Object?>[
        provider,
        quoteId,
        request,
        minimumOutputUnits,
        minimumOutputDisplay,
        routeTool,
        quotedAt,
        expiresAt,
        approvalAddress,
        estimatedDurationSeconds,
        estimatedFeesUsd,
      ];
}

final class BridgeExecutableQuote extends Equatable {
  const BridgeExecutableQuote({
    required this.estimate,
    required this.connectedSourceAddress,
    required this.destinationChainId,
    required this.destinationToken,
    required this.payload,
    required this.fingerprint,
  });

  final BridgeEstimate estimate;
  final String connectedSourceAddress;
  final int destinationChainId;
  final BridgeToken destinationToken;
  final BridgeExecutionPayload payload;
  final String fingerprint;

  @override
  List<Object?> get props => <Object?>[
        estimate,
        connectedSourceAddress,
        destinationChainId,
        destinationToken,
        payload,
        fingerprint,
      ];
}

final class RelayDepositInstruction extends Equatable {
  const RelayDepositInstruction({
    required this.requestId,
    required this.depositAddress,
    required this.request,
    required this.minimumOutputUnits,
    required this.minimumOutputDisplay,
    required this.createdAt,
    required this.expiresAt,
    this.estimatedFeesUsd,
  });

  final String requestId;
  final String depositAddress;
  final BridgeFundingRequest request;
  final String minimumOutputUnits;
  final String minimumOutputDisplay;
  final DateTime createdAt;
  final DateTime expiresAt;
  final double? estimatedFeesUsd;

  @override
  List<Object?> get props => <Object?>[
        requestId,
        depositAddress,
        request,
        minimumOutputUnits,
        minimumOutputDisplay,
        createdAt,
        expiresAt,
        estimatedFeesUsd,
      ];
}

final class BridgeFundingObservation extends Equatable {
  const BridgeFundingObservation({
    required this.state,
    required this.providerStatus,
    required this.observedAt,
    this.providerSubstatus,
    this.sourceTransactionHash,
    this.destinationTransactionHash,
    this.actualOutputUnits,
  });

  final BridgeFundingState state;
  final String providerStatus;
  final String? providerSubstatus;
  final String? sourceTransactionHash;
  final String? destinationTransactionHash;
  final String? actualOutputUnits;
  final DateTime observedAt;

  @override
  List<Object?> get props => <Object?>[
        state,
        providerStatus,
        providerSubstatus,
        sourceTransactionHash,
        destinationTransactionHash,
        actualOutputUnits,
        observedAt,
      ];
}

final class BridgeCapabilitySnapshot extends Equatable {
  const BridgeCapabilitySnapshot({
    required this.schemaVersion,
    required this.refreshedAt,
    required this.connectedChains,
    required this.relayChains,
    required this.connectedTokensByChain,
    required this.relayTokensByChain,
    required this.availabilityReasons,
  });

  final int schemaVersion;
  final DateTime refreshedAt;
  final List<BridgeChain> connectedChains;
  final List<BridgeChain> relayChains;
  final Map<int, List<BridgeToken>> connectedTokensByChain;
  final Map<int, List<BridgeToken>> relayTokensByChain;
  final Map<String, String> availabilityReasons;

  List<BridgeToken> connectedTokensFor(int chainId) =>
      List<BridgeToken>.unmodifiable(
        connectedTokensByChain[chainId] ?? const <BridgeToken>[],
      );

  List<BridgeToken> relayTokensFor(int chainId) =>
      List<BridgeToken>.unmodifiable(
        relayTokensByChain[chainId] ?? const <BridgeToken>[],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'refreshedAt': refreshedAt.toUtc().toIso8601String(),
        'connectedChains': connectedChains.map(_chainToJson).toList(),
        'relayChains': relayChains.map(_chainToJson).toList(),
        'connectedTokensByChain': _tokenMapToJson(connectedTokensByChain),
        'relayTokensByChain': _tokenMapToJson(relayTokensByChain),
        'availabilityReasons': availabilityReasons,
      };

  factory BridgeCapabilitySnapshot.fromJson(Map<String, dynamic> json) {
    final connectedChains = _chainListFromJson(json['connectedChains']);
    final relayChains = _chainListFromJson(json['relayChains']);
    return BridgeCapabilitySnapshot(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      refreshedAt: _requiredDateTime(json, 'refreshedAt'),
      connectedChains: List<BridgeChain>.unmodifiable(connectedChains),
      relayChains: List<BridgeChain>.unmodifiable(relayChains),
      connectedTokensByChain: _tokenMapFromJson(json['connectedTokensByChain']),
      relayTokensByChain: _tokenMapFromJson(json['relayTokensByChain']),
      availabilityReasons: Map<String, String>.unmodifiable(
        _stringMapFromJson(json['availabilityReasons']),
      ),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        schemaVersion,
        refreshedAt,
        connectedChains,
        relayChains,
        connectedTokensByChain,
        relayTokensByChain,
        availabilityReasons,
      ];
}

Map<String, dynamic> _chainToJson(BridgeChain chain) => <String, dynamic>{
      'id': chain.id,
      'key': chain.key,
      'name': chain.name,
      'type': chain.type.name,
      'nativeTokenSymbol': chain.nativeTokenSymbol,
    };

List<BridgeChain> _chainListFromJson(Object? raw) {
  if (raw is! List) throw const FormatException('Invalid bridge chain list.');
  return raw.map((item) {
    if (item is! Map) throw const FormatException('Invalid bridge chain.');
    final json = Map<String, dynamic>.from(item);
    return BridgeChain(
      id: _requiredInt(json, 'id'),
      key: _requiredString(json, 'key'),
      name: _requiredString(json, 'name'),
      type: _requiredEnum(BridgeChainType.values, json['type'], 'type'),
      nativeTokenSymbol: _requiredString(json, 'nativeTokenSymbol'),
    );
  }).toList();
}

Map<String, dynamic> _tokenMapToJson(Map<int, List<BridgeToken>> source) =>
    <String, dynamic>{
      for (final entry in source.entries)
        entry.key.toString(): entry.value
            .map((token) => <String, dynamic>{
                  'chainId': token.chainId,
                  'address': token.address,
                  'symbol': token.symbol,
                  'decimals': token.decimals,
                  'solverDepositable': token.solverDepositable,
                })
            .toList(),
    };

Map<int, List<BridgeToken>> _tokenMapFromJson(Object? raw) {
  if (raw is! Map) throw const FormatException('Invalid bridge token map.');
  final result = <int, List<BridgeToken>>{};
  for (final entry in raw.entries) {
    final chainId = int.tryParse(entry.key.toString());
    if (chainId == null || entry.value is! List) {
      throw const FormatException('Invalid bridge token map entry.');
    }
    result[chainId] = List<BridgeToken>.unmodifiable(
      (entry.value as List).map((item) {
        if (item is! Map) throw const FormatException('Invalid bridge token.');
        final json = Map<String, dynamic>.from(item);
        return BridgeToken(
          chainId: _requiredInt(json, 'chainId'),
          address: _requiredString(json, 'address'),
          symbol: _requiredString(json, 'symbol'),
          decimals: _requiredInt(json, 'decimals'),
          solverDepositable: _optionalBool(json, 'solverDepositable'),
        );
      }),
    );
  }
  return Map<int, List<BridgeToken>>.unmodifiable(result);
}

Map<String, String> _stringMapFromJson(Object? raw) {
  if (raw is! Map) throw const FormatException('Invalid bridge string map.');
  return <String, String>{
    for (final entry in raw.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

final class BridgeFundingReceipt extends Equatable {
  const BridgeFundingReceipt({
    required this.schemaVersion,
    required this.intentId,
    required this.method,
    required this.provider,
    required this.state,
    required this.sourceChainId,
    required this.sourceTokenAddress,
    required this.sourceTokenSymbol,
    required this.sourceAmountUnits,
    required this.baseDestinationAddress,
    required this.createdAt,
    required this.updatedAt,
    this.sourceAddress,
    this.refundAddress,
    this.depositAddress,
    this.providerQuoteId,
    this.providerRequestId,
    this.routeTool,
    this.minimumOutputUnits,
    this.actualOutputUnits,
    this.sourceTransactionHash,
    this.destinationTransactionHash,
    this.providerStatus,
    this.providerSubstatus,
    this.walletTransport,
    this.reviewedPayloadHash,
    this.sourceBlockhash,
    this.expiresAt,
    this.archivedAt,
    this.depositAddressExposed = false,
    this.balanceRefreshPending = false,
    this.submissionOutcomeUnknown = false,
  });

  final int schemaVersion;
  final String intentId;
  final BridgeFundingMethod method;
  final String provider;
  final BridgeFundingState state;
  final int sourceChainId;
  final String sourceTokenAddress;
  final String sourceTokenSymbol;
  final String sourceAmountUnits;
  final String baseDestinationAddress;
  final String? sourceAddress;
  final String? refundAddress;
  final String? depositAddress;
  final String? providerQuoteId;
  final String? providerRequestId;
  final String? routeTool;
  final String? minimumOutputUnits;
  final String? actualOutputUnits;
  final String? sourceTransactionHash;
  final String? destinationTransactionHash;
  final String? providerStatus;
  final String? providerSubstatus;
  final ExternalWalletTransport? walletTransport;
  final String? reviewedPayloadHash;
  final String? sourceBlockhash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final DateTime? archivedAt;
  final bool depositAddressExposed;
  final bool balanceRefreshPending;
  final bool submissionOutcomeUnknown;

  Map<String, dynamic> toJson() {
    _validateLocalRecoveryFields();
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'intentId': intentId,
      'method': method.name,
      'provider': provider,
      'state': state.name,
      'sourceChainId': sourceChainId,
      'sourceTokenAddress': sourceTokenAddress,
      'sourceTokenSymbol': sourceTokenSymbol,
      'sourceAmountUnits': sourceAmountUnits,
      'baseDestinationAddress': baseDestinationAddress,
      if (sourceAddress != null) 'sourceAddress': sourceAddress,
      if (refundAddress != null) 'refundAddress': refundAddress,
      if (depositAddress != null) 'depositAddress': depositAddress,
      if (providerQuoteId != null) 'providerQuoteId': providerQuoteId,
      if (providerRequestId != null) 'providerRequestId': providerRequestId,
      if (routeTool != null) 'routeTool': routeTool,
      if (minimumOutputUnits != null) 'minimumOutputUnits': minimumOutputUnits,
      if (actualOutputUnits != null) 'actualOutputUnits': actualOutputUnits,
      if (sourceTransactionHash != null)
        'sourceTransactionHash': sourceTransactionHash,
      if (destinationTransactionHash != null)
        'destinationTransactionHash': destinationTransactionHash,
      if (providerStatus != null) 'providerStatus': providerStatus,
      if (providerSubstatus != null) 'providerSubstatus': providerSubstatus,
      if (walletTransport != null)
        'walletTransport': _walletTransportName(walletTransport!),
      if (reviewedPayloadHash != null)
        'reviewedPayloadHash': reviewedPayloadHash,
      if (sourceBlockhash != null) 'sourceBlockhash': sourceBlockhash,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
      if (archivedAt != null)
        'archivedAt': archivedAt!.toUtc().toIso8601String(),
      'depositAddressExposed': depositAddressExposed,
      'balanceRefreshPending': balanceRefreshPending,
      'submissionOutcomeUnknown': submissionOutcomeUnknown,
    };
  }

  Map<String, dynamic> toAgentJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'intentId': intentId,
        'method': method.name,
        'provider': provider,
        'state': state.name,
        'sourceChainId': sourceChainId,
        'sourceTokenAddress': _shortenAddress(sourceTokenAddress),
        'sourceTokenSymbol': sourceTokenSymbol,
        'sourceAmountUnits': sourceAmountUnits,
        'baseDestinationAddress': _shortenAddress(baseDestinationAddress),
        if (sourceAddress != null)
          'sourceAddress': _shortenAddress(sourceAddress!),
        if (refundAddress != null)
          'refundAddress': _shortenAddress(refundAddress!),
        if (depositAddress != null)
          'depositAddress': _shortenAddress(depositAddress!),
        if (providerQuoteId != null) 'providerQuoteId': providerQuoteId,
        if (providerRequestId != null) 'providerRequestId': providerRequestId,
        if (routeTool != null) 'routeTool': routeTool,
        if (minimumOutputUnits != null)
          'minimumOutputUnits': minimumOutputUnits,
        if (actualOutputUnits != null) 'actualOutputUnits': actualOutputUnits,
        if (sourceTransactionHash != null)
          'sourceTransactionHash': sourceTransactionHash,
        if (destinationTransactionHash != null)
          'destinationTransactionHash': destinationTransactionHash,
        if (providerStatus != null) 'providerStatus': providerStatus,
        if (providerSubstatus != null) 'providerSubstatus': providerSubstatus,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (expiresAt != null)
          'expiresAt': expiresAt!.toUtc().toIso8601String(),
        if (archivedAt != null)
          'archivedAt': archivedAt!.toUtc().toIso8601String(),
        'depositAddressExposed': depositAddressExposed,
        'balanceRefreshPending': balanceRefreshPending,
        'submissionOutcomeUnknown': submissionOutcomeUnknown,
      };

  factory BridgeFundingReceipt.fromJson(Map<String, dynamic> json) {
    final walletTransport = _optionalEnum(
      ExternalWalletTransport.values,
      json['walletTransport'],
      'walletTransport',
    );
    final receipt = BridgeFundingReceipt(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      intentId: _requiredString(json, 'intentId'),
      method: _requiredEnum(
        BridgeFundingMethod.values,
        json['method'],
        'method',
      ),
      provider: _requiredString(json, 'provider'),
      state: _requiredEnum(
        BridgeFundingState.values,
        json['state'],
        'state',
      ),
      sourceChainId: _requiredInt(json, 'sourceChainId'),
      sourceTokenAddress: _requiredString(json, 'sourceTokenAddress'),
      sourceTokenSymbol: _requiredString(json, 'sourceTokenSymbol'),
      sourceAmountUnits: _requiredString(json, 'sourceAmountUnits'),
      baseDestinationAddress: _requiredString(json, 'baseDestinationAddress'),
      sourceAddress: _optionalString(json, 'sourceAddress'),
      refundAddress: _optionalString(json, 'refundAddress'),
      depositAddress: _optionalString(json, 'depositAddress'),
      providerQuoteId: _optionalString(json, 'providerQuoteId'),
      providerRequestId: _optionalString(json, 'providerRequestId'),
      routeTool: _optionalString(json, 'routeTool'),
      minimumOutputUnits: _optionalString(json, 'minimumOutputUnits'),
      actualOutputUnits: _optionalString(json, 'actualOutputUnits'),
      sourceTransactionHash: _optionalString(json, 'sourceTransactionHash'),
      destinationTransactionHash:
          _optionalString(json, 'destinationTransactionHash'),
      providerStatus: _optionalString(json, 'providerStatus'),
      providerSubstatus: _optionalString(json, 'providerSubstatus'),
      walletTransport: walletTransport,
      reviewedPayloadHash: _optionalString(json, 'reviewedPayloadHash'),
      sourceBlockhash: _optionalString(json, 'sourceBlockhash'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      expiresAt: _optionalDateTime(json, 'expiresAt'),
      archivedAt: _optionalDateTime(json, 'archivedAt'),
      depositAddressExposed: _optionalBool(json, 'depositAddressExposed'),
      balanceRefreshPending: _optionalBool(json, 'balanceRefreshPending'),
      submissionOutcomeUnknown: _optionalBool(json, 'submissionOutcomeUnknown'),
    );
    receipt._validateLocalRecoveryFields();
    return receipt;
  }

  void _validateLocalRecoveryFields() {
    final hash = reviewedPayloadHash;
    if (hash != null && !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const BridgeValidationException(
        'invalid_reviewed_payload_hash',
        'reviewedPayloadHash must be a lowercase SHA-256 hex digest.',
      );
    }
    if (sourceBlockhash != null &&
        sourceChainId != BridgeConstants.solanaChainId) {
      throw const BridgeValidationException(
        'invalid_source_blockhash_chain',
        'sourceBlockhash is valid only for Solana reconciliation.',
      );
    }
  }

  @override
  List<Object?> get props => <Object?>[
        schemaVersion,
        intentId,
        method,
        provider,
        state,
        sourceChainId,
        sourceTokenAddress,
        sourceTokenSymbol,
        sourceAmountUnits,
        baseDestinationAddress,
        sourceAddress,
        refundAddress,
        depositAddress,
        providerQuoteId,
        providerRequestId,
        routeTool,
        minimumOutputUnits,
        actualOutputUnits,
        sourceTransactionHash,
        destinationTransactionHash,
        providerStatus,
        providerSubstatus,
        walletTransport,
        reviewedPayloadHash,
        sourceBlockhash,
        createdAt,
        updatedAt,
        expiresAt,
        archivedAt,
        depositAddressExposed,
        balanceRefreshPending,
        submissionOutcomeUnknown,
      ];
}

String _walletTransportName(ExternalWalletTransport transport) =>
    switch (transport) {
      ExternalWalletTransport.reownEvm => 'reownEvm',
      ExternalWalletTransport.solanaMwa => 'solanaMwa',
      ExternalWalletTransport.reownSolanaPhantom => 'reownSolanaPhantom',
      ExternalWalletTransport.reownSolanaSolflare => 'reownSolanaSolflare',
      ExternalWalletTransport.baseAccountMwp => 'baseAccountMwp',
    };

String _shortenAddress(String address) {
  if (address.startsWith('0x') && address.length > 10) {
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
  if (address.length > 8) {
    return '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
  }
  return address;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid bridge receipt $key.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid bridge receipt $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Invalid bridge receipt $key.');
  }
  return value;
}

bool _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return false;
  if (value is! bool) {
    throw FormatException('Invalid bridge receipt $key.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Invalid bridge receipt $key.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid bridge receipt $key.');
  }
  return parsed.toUtc();
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return _requiredDateTime(json, key);
}

T _requiredEnum<T extends Enum>(
  List<T> values,
  Object? raw,
  String key,
) {
  return _optionalEnum(values, raw, key) ??
      (throw FormatException('Invalid bridge receipt $key.'));
}

T? _optionalEnum<T extends Enum>(
  List<T> values,
  Object? raw,
  String key,
) {
  if (raw == null) return null;
  if (raw is! String) {
    throw FormatException('Invalid bridge receipt $key.');
  }
  for (final value in values) {
    final serialized = value is ExternalWalletTransport
        ? _walletTransportName(value)
        : value.name;
    if (serialized == raw) return value;
  }
  throw FormatException('Invalid bridge receipt $key.');
}
