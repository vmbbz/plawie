import 'bridge_http_client.dart';
import 'bridge_funding_strategy.dart';
import 'bridge_models.dart';
import 'solana_transaction_envelope.dart';

abstract interface class RelayDepositProvider {
  Future<RelayDepositInstruction> createInstruction(
    BridgeFundingRequest request,
  );

  Future<BridgeFundingObservation> status(BridgeFundingReceipt receipt);
}

final class RelayDepositService implements RelayDepositProvider {
  RelayDepositService({
    BridgeHttpTransport? transport,
    required Set<int> supportedSourceChainIds,
    DateTime Function()? clock,
    SolanaTransactionEnvelope solanaEnvelope =
        const SolanaTransactionEnvelope(),
  })  : _transport = transport ?? BridgeHttpClient(),
        _supportedSourceChainIds =
            Set<int>.unmodifiable(supportedSourceChainIds),
        _clock = clock ?? DateTime.now,
        _solanaEnvelope = solanaEnvelope;

  static final Uri _quoteUri = Uri.https('api.relay.link', '/quote/v2');
  static const Duration _instructionLifetime = Duration(minutes: 10);

  final BridgeHttpTransport _transport;
  final Set<int> _supportedSourceChainIds;
  final DateTime Function() _clock;
  final SolanaTransactionEnvelope _solanaEnvelope;

  @override
  Future<RelayDepositInstruction> createInstruction(
    BridgeFundingRequest request,
  ) async {
    _validateRequest(request);
    final response = await _transport.postJson(
      _quoteUri,
      <String, Object?>{
        'user': request.baseDestinationAddress,
        'originChainId': request.sourceChain.id,
        'destinationChainId': BridgeConstants.baseChainId,
        'originCurrency': request.sourceToken.address,
        'destinationCurrency': BridgeConstants.baseUsdc,
        'amount': request.amountUnits,
        'tradeType': 'EXACT_INPUT',
        'recipient': request.baseDestinationAddress,
        'refundTo': request.refundAddress,
        'useDepositAddress': true,
        'strict': true,
      },
      maxBytes: 256 * 1024,
    );
    _requireOk(response, 'relay_quote');
    final json = _requiredMap(response.json, 'invalid_relay_quote');
    final steps = json['steps'];
    if (steps is! List) {
      throw const BridgeValidationException('invalid_relay_deposit_step');
    }
    final deposits = steps.where((step) {
      if (step is! Map) return false;
      return Map<String, Object?>.from(step)['id'] == 'deposit';
    }).toList();
    if (deposits.length != 1) {
      throw const BridgeValidationException('invalid_relay_deposit_step');
    }
    final deposit = _requiredMap(
      deposits.single,
      'invalid_relay_deposit_step',
    );
    final requestId = deposit['requestId'];
    final depositAddress = deposit['depositAddress'];
    if (deposit['kind'] != 'transaction' ||
        requestId is! String ||
        !_validRequestId(requestId) ||
        depositAddress is! String ||
        !_validAddressForChain(depositAddress, request.sourceChain)) {
      throw const BridgeValidationException('invalid_relay_deposit_step');
    }
    _validateStatusCheck(deposit['items'], requestId);

    final details = _requiredMap(json['details'], 'invalid_relay_quote');
    if (!_sameAddress(
      details['recipient'],
      request.baseDestinationAddress,
      BridgeChainType.evm,
    )) {
      throw const BridgeValidationException('relay_recipient_mismatch');
    }
    final echoedRefund = details['refundTo'];
    if (echoedRefund != null &&
        !_sameAddress(
          echoedRefund,
          request.refundAddress!,
          request.sourceChain.type,
        )) {
      throw const BridgeValidationException('relay_refund_mismatch');
    }
    final currencyIn = _requiredMap(
      details['currencyIn'],
      'invalid_relay_currency_in',
    );
    final currencyOut = _requiredMap(
      details['currencyOut'],
      'invalid_relay_currency_out',
    );
    _validateCurrencyAmount(
      currencyIn,
      chainId: request.sourceChain.id,
      address: request.sourceToken.address,
      expectedAmount: request.amountUnits,
      chainType: request.sourceChain.type,
      code: 'relay_currency_in_mismatch',
    );
    _validateCurrencyAmount(
      currencyOut,
      chainId: BridgeConstants.baseChainId,
      address: BridgeConstants.baseUsdc,
      chainType: BridgeChainType.evm,
      code: 'relay_currency_out_mismatch',
    );
    final outputAmount = _positiveUnits(
      currencyOut['amount'],
      'invalid_relay_output_amount',
    );
    final minimumOutput = _positiveUnits(
      currencyOut['minimumAmount'] ?? currencyOut['amount'],
      'invalid_relay_minimum_output',
    );
    if (minimumOutput > outputAmount) {
      throw const BridgeValidationException('invalid_relay_minimum_output');
    }
    final estimatedFeesUsd = _parseFeesUsd(json['fees']);
    final createdAt = _clock().toUtc();
    return RelayDepositInstruction(
      requestId: requestId,
      depositAddress: depositAddress,
      request: request,
      minimumOutputUnits: minimumOutput.toString(),
      minimumOutputDisplay: _formatUnits(
        minimumOutput,
        6,
      ),
      createdAt: createdAt,
      expiresAt: createdAt.add(_instructionLifetime),
      estimatedFeesUsd: estimatedFeesUsd,
    );
  }

  @override
  Future<BridgeFundingObservation> status(
    BridgeFundingReceipt receipt,
  ) async {
    _validateReceipt(receipt);
    final byAddress = await _transport.getJson(
      Uri.https(
        'api.relay.link',
        '/requests/v2',
        <String, String>{
          'id': receipt.providerRequestId!,
          'depositAddress': receipt.depositAddress!,
          'includeChildRequests': 'true',
          'originChainId': receipt.sourceChainId.toString(),
          'destinationChainId': BridgeConstants.baseChainId.toString(),
          'sortBy': 'updatedAt',
          'sortDirection': 'desc',
          'limit': '20',
        },
      ),
      maxBytes: 256 * 1024,
    );
    _requireOk(byAddress, 'relay_requests');
    final root = _requiredMap(byAddress.json, 'invalid_relay_requests');
    final requests = root['requests'];
    if (requests is! List) {
      throw const BridgeValidationException('invalid_relay_requests');
    }
    if (requests.isNotEmpty) {
      return _observationFromRequests(receipt, requests);
    }

    final byId = await _transport.getJson(
      Uri.https(
        'api.relay.link',
        '/intents/status/v3',
        <String, String>{'requestId': receipt.providerRequestId!},
      ),
      maxBytes: 64 * 1024,
    );
    _requireOk(byId, 'relay_status');
    return _observationFromStatus(
      receipt,
      _requiredMap(byId.json, 'invalid_relay_status'),
    );
  }

  BridgeFundingObservation _observationFromRequests(
    BridgeFundingReceipt receipt,
    List<Object?> rawRequests,
  ) {
    final requests = <_RelayRequestObservation>[];
    for (var index = 0; index < rawRequests.length; index += 1) {
      requests.add(
        _parseRequestObservation(
          receipt,
          _requiredMap(rawRequests[index], 'invalid_relay_requests'),
          index,
        ),
      );
    }
    if (!requests.any(
      (request) => request.requestId == receipt.providerRequestId,
    )) {
      throw const BridgeValidationException('relay_status_mismatch');
    }
    final newest = requests.reduce(
      (current, candidate) =>
          candidate.isNewerThan(current) ? candidate : current,
    );
    final successes = requests
        .where((request) =>
            request.observation.state == BridgeFundingState.completed)
        .toList();
    final refunds = requests
        .where((request) =>
            request.observation.state == BridgeFundingState.refunded)
        .toList();
    final expectedInput = BigInt.parse(receipt.sourceAmountUnits);
    for (final success in successes) {
      final actualInput = success.inputAmountUnits;
      if (actualInput == null || actualInput < expectedInput) {
        throw const BridgeValidationException('relay_status_mismatch');
      }
    }
    if (successes.isNotEmpty && refunds.isNotEmpty) {
      final success = successes.reduce(
        (current, candidate) =>
            candidate.isNewerThan(current) ? candidate : current,
      );
      final refund = refunds.reduce(
        (current, candidate) =>
            candidate.isNewerThan(current) ? candidate : current,
      );
      return BridgeFundingObservation(
        state: BridgeFundingState.partial,
        providerStatus: 'success_with_refund',
        providerSubstatus: refund.observation.providerSubstatus,
        sourceTransactionHash: refund.observation.sourceTransactionHash ??
            success.observation.sourceTransactionHash,
        destinationTransactionHash:
            success.observation.destinationTransactionHash,
        actualOutputUnits: success.observation.actualOutputUnits,
        observedAt: _clock().toUtc(),
      );
    }
    final overpaidSuccesses = successes
        .where((request) =>
            request.inputAmountUnits != null &&
            request.inputAmountUnits! > expectedInput)
        .toList();
    if (overpaidSuccesses.isNotEmpty) {
      final success = overpaidSuccesses.reduce(
        (current, candidate) =>
            candidate.isNewerThan(current) ? candidate : current,
      );
      return BridgeFundingObservation(
        state: BridgeFundingState.destinationPending,
        providerStatus: 'success_refund_pending',
        providerSubstatus: success.observation.providerSubstatus,
        sourceTransactionHash: success.observation.sourceTransactionHash,
        destinationTransactionHash:
            success.observation.destinationTransactionHash,
        actualOutputUnits: success.observation.actualOutputUnits,
        observedAt: _clock().toUtc(),
      );
    }
    return newest.observation;
  }

  _RelayRequestObservation _parseRequestObservation(
    BridgeFundingReceipt receipt,
    Map<String, Object?> request,
    int responseIndex,
  ) {
    final requestId = request['id'];
    final rawUpdatedAt = request['updatedAt'];
    final updatedAt = rawUpdatedAt == null
        ? null
        : rawUpdatedAt is String
            ? DateTime.tryParse(rawUpdatedAt)?.toUtc()
            : null;
    if (requestId is! String ||
        !_validRequestId(requestId) ||
        (rawUpdatedAt != null && updatedAt == null)) {
      throw const BridgeValidationException('invalid_relay_requests');
    }
    final deposit = request['depositAddress'];
    if (deposit == null) {
      throw const BridgeValidationException('relay_status_mismatch');
    }
    final depositMap = _requiredMap(deposit, 'invalid_relay_requests');
    if (!_sameAddress(
      depositMap['address'],
      receipt.depositAddress!,
      _chainType(receipt.sourceChainId),
    )) {
      throw const BridgeValidationException('relay_status_mismatch');
    }
    if (request['recipient'] is! String) {
      throw const BridgeValidationException('relay_status_mismatch');
    }
    _validateStatusIdentity(receipt, request);
    final data = request['data'] == null
        ? const <String, Object?>{}
        : _requiredMap(request['data'], 'invalid_relay_requests');
    final inputs = _transactionList(data['inTxs'], receipt.sourceChainId);
    final outputs =
        _transactionList(data['outTxs'], BridgeConstants.baseChainId);
    final actualOutput = outputs.isEmpty
        ? _nestedAmount(data['currencyOut'])
        : outputs.last.amount;
    final transactionInput = _totalAmount(inputs);
    final metadataInput = _metadataInputAmount(receipt, data);
    if (transactionInput != null &&
        metadataInput != null &&
        transactionInput != metadataInput) {
      throw const BridgeValidationException('relay_status_mismatch');
    }
    final inputAmount = transactionInput ?? metadataInput;
    return _RelayRequestObservation(
      requestId: requestId,
      updatedAt: updatedAt,
      responseIndex: responseIndex,
      inputAmountUnits: inputAmount == null ? null : BigInt.parse(inputAmount),
      observation: _buildObservation(
        status: request['status'],
        details: data['failReason'],
        sourceHash: inputs.isEmpty ? null : inputs.last.hash,
        destinationHash: outputs.isEmpty ? null : outputs.last.hash,
        actualOutputUnits: actualOutput,
      ),
    );
  }

  BridgeFundingObservation _observationFromStatus(
    BridgeFundingReceipt receipt,
    Map<String, Object?> json,
  ) {
    _validateStatusIdentity(receipt, json);
    final observation = _buildObservation(
      status: json['status'],
      details: json['details'],
      sourceHash: _lastHash(json['inTxHashes'], receipt.sourceChainId),
      destinationHash: _lastHash(json['txHashes'], BridgeConstants.baseChainId),
      actualOutputUnits: null,
    );
    if (observation.state != BridgeFundingState.completed) {
      return observation;
    }
    return BridgeFundingObservation(
      state: BridgeFundingState.destinationPending,
      providerStatus: 'success_amount_unverified',
      providerSubstatus: observation.providerSubstatus,
      sourceTransactionHash: observation.sourceTransactionHash,
      destinationTransactionHash: observation.destinationTransactionHash,
      actualOutputUnits: null,
      observedAt: observation.observedAt,
    );
  }

  BridgeFundingObservation _buildObservation({
    required Object? status,
    required Object? details,
    required String? sourceHash,
    required String? destinationHash,
    required String? actualOutputUnits,
  }) {
    if (status is! String ||
        (details != null && details is! String) ||
        (actualOutputUnits != null &&
            !RegExp(r'^[0-9]+$').hasMatch(actualOutputUnits))) {
      throw const BridgeValidationException('invalid_relay_status');
    }
    final state = switch (status) {
      'waiting' => BridgeFundingState.awaitingDeposit,
      'depositing' => BridgeFundingState.depositDetected,
      'pending' ||
      'submitted' ||
      'delayed' =>
        BridgeFundingState.destinationPending,
      'success' => BridgeFundingState.completed,
      'refund' || 'refunded' => BridgeFundingState.refunded,
      'failure' => BridgeFundingState.failed,
      _ => throw const BridgeValidationException('unsupported_relay_status'),
    };
    return BridgeFundingObservation(
      state: state,
      providerStatus: status,
      providerSubstatus: details as String?,
      sourceTransactionHash: sourceHash,
      destinationTransactionHash: destinationHash,
      actualOutputUnits: actualOutputUnits,
      observedAt: _clock().toUtc(),
    );
  }

  void _validateRequest(BridgeFundingRequest request) {
    if (request.method != BridgeFundingMethod.relayDeposit) {
      throw const BridgeValidationException('strategy_intent_mismatch');
    }
    if (!request.selfCustodyConfirmed) {
      throw const BridgeValidationException(
        'self_custody_confirmation_required',
      );
    }
    if (!_supportedSourceChainIds.contains(request.sourceChain.id)) {
      throw const BridgeValidationException('relay_source_chain_disabled');
    }
    if (request.sourceToken.chainId != request.sourceChain.id ||
        !request.sourceToken.solverDepositable) {
      throw const BridgeValidationException('unsupported_solver_currency');
    }
    if (!_validAddressForChain(
      request.sourceToken.address,
      request.sourceChain,
    )) {
      throw const BridgeValidationException('invalid_source_token');
    }
    if (!_validEvmAddress(request.baseDestinationAddress)) {
      throw const BridgeValidationException('invalid_base_destination');
    }
    if (request.refundAddress == null) {
      throw const BridgeValidationException('refund_address_required');
    }
    if (!_validAddressForChain(request.refundAddress!, request.sourceChain)) {
      throw const BridgeValidationException('invalid_refund_address');
    }
    _positiveUnits(request.amountUnits, 'invalid_bridge_amount');
  }

  void _validateReceipt(BridgeFundingReceipt receipt) {
    if (receipt.method != BridgeFundingMethod.relayDeposit ||
        receipt.provider != 'relay' ||
        receipt.depositAddress == null ||
        receipt.providerRequestId == null ||
        !_validRequestId(receipt.providerRequestId!) ||
        !_validAddress(
          receipt.depositAddress!,
          _chainType(receipt.sourceChainId),
        )) {
      throw const BridgeValidationException('relay_status_not_available');
    }
  }

  void _validateStatusIdentity(
    BridgeFundingReceipt receipt,
    Map<String, Object?> json,
  ) {
    final origin = json['originChainId'];
    final destination = json['destinationChainId'];
    final recipient = json['recipient'];
    if ((origin != null && origin != receipt.sourceChainId) ||
        (destination != null && destination != BridgeConstants.baseChainId) ||
        (recipient != null &&
            !_sameAddress(
              recipient,
              receipt.baseDestinationAddress,
              BridgeChainType.evm,
            ))) {
      throw const BridgeValidationException('relay_status_mismatch');
    }
  }

  void _validateStatusCheck(Object? rawItems, String requestId) {
    if (rawItems is! List || rawItems.length != 1 || rawItems.single is! Map) {
      throw const BridgeValidationException('invalid_relay_deposit_step');
    }
    final item = Map<String, Object?>.from(rawItems.single as Map);
    final check = _requiredMap(
      item['check'],
      'invalid_relay_deposit_step',
    );
    final endpoint = check['endpoint'];
    final uri = endpoint is String ? Uri.tryParse(endpoint) : null;
    if (item['status'] != 'incomplete' ||
        check['method'] != 'GET' ||
        uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.path != '/intents/status/v3' ||
        uri.queryParameters.length != 1 ||
        uri.queryParameters['requestId'] != requestId) {
      throw const BridgeValidationException('invalid_relay_deposit_step');
    }
  }

  void _validateCurrencyAmount(
    Map<String, Object?> amountMap, {
    required int chainId,
    required String address,
    required BridgeChainType chainType,
    required String code,
    String? expectedAmount,
  }) {
    final currency = _requiredMap(amountMap['currency'], code);
    if (currency['chainId'] != chainId ||
        !_sameAddress(currency['address'], address, chainType) ||
        (expectedAmount != null && amountMap['amount'] != expectedAmount)) {
      throw BridgeValidationException(code);
    }
  }

  double? _parseFeesUsd(Object? raw) {
    if (raw == null) return null;
    final fees = _requiredMap(raw, 'invalid_relay_fees');
    var total = 0.0;
    var found = false;
    for (final fee in fees.values) {
      final map = _requiredMap(fee, 'invalid_relay_fees');
      final usd = map['amountUsd'];
      if (usd != null &&
          (usd is! String ||
              double.tryParse(usd) == null ||
              double.parse(usd) < 0)) {
        throw const BridgeValidationException('invalid_relay_fees');
      }
      if (usd != null) {
        total += double.parse(usd as String);
        found = true;
      }
    }
    return found ? total : null;
  }

  List<_RelayTransaction> _transactionList(Object? raw, int chainId) {
    if (raw == null) return const <_RelayTransaction>[];
    if (raw is! List) {
      throw const BridgeValidationException('invalid_relay_status');
    }
    final result = <_RelayTransaction>[];
    for (final value in raw) {
      final map = _requiredMap(value, 'invalid_relay_status');
      final hash = map['hash'] ?? map['txHash'];
      final amount = map['amount'];
      if (map['chainId'] != chainId ||
          (hash != null && (hash is! String || !_validHash(hash, chainId))) ||
          (amount != null &&
              (amount is! String || !RegExp(r'^[0-9]+$').hasMatch(amount)))) {
        throw const BridgeValidationException('relay_status_mismatch');
      }
      if (hash == null) continue;
      result.add(_RelayTransaction(hash as String, amount as String?));
    }
    return result;
  }

  String? _lastHash(Object? raw, int chainId) {
    if (raw == null) return null;
    if (raw is! List || raw.any((value) => value is! String)) {
      throw const BridgeValidationException('invalid_relay_status');
    }
    if (raw.isEmpty) return null;
    final hash = raw.last as String;
    if (!_validHash(hash, chainId)) {
      throw const BridgeValidationException('relay_status_mismatch');
    }
    return hash.startsWith('0x') ? hash.toLowerCase() : hash;
  }

  String? _nestedAmount(Object? raw) {
    if (raw == null) return null;
    final map = _requiredMap(raw, 'invalid_relay_status');
    final amount = map['amount'];
    if (amount == null) return null;
    if (amount is! String || !RegExp(r'^[0-9]+$').hasMatch(amount)) {
      throw const BridgeValidationException('invalid_relay_status');
    }
    return amount;
  }

  String? _totalAmount(List<_RelayTransaction> transactions) {
    if (transactions.isEmpty ||
        transactions.any((transaction) => transaction.amount == null)) {
      return null;
    }
    var total = BigInt.zero;
    for (final transaction in transactions) {
      total += BigInt.parse(transaction.amount!);
    }
    return total.toString();
  }

  String? _metadataInputAmount(
    BridgeFundingReceipt receipt,
    Map<String, Object?> data,
  ) {
    final rawMetadata = data['metadata'];
    if (rawMetadata == null) return null;
    final metadata = _requiredMap(rawMetadata, 'invalid_relay_status');
    final rawCurrencyIn = metadata['currencyIn'];
    if (rawCurrencyIn == null) return null;
    final currencyIn = _requiredMap(rawCurrencyIn, 'invalid_relay_status');
    _validateCurrencyAmount(
      currencyIn,
      chainId: receipt.sourceChainId,
      address: receipt.sourceTokenAddress,
      chainType: _chainType(receipt.sourceChainId),
      code: 'relay_status_mismatch',
    );
    return _nestedAmount(currencyIn);
  }

  bool _validAddressForChain(String value, BridgeChain chain) =>
      _validAddress(value, chain.type);

  bool _validAddress(String value, BridgeChainType type) => switch (type) {
        BridgeChainType.evm => _validEvmAddress(value),
        BridgeChainType.svm => _validSolanaPublicKey(value),
      };

  bool _validSolanaPublicKey(String value) {
    try {
      _solanaEnvelope.base58Decode(value, expectedLength: 32);
      return true;
    } on BridgeValidationException {
      return false;
    }
  }
}

final class RelayDepositAddressStrategy implements BridgeFundingStrategy {
  RelayDepositAddressStrategy({
    required RelayDepositProvider provider,
    required Future<BridgeCapabilitySnapshot> Function() capabilitiesLoader,
  })  : _provider = provider,
        _capabilitiesLoader = capabilitiesLoader;

  final RelayDepositProvider _provider;
  final Future<BridgeCapabilitySnapshot> Function() _capabilitiesLoader;
  RelayDepositInstruction? _pendingInstruction;

  @override
  Future<BridgeCapabilitySnapshot> capabilities() => _capabilitiesLoader();

  @override
  Future<BridgeEstimate> quote(BridgeFundingRequest request) async {
    final instruction = await _provider.createInstruction(request);
    _pendingInstruction = instruction;
    return BridgeEstimate(
      provider: 'relay',
      quoteId: instruction.requestId,
      request: request,
      minimumOutputUnits: instruction.minimumOutputUnits,
      minimumOutputDisplay: instruction.minimumOutputDisplay,
      routeTool: 'strict_deposit',
      quotedAt: instruction.createdAt,
      expiresAt: instruction.expiresAt,
      estimatedFeesUsd: instruction.estimatedFeesUsd,
    );
  }

  @override
  Future<BridgeFundingReceipt> submit(
    ValidatedBridgeFundingIntent intent,
  ) async {
    if (intent is! ValidatedRelayDepositIntent) {
      throw const BridgeValidationException('strategy_intent_mismatch');
    }
    final pending = _pendingInstruction;
    if (pending == null ||
        pending != intent.instruction ||
        pending.request != intent.request) {
      throw const BridgeValidationException('relay_instruction_mismatch');
    }
    _pendingInstruction = null;
    return BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: intent.intentId,
      method: BridgeFundingMethod.relayDeposit,
      provider: 'relay',
      state: BridgeFundingState.awaitingDeposit,
      sourceChainId: intent.request.sourceChain.id,
      sourceTokenAddress: intent.request.sourceToken.address,
      sourceTokenSymbol: intent.request.sourceToken.symbol,
      sourceAmountUnits: intent.request.amountUnits,
      baseDestinationAddress: intent.request.baseDestinationAddress,
      refundAddress: intent.request.refundAddress,
      depositAddress: pending.depositAddress,
      providerRequestId: pending.requestId,
      minimumOutputUnits: pending.minimumOutputUnits,
      providerStatus: 'waiting',
      createdAt: pending.createdAt,
      updatedAt: pending.createdAt,
      expiresAt: pending.expiresAt,
      depositAddressExposed: true,
    );
  }

  @override
  Future<BridgeFundingObservation> status(BridgeFundingReceipt receipt) =>
      _provider.status(receipt);
}

final class _RelayTransaction {
  const _RelayTransaction(this.hash, this.amount);

  final String hash;
  final String? amount;
}

final class _RelayRequestObservation {
  const _RelayRequestObservation({
    required this.requestId,
    required this.updatedAt,
    required this.responseIndex,
    required this.inputAmountUnits,
    required this.observation,
  });

  final String requestId;
  final DateTime? updatedAt;
  final int responseIndex;
  final BigInt? inputAmountUnits;
  final BridgeFundingObservation observation;

  bool isNewerThan(_RelayRequestObservation other) {
    final currentUpdatedAt = updatedAt;
    final otherUpdatedAt = other.updatedAt;
    if (currentUpdatedAt == null || otherUpdatedAt == null) {
      return responseIndex < other.responseIndex;
    }
    final comparison = currentUpdatedAt.compareTo(otherUpdatedAt);
    return comparison > 0 ||
        (comparison == 0 && responseIndex > other.responseIndex);
  }
}

void _requireOk(BridgeHttpResponse response, String code) {
  if (response.statusCode != 200) {
    throw BridgeValidationException('${code}_http_error');
  }
}

Map<String, Object?> _requiredMap(Object? raw, String code) {
  if (raw is! Map) throw BridgeValidationException(code);
  return Map<String, Object?>.from(raw);
}

BigInt _positiveUnits(Object? raw, String code) {
  if (raw is! String || !RegExp(r'^[0-9]+$').hasMatch(raw)) {
    throw BridgeValidationException(code);
  }
  final value = BigInt.parse(raw);
  if (value <= BigInt.zero) throw BridgeValidationException(code);
  return value;
}

String _formatUnits(BigInt value, int decimals) {
  final digits = value.toString().padLeft(decimals + 1, '0');
  final whole = digits.substring(0, digits.length - decimals);
  final fraction = digits
      .substring(digits.length - decimals)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole : '$whole.$fraction';
}

bool _validRequestId(String value) =>
    RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(value);

bool _validEvmAddress(String value) =>
    RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value);

bool _sameAddress(Object? left, String right, BridgeChainType type) =>
    left is String &&
    (type == BridgeChainType.evm
        ? left.toLowerCase() == right.toLowerCase()
        : left == right);

BridgeChainType _chainType(int chainId) =>
    chainId == BridgeConstants.solanaChainId
        ? BridgeChainType.svm
        : BridgeChainType.evm;

bool _validHash(String value, int chainId) =>
    chainId == BridgeConstants.solanaChainId
        ? RegExp(r'^[1-9A-HJ-NP-Za-km-z]{80,90}$').hasMatch(value)
        : RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(value);
