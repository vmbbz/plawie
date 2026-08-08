import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'bridge_models.dart';
import 'bridge_receipt_store.dart';
import 'bridge_state_machine.dart';
import 'evm_bridge_rpc_service.dart';
import 'external_wallet_session_service.dart';
import 'lifi_bridge_service.dart';
import 'lifi_status_service.dart';
import 'lifi_transaction_validator.dart';
import 'relay_deposit_service.dart';
import 'solana_rpc_broadcaster.dart';
import 'solana_transaction_envelope.dart';

enum BridgeReviewKind { allowance, bridge }

enum SolanaRecoveryScanResult { matched, inconclusive, ambiguous, expired }

abstract interface class BridgeFundingUiController {
  BridgeFundingReceipt? get activeReceipt;

  List<BridgeFundingReceipt> get receipts;

  ExternalWalletIdentity? get connectedExternalWallet;

  BridgeReviewKind? pendingReviewKind(String intentId);

  Future<List<ExternalWalletOption>> discoverWallets(BridgeChain chain);

  Future<void> disconnectExternalWallet();

  Future<void> prepareConnected(
    BridgeFundingRequest request, {
    ExternalWalletTransport? transport,
  });

  Future<RelayDepositInstruction> prepareRelayDeposit(
    BridgeFundingRequest request, {
    bool oldAddressWarningAcknowledged = false,
  });

  Future<void> confirmEvmAllowance(String intentId);

  Future<void> confirmConnectedBridge(String intentId);

  Future<void> cancelBeforeSubmission(String intentId);

  Future<void> refreshStatus(String intentId);

  Future<void> pollSettlement(String intentId, {int maxObservations = 7});

  Future<void> refreshBaseBalance(String intentId);

  Future<void> archiveRelayInstructions(String intentId);

  Future<void> recoverEvmTransactionHash(
    String intentId,
    String transactionHash,
  );

  Future<void> recoverSolanaSignature(String intentId, String signature);

  Future<SolanaRecoveryScanResult> scanSolanaRecovery(String intentId);
}

abstract interface class BridgeExecutableQuoteProvider {
  Future<BridgeExecutableQuote> executableQuote(
    BridgeFundingRequest request, {
    required String connectedSourceAddress,
  });
}

final class LifiExecutableQuoteProvider
    implements BridgeExecutableQuoteProvider {
  const LifiExecutableQuoteProvider(this._service);

  final LifiBridgeService _service;

  @override
  Future<BridgeExecutableQuote> executableQuote(
    BridgeFundingRequest request, {
    required String connectedSourceAddress,
  }) =>
      _service.executableQuote(
        request,
        connectedSourceAddress: connectedSourceAddress,
      );
}

abstract interface class BaseBalanceRefreshService {
  Future<bool> refresh();
}

final class BridgeFundingController implements BridgeFundingUiController {
  BridgeFundingController({
    required BridgeExecutableQuoteProvider quoteProvider,
    required ExternalWalletSessionService wallet,
    required BridgeReceiptStore receiptStore,
    required EvmBridgeRpc rpc,
    required SolanaRpcBroadcaster solanaRpc,
    required BaseBalanceRefreshService baseBalance,
    required String Function() internalBaseAddress,
    LifiSettlementStatusProvider? lifiStatus,
    RelayDepositProvider? relay,
    bool lifiConnectedEnabled = BridgeFeatureConfig.lifiConnectedEnabled,
    bool relayDepositEnabled = BridgeFeatureConfig.relayDepositEnabled,
    bool reownEvmEnabled = BridgeFeatureConfig.reownEvmWalletsEnabled,
    bool solanaMwaEnabled = BridgeFeatureConfig.solanaMwaWalletsEnabled,
    bool reownSolanaFallbackEnabled =
        BridgeFeatureConfig.reownSolanaFallbackEnabled,
    bool baseAccountMwpEnabled = BridgeFeatureConfig.baseAccountMwpEnabled,
    LifiTransactionValidator transactionValidator =
        const LifiTransactionValidator(),
    SolanaTransactionEnvelope solanaEnvelope =
        const SolanaTransactionEnvelope(),
    DateTime Function()? clock,
    String Function()? intentIdFactory,
    Future<void> Function(Duration)? delay,
    bool Function()? isForeground,
  })  : _quoteProvider = quoteProvider,
        _wallet = wallet,
        _store = receiptStore,
        _rpc = rpc,
        _solanaRpc = solanaRpc,
        _lifiStatus = lifiStatus ?? LifiStatusService(),
        _relay = relay,
        _baseBalance = baseBalance,
        _internalBaseAddress = internalBaseAddress,
        _lifiConnectedEnabled = lifiConnectedEnabled,
        _relayDepositEnabled = relayDepositEnabled,
        _reownEvmEnabled = reownEvmEnabled,
        _solanaMwaEnabled = solanaMwaEnabled,
        _reownSolanaFallbackEnabled = reownSolanaFallbackEnabled,
        _baseAccountMwpEnabled = baseAccountMwpEnabled,
        _transactionValidator = transactionValidator,
        _solanaEnvelope = solanaEnvelope,
        _clock = clock ?? DateTime.now,
        _intentIdFactory = intentIdFactory ?? _secureIntentId,
        _delay = delay ?? Future<void>.delayed,
        _isForeground = isForeground ?? _alwaysForeground;

  final BridgeExecutableQuoteProvider _quoteProvider;
  final ExternalWalletSessionService _wallet;
  final BridgeReceiptStore _store;
  final EvmBridgeRpc _rpc;
  final SolanaRpcBroadcaster _solanaRpc;
  final LifiSettlementStatusProvider _lifiStatus;
  final RelayDepositProvider? _relay;
  final BaseBalanceRefreshService _baseBalance;
  final String Function() _internalBaseAddress;
  final bool _lifiConnectedEnabled;
  final bool _relayDepositEnabled;
  final bool _reownEvmEnabled;
  final bool _solanaMwaEnabled;
  final bool _reownSolanaFallbackEnabled;
  final bool _baseAccountMwpEnabled;
  final LifiTransactionValidator _transactionValidator;
  final SolanaTransactionEnvelope _solanaEnvelope;
  final DateTime Function() _clock;
  final String Function() _intentIdFactory;
  final Future<void> Function(Duration) _delay;
  final bool Function() _isForeground;

  _PreparedEvmIntent? _prepared;
  _PreparedSolanaIntent? _preparedSolana;
  String? _confirmationInFlight;

  @override
  BridgeFundingReceipt? get activeReceipt => _store.activeReceipt;

  @override
  List<BridgeFundingReceipt> get receipts => _store.receipts;

  @override
  ExternalWalletIdentity? get connectedExternalWallet => _wallet.identity;

  @override
  BridgeReviewKind? pendingReviewKind(String intentId) {
    if (_preparedSolana?.intentId == intentId) {
      return BridgeReviewKind.bridge;
    }
    final prepared = _prepared;
    return prepared?.intentId == intentId ? prepared?.reviewKind : null;
  }

  @override
  Future<List<ExternalWalletOption>> discoverWallets(BridgeChain chain) =>
      _wallet.discover(chain);

  @override
  Future<void> disconnectExternalWallet() async {
    if (_store.activeReceipt != null ||
        _prepared != null ||
        _preparedSolana != null ||
        _confirmationInFlight != null) {
      throw const BridgeValidationException(
        'active_bridge_receipt_exists',
        'Finish or cancel the active funding transfer before changing wallet.',
      );
    }
    await _wallet.disconnect();
  }

  @override
  Future<void> prepareConnected(
    BridgeFundingRequest request, {
    ExternalWalletTransport? transport,
  }) async {
    _validatePreparationRequest(request);
    if (_store.activeReceipt != null) {
      throw const BridgeValidationException('active_bridge_receipt_exists');
    }
    final direct = _isDirectBaseUsdc(request);
    if (!direct && !_lifiConnectedEnabled) {
      throw const BridgeValidationException('lifi_connected_disabled');
    }
    final intentId = _intentIdFactory();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(intentId)) {
      throw const BridgeValidationException('invalid_bridge_intent_id');
    }
    final createdAt = _now();
    var receipt = _newReceipt(request, intentId, createdAt);
    await _store.upsert(receipt);

    try {
      receipt = _copyReceipt(
        receipt,
        state: BridgeFundingState.checkingCapabilities,
      );
      await _store.upsert(receipt);
      receipt = _copyReceipt(
        receipt,
        state: BridgeFundingState.connectingWallet,
      );
      await _store.upsert(receipt);

      final identity = await _connectedIdentity(
        request.sourceChain,
        transport: transport,
      );
      receipt = _copyReceipt(
        receipt,
        state: BridgeFundingState.quoting,
        sourceAddress: identity.publicAddress,
        walletTransport: identity.transport,
      );
      await _store.upsert(receipt);

      if (request.sourceChain.type == BridgeChainType.svm) {
        final prepared = await _prepareSolanaReview(
          intentId: intentId,
          request: request,
          identity: identity,
        );
        _preparedSolana = prepared;
        await _persistSolanaReview(receipt, prepared);
        return;
      }

      if (direct) {
        final quote = await _directQuote(
          request,
          intentId: intentId,
          connectedAddress: identity.publicAddress,
        );
        _prepared = _PreparedEvmIntent(
          intentId: intentId,
          request: request,
          identity: identity,
          quote: quote,
          payload: quote.payload as EvmBridgeExecutionPayload,
          reviewKind: BridgeReviewKind.bridge,
        );
        await _persistReview(receipt, _prepared!);
        return;
      }

      final prepared = await _prepareLifiReview(
        intentId: intentId,
        request: request,
        identity: identity,
      );
      _prepared = prepared;
      await _persistReview(receipt, prepared);
    } catch (_) {
      await _failPreparationIfPossible(intentId);
      rethrow;
    }
  }

  @override
  Future<RelayDepositInstruction> prepareRelayDeposit(
    BridgeFundingRequest request, {
    bool oldAddressWarningAcknowledged = false,
  }) async {
    final relay = _relay;
    if (!_relayDepositEnabled || relay == null) {
      throw const BridgeValidationException('relay_deposit_disabled');
    }
    if (request.method != BridgeFundingMethod.relayDeposit) {
      throw const BridgeValidationException('strategy_intent_mismatch');
    }
    if (_store.activeReceipt != null) {
      throw const BridgeValidationException('active_bridge_receipt_exists');
    }
    if (!_sameEvmAddress(
      request.baseDestinationAddress,
      _currentBaseAddress(),
    )) {
      throw const BridgeValidationException('base_destination_changed');
    }
    final intentId = _intentIdFactory();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(intentId)) {
      throw const BridgeValidationException('invalid_bridge_intent_id');
    }
    final priorInstructions = _store.receipts
        .where(
          (receipt) =>
              receipt.method == BridgeFundingMethod.relayDeposit &&
              receipt.depositAddressExposed &&
              (receipt.archivedAt != null ||
                  receipt.state == BridgeFundingState.expired),
        )
        .toList();
    if (priorInstructions.isNotEmpty && !oldAddressWarningAcknowledged) {
      throw const BridgeValidationException(
        'old_relay_address_warning_required',
      );
    }
    for (final prior in priorInstructions) {
      if (prior.archivedAt == null) {
        await _store.upsert(_copyReceipt(prior, archivedAt: _now()));
      }
    }
    var receipt = _newReceipt(request, intentId, _now());
    await _store.upsert(receipt);
    try {
      receipt = _copyReceipt(
        receipt,
        state: BridgeFundingState.checkingCapabilities,
      );
      await _store.upsert(receipt);
      receipt = _copyReceipt(
        receipt,
        state: BridgeFundingState.collectingRefundAddress,
      );
      await _store.upsert(receipt);
      receipt = _copyReceipt(receipt, state: BridgeFundingState.quoting);
      await _store.upsert(receipt);
      final instruction = await relay.createInstruction(request);
      if (instruction.request != request ||
          instruction.createdAt.isAfter(_now()) ||
          !instruction.expiresAt.isAfter(instruction.createdAt)) {
        throw const BridgeValidationException(
          'relay_instruction_request_mismatch',
        );
      }
      final persisted = _copyReceipt(
        receipt,
        provider: 'relay',
        state: BridgeFundingState.awaitingDeposit,
        depositAddress: instruction.depositAddress,
        providerRequestId: instruction.requestId,
        minimumOutputUnits: instruction.minimumOutputUnits,
        providerStatus: 'waiting',
        providerSubstatus: null,
        expiresAt: instruction.expiresAt,
        depositAddressExposed: false,
      );
      await _store.upsert(persisted);
      await _store.upsert(
        _copyReceipt(persisted, depositAddressExposed: true),
      );
      return instruction;
    } on BridgePersistenceException {
      rethrow;
    } catch (_) {
      await _failPreparationIfPossible(intentId);
      rethrow;
    }
  }

  @override
  Future<void> confirmEvmAllowance(String intentId) =>
      _runConfirmation(intentId, () async {
        final prepared = _requirePrepared(
          intentId,
          BridgeReviewKind.allowance,
        );
        final receipt = _requireReviewReceipt(intentId);
        _validatePreparedIdentity(prepared);
        await _persistAwaitingWallet(receipt, prepared);

        late String hash;
        try {
          hash = await _wallet.sendEvmTransaction(prepared.payload);
        } on ExternalWalletException catch (error) {
          await _handleWalletFailure(receipt, prepared, error);
          rethrow;
        }
        if (!_validTransactionHash(hash)) {
          await _persistUnknownWalletOutcome(receipt, prepared);
          throw const BridgeValidationException(
              'invalid_wallet_transaction_hash');
        }
        hash = hash.toLowerCase();
        await _store.upsert(
          _copyReceipt(
            _requireReceipt(intentId),
            sourceTransactionHash: hash,
            providerStatus: 'approval_submitted',
          ),
        );
        await _refreshAllowance(intentId);
      });

  @override
  Future<void> confirmConnectedBridge(String intentId) =>
      _runConfirmation(intentId, () async {
        if (_preparedSolana?.intentId == intentId) {
          await _confirmSolanaBridge(intentId);
          return;
        }
        final prepared = _requirePrepared(intentId, BridgeReviewKind.bridge);
        final receipt = _requireReviewReceipt(intentId);
        _validatePreparedIdentity(prepared);
        if (!_sameEvmAddress(
          receipt.baseDestinationAddress,
          _currentBaseAddress(),
        )) {
          throw const BridgeValidationException('base_destination_changed');
        }
        await _persistAwaitingWallet(receipt, prepared);

        late String hash;
        try {
          hash = await _wallet.sendEvmTransaction(prepared.payload);
        } on ExternalWalletException catch (error) {
          await _handleWalletFailure(receipt, prepared, error);
          rethrow;
        }
        if (!_validTransactionHash(hash)) {
          await _persistUnknownWalletOutcome(receipt, prepared);
          throw const BridgeValidationException(
              'invalid_wallet_transaction_hash');
        }
        hash = hash.toLowerCase();
        final awaiting = _requireReceipt(intentId);
        await _store.upsert(
          _copyReceipt(
            awaiting,
            state: BridgeFundingState.submitted,
            sourceTransactionHash: hash,
            providerStatus: 'submitted',
            submissionOutcomeUnknown: false,
          ),
        );
        _prepared = null;
        await _refreshSubmitted(intentId);
      });

  @override
  Future<void> cancelBeforeSubmission(String intentId) async {
    final receipt = _requireReceipt(intentId);
    if (receipt.sourceTransactionHash != null ||
        receipt.submissionOutcomeUnknown ||
        receipt.state == BridgeFundingState.awaitingExternalWallet ||
        receipt.state == BridgeFundingState.submitted ||
        receipt.state == BridgeFundingState.sourcePending ||
        receipt.state == BridgeFundingState.destinationPending) {
      throw const BridgeValidationException(
          'bridge_cancellation_not_available');
    }
    await _store.upsert(
      _copyReceipt(
        receipt,
        state: BridgeFundingState.cancelled,
        providerStatus: 'cancelled_before_submission',
      ),
    );
    _prepared = null;
    _preparedSolana = null;
    await _wallet.disconnect();
  }

  @override
  Future<void> refreshStatus(String intentId) async {
    final receipt = _requireReceipt(intentId);
    if (receipt.provider == 'relay' &&
        receipt.method == BridgeFundingMethod.relayDeposit &&
        (receipt.state == BridgeFundingState.awaitingDeposit ||
            receipt.state == BridgeFundingState.depositDetected ||
            receipt.state == BridgeFundingState.destinationPending ||
            receipt.state == BridgeFundingState.expired)) {
      await _refreshRelayStatus(intentId);
      return;
    }
    if (receipt.state == BridgeFundingState.awaitingExternalWallet &&
        receipt.sourceTransactionHash == null) {
      if (!receipt.submissionOutcomeUnknown) {
        await _store.upsert(
          _copyReceipt(
            receipt,
            providerStatus: 'wallet_outcome_unknown',
            submissionOutcomeUnknown: true,
          ),
        );
      }
      return;
    }
    if (receipt.provider == 'lifi' &&
        receipt.sourceTransactionHash != null &&
        (receipt.state == BridgeFundingState.destinationPending ||
            _hasLifiObservation(receipt))) {
      await _refreshLifiStatus(intentId);
      return;
    }
    if (receipt.sourceChainId == BridgeConstants.solanaChainId &&
        receipt.sourceTransactionHash != null &&
        (receipt.state == BridgeFundingState.awaitingExternalWallet ||
            receipt.state == BridgeFundingState.submitted ||
            receipt.state == BridgeFundingState.sourcePending)) {
      await _refreshSolanaSubmitted(intentId);
      return;
    }
    if (receipt.providerStatus == 'approval_submitted' ||
        receipt.providerStatus == 'approval_pending') {
      await _refreshAllowance(intentId);
      return;
    }
    if (receipt.state != BridgeFundingState.submitted &&
        receipt.state != BridgeFundingState.sourcePending) {
      throw const BridgeValidationException('bridge_refresh_not_available');
    }
    await _refreshSubmitted(intentId);
  }

  @override
  Future<void> pollSettlement(
    String intentId, {
    int maxObservations = 7,
  }) async {
    if (maxObservations < 1 || maxObservations > 7) {
      throw const BridgeValidationException('invalid_polling_bound');
    }
    const schedule = <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ];
    for (var index = 0; index < maxObservations; index += 1) {
      if (!_isForeground()) return;
      Duration? retryAfter;
      try {
        await refreshStatus(intentId);
      } on LifiStatusException catch (error) {
        if (error.code != 'rate_limited') rethrow;
        retryAfter = error.retryAfter;
      }
      final receipt = _requireReceipt(intentId);
      if (_isTerminalState(receipt.state)) return;
      if (index + 1 >= maxObservations) return;
      await _delay(retryAfter ?? schedule[index]);
    }
  }

  @override
  Future<void> refreshBaseBalance(String intentId) async {
    final receipt = _requireReceipt(intentId);
    if ((receipt.state != BridgeFundingState.completed &&
            receipt.state != BridgeFundingState.partial) ||
        !receipt.balanceRefreshPending) {
      throw const BridgeValidationException(
        'base_balance_refresh_not_available',
      );
    }
    if (!await _baseBalance.refresh()) return;
    await _store.upsert(
      _copyReceipt(
        receipt,
        providerSubstatus:
            receipt.provider == 'direct_base' ? null : _unchanged,
        balanceRefreshPending: false,
      ),
    );
  }

  @override
  Future<void> archiveRelayInstructions(String intentId) async {
    final receipt = _requireReceipt(intentId);
    if (receipt.provider != 'relay' ||
        receipt.method != BridgeFundingMethod.relayDeposit ||
        !receipt.depositAddressExposed ||
        receipt.archivedAt != null) {
      throw const BridgeValidationException('relay_archive_not_available');
    }
    await _store.upsert(
      _copyReceipt(receipt, archivedAt: _now()),
    );
  }

  @override
  Future<void> recoverEvmTransactionHash(
    String intentId,
    String transactionHash,
  ) async {
    final receipt = _requireReceipt(intentId);
    if (receipt.sourceChainId == BridgeConstants.solanaChainId ||
        receipt.state != BridgeFundingState.awaitingExternalWallet ||
        receipt.sourceTransactionHash != null ||
        !receipt.submissionOutcomeUnknown) {
      throw const BridgeValidationException('evm_recovery_not_available');
    }
    if (!_validTransactionHash(transactionHash)) {
      throw const BridgeValidationException('invalid_transaction_hash');
    }
    final transaction = await _rpc.transactionByHash(
      chainId: receipt.sourceChainId,
      transactionHash: transactionHash,
    );
    if (transaction == null) {
      throw const BridgeValidationException('recovery_transaction_not_found');
    }
    final expectedSource = receipt.sourceAddress;
    final reviewedHash = receipt.reviewedPayloadHash;
    if (expectedSource == null ||
        reviewedHash == null ||
        transaction.chainId != receipt.sourceChainId ||
        !_sameEvmAddress(transaction.from, expectedSource)) {
      throw const BridgeValidationException('recovery_transaction_mismatch');
    }
    final recoveredPayload = EvmBridgeExecutionPayload(
      chainId: transaction.chainId,
      from: transaction.from,
      to: transaction.to,
      valueHex: transaction.valueHex,
      dataHex: transaction.dataHex,
      gasLimitHex: '0x5208',
      approvalAddress: null,
    );
    if (_payloadFingerprint(recoveredPayload) != reviewedHash) {
      throw const BridgeValidationException('recovery_transaction_mismatch');
    }
    if (receipt.provider == 'direct_base') {
      final expectedData = _rpc.encodeExactTransfer(
        receipt.baseDestinationAddress,
        _positiveAmount(receipt.sourceAmountUnits),
      );
      if (transaction.chainId != BridgeConstants.baseChainId ||
          !_sameEvmAddress(transaction.to, BridgeConstants.baseUsdc) ||
          _normalizedQuantity(transaction.valueHex) != '0x0' ||
          transaction.dataHex.toLowerCase() != expectedData.toLowerCase()) {
        throw const BridgeValidationException('recovery_transaction_mismatch');
      }
    } else if (receipt.provider != 'lifi') {
      throw const BridgeValidationException('evm_recovery_not_available');
    }

    await _store.upsert(
      _copyReceipt(
        receipt,
        state: BridgeFundingState.sourcePending,
        sourceTransactionHash: transaction.transactionHash,
        providerStatus: 'recovery_transaction_verified',
        providerSubstatus: null,
        submissionOutcomeUnknown: false,
      ),
    );
    if (receipt.provider == 'direct_base') {
      await _refreshSubmitted(intentId);
    } else {
      await _refreshLifiStatus(intentId);
    }
  }

  @override
  Future<void> recoverSolanaSignature(
    String intentId,
    String signature,
  ) async {
    final receipt = _requireSolanaRecoveryReceipt(intentId);
    final fetched = await _solanaRpc.transaction(signature);
    if (fetched == null) {
      throw const BridgeValidationException('recovery_transaction_not_found');
    }
    final verified = await _solanaEnvelope.verifyRecovered(
      transactionBytes: fetched.transactionBytes,
      expectedSigner: receipt.sourceAddress!,
      expectedMessageSha256: receipt.reviewedPayloadHash!,
    );
    if (verified.signature != signature || fetched.signature != signature) {
      throw const BridgeValidationException('recovery_transaction_mismatch');
    }
    await _attachRecoveredSolana(receipt, signature);
  }

  @override
  Future<SolanaRecoveryScanResult> scanSolanaRecovery(
    String intentId,
  ) async {
    final receipt = _requireSolanaRecoveryReceipt(intentId);
    final history = await _solanaRpc.signaturesForAddress(
      receipt.sourceAddress!,
      since: receipt.createdAt,
      limit: 200,
    );
    final matches = <String>{};
    var scanInconclusive = false;
    for (final candidate in history.entries) {
      final fetched = await _solanaRpc.transaction(candidate.signature);
      if (fetched == null) {
        scanInconclusive = true;
        continue;
      }
      try {
        final verified = await _solanaEnvelope.verifyRecovered(
          transactionBytes: fetched.transactionBytes,
          expectedSigner: receipt.sourceAddress!,
          expectedMessageSha256: receipt.reviewedPayloadHash!,
        );
        if (verified.signature != candidate.signature ||
            fetched.signature != candidate.signature) {
          scanInconclusive = true;
          continue;
        }
        matches.add(candidate.signature);
      } on BridgeValidationException catch (error) {
        if (error.code == 'solana_message_changed' ||
            error.code == 'solana_signer_changed' ||
            error.code == 'solana_signature_invalid' ||
            error.code == 'solana_signature_missing') {
          continue;
        }
        scanInconclusive = true;
      }
    }
    if (matches.length > 1) return SolanaRecoveryScanResult.ambiguous;
    if (matches.length == 1) {
      await _attachRecoveredSolana(receipt, matches.single);
      return SolanaRecoveryScanResult.matched;
    }
    if (scanInconclusive || history.truncated || !history.complete) {
      return SolanaRecoveryScanResult.inconclusive;
    }
    if (await _solanaRpc.isBlockhashValid(receipt.sourceBlockhash!)) {
      return SolanaRecoveryScanResult.inconclusive;
    }
    final evidence = SolanaNoSubmissionEvidence(
      sourceChainId: receipt.sourceChainId,
      blockhashInvalid: true,
      completeHistoryScan: true,
      exactMatchFound: false,
    );
    await _store.upsert(
      _copyReceipt(
        receipt,
        state: BridgeFundingState.expired,
        providerStatus: 'solana_submission_not_found',
        providerSubstatus: 'blockhash_expired_after_complete_scan',
        expiresAt: _now(),
        submissionOutcomeUnknown: false,
      ),
      evidence: evidence,
    );
    return SolanaRecoveryScanResult.expired;
  }

  BridgeFundingReceipt _requireSolanaRecoveryReceipt(String intentId) {
    final receipt = _requireReceipt(intentId);
    if (receipt.sourceChainId != BridgeConstants.solanaChainId ||
        receipt.state != BridgeFundingState.awaitingExternalWallet ||
        receipt.sourceTransactionHash != null ||
        !receipt.submissionOutcomeUnknown ||
        receipt.sourceAddress == null ||
        receipt.reviewedPayloadHash == null ||
        receipt.sourceBlockhash == null) {
      throw const BridgeValidationException('solana_recovery_not_available');
    }
    return receipt;
  }

  Future<void> _attachRecoveredSolana(
    BridgeFundingReceipt receipt,
    String signature,
  ) async {
    await _store.upsert(
      _copyReceipt(
        receipt,
        state: BridgeFundingState.sourcePending,
        sourceTransactionHash: signature,
        providerStatus: 'solana_recovery_transaction_verified',
        providerSubstatus: null,
        submissionOutcomeUnknown: false,
      ),
    );
    await _refreshLifiStatus(receipt.intentId);
  }

  Future<_PreparedEvmIntent> _prepareLifiReview({
    required String intentId,
    required BridgeFundingRequest request,
    required ExternalWalletIdentity identity,
  }) async {
    final quote = await _quoteProvider.executableQuote(
      request,
      connectedSourceAddress: identity.publicAddress,
    );
    _transactionValidator.validate(
      quote,
      request: request,
      connectedAddress: identity.publicAddress,
      baseAddress: _currentBaseAddress(),
      now: _now(),
    );
    final payload = quote.payload;
    if (payload is! EvmBridgeExecutionPayload) {
      throw const BridgeValidationException('evm_payload_required');
    }
    if (_payloadFingerprint(payload) != quote.fingerprint) {
      throw const BridgeValidationException('quote_fingerprint_mismatch');
    }
    _validateGasLimit(payload.gasLimitHex);

    final approvalAddress = quote.estimate.approvalAddress;
    if (approvalAddress != null &&
        !_isNativeToken(request.sourceToken.address)) {
      final amount = _positiveAmount(request.amountUnits);
      final allowance = await _rpc.allowance(
        chainId: request.sourceChain.id,
        tokenAddress: request.sourceToken.address,
        owner: identity.publicAddress,
        spender: approvalAddress,
      );
      if (allowance < amount) {
        final approval = EvmBridgeExecutionPayload(
          chainId: request.sourceChain.id,
          from: identity.publicAddress,
          to: request.sourceToken.address,
          valueHex: '0x0',
          dataHex: _rpc.encodeExactApproval(approvalAddress, amount),
          gasLimitHex: '0x0',
          approvalAddress: null,
        );
        final gas = await _rpc.estimateGas(approval);
        final exactApproval = EvmBridgeExecutionPayload(
          chainId: approval.chainId,
          from: approval.from,
          to: approval.to,
          valueHex: approval.valueHex,
          dataHex: approval.dataHex,
          gasLimitHex: _quantity(gas),
          approvalAddress: null,
        );
        return _PreparedEvmIntent(
          intentId: intentId,
          request: request,
          identity: identity,
          quote: quote,
          payload: exactApproval,
          reviewKind: BridgeReviewKind.allowance,
        );
      }
    }
    return _PreparedEvmIntent(
      intentId: intentId,
      request: request,
      identity: identity,
      quote: quote,
      payload: payload,
      reviewKind: BridgeReviewKind.bridge,
    );
  }

  Future<_PreparedSolanaIntent> _prepareSolanaReview({
    required String intentId,
    required BridgeFundingRequest request,
    required ExternalWalletIdentity identity,
  }) async {
    final quote = await _quoteProvider.executableQuote(
      request,
      connectedSourceAddress: identity.publicAddress,
    );
    _transactionValidator.validate(
      quote,
      request: request,
      connectedAddress: identity.publicAddress,
      baseAddress: _currentBaseAddress(),
      now: _now(),
    );
    final payload = quote.payload;
    if (payload is! SolanaBridgeExecutionPayload) {
      throw const BridgeValidationException('solana_payload_required');
    }
    final inspection = _solanaEnvelope.inspect(payload);
    if (sha256.convert(inspection.transactionBytes).toString() !=
        quote.fingerprint) {
      throw const BridgeValidationException('quote_fingerprint_mismatch');
    }
    final mode = identity.approvedMethods.contains('solana_signTransaction')
        ? SolanaWalletSubmissionMode.signOnly
        : identity.approvedMethods.contains('solana_signAndSendTransaction')
            ? SolanaWalletSubmissionMode.signAndSend
            : throw const BridgeValidationException(
                'connected_wallet_mismatch',
              );
    return _PreparedSolanaIntent(
      intentId: intentId,
      request: request,
      identity: identity,
      quote: quote,
      payload: payload,
      inspection: inspection,
      submissionMode: mode,
    );
  }

  Future<BridgeExecutableQuote> _directQuote(
    BridgeFundingRequest request, {
    required String intentId,
    required String connectedAddress,
  }) async {
    final amount = _positiveAmount(request.amountUnits);
    final destination = _currentBaseAddress();
    final unestimated = EvmBridgeExecutionPayload(
      chainId: BridgeConstants.baseChainId,
      from: connectedAddress,
      to: BridgeConstants.baseUsdc,
      valueHex: '0x0',
      dataHex: _rpc.encodeExactTransfer(destination, amount),
      gasLimitHex: '0x0',
      approvalAddress: null,
    );
    final gas = await _rpc.estimateGas(unestimated);
    final payload = EvmBridgeExecutionPayload(
      chainId: unestimated.chainId,
      from: unestimated.from,
      to: unestimated.to,
      valueHex: unestimated.valueHex,
      dataHex: unestimated.dataHex,
      gasLimitHex: _quantity(gas),
      approvalAddress: null,
    );
    final normalized = _withConnectedAddress(request, connectedAddress);
    final now = _now();
    return BridgeExecutableQuote(
      estimate: BridgeEstimate(
        provider: 'direct_base',
        quoteId: 'direct-$intentId',
        request: normalized,
        minimumOutputUnits: amount.toString(),
        minimumOutputDisplay: request.amount,
        routeTool: 'direct_transfer',
        quotedAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
      ),
      connectedSourceAddress: connectedAddress,
      destinationChainId: BridgeConstants.baseChainId,
      destinationToken: const BridgeToken(
        chainId: BridgeConstants.baseChainId,
        address: BridgeConstants.baseUsdc,
        symbol: 'USDC',
        decimals: 6,
        solverDepositable: false,
      ),
      payload: payload,
      fingerprint: _payloadFingerprint(payload),
    );
  }

  Future<void> _persistReview(
    BridgeFundingReceipt receipt,
    _PreparedEvmIntent prepared,
  ) =>
      _store.upsert(
        _copyReceipt(
          receipt,
          state: BridgeFundingState.awaitingPlawieReview,
          provider: prepared.quote.estimate.provider,
          providerQuoteId: prepared.quote.estimate.quoteId,
          routeTool: prepared.quote.estimate.routeTool,
          minimumOutputUnits: prepared.quote.estimate.minimumOutputUnits,
          sourceAddress: prepared.identity.publicAddress,
          walletTransport: prepared.identity.transport,
          reviewedPayloadHash: prepared.fingerprint,
          expiresAt: prepared.quote.estimate.expiresAt,
          providerStatus: prepared.reviewKind == BridgeReviewKind.allowance
              ? 'allowance_review'
              : 'bridge_review',
        ),
      );

  Future<void> _persistSolanaReview(
    BridgeFundingReceipt receipt,
    _PreparedSolanaIntent prepared,
  ) =>
      _store.upsert(
        _copyReceipt(
          receipt,
          state: BridgeFundingState.awaitingPlawieReview,
          provider: prepared.quote.estimate.provider,
          providerQuoteId: prepared.quote.estimate.quoteId,
          routeTool: prepared.quote.estimate.routeTool,
          minimumOutputUnits: prepared.quote.estimate.minimumOutputUnits,
          sourceAddress: prepared.identity.publicAddress,
          walletTransport: prepared.identity.transport,
          reviewedPayloadHash: prepared.fingerprint,
          sourceBlockhash: prepared.inspection.recentBlockhash,
          expiresAt: prepared.quote.estimate.expiresAt,
          providerStatus: 'bridge_review',
        ),
      );

  Future<void> _persistAwaitingWallet(
    BridgeFundingReceipt receipt,
    _PreparedEvmIntent prepared,
  ) async {
    if (receipt.reviewedPayloadHash != prepared.fingerprint) {
      throw const BridgeValidationException('reviewed_payload_changed');
    }
    await _store.upsert(
      _copyReceipt(
        receipt,
        state: BridgeFundingState.awaitingExternalWallet,
        reviewedPayloadHash: prepared.fingerprint,
        providerStatus: prepared.reviewKind == BridgeReviewKind.allowance
            ? 'awaiting_allowance_wallet'
            : 'awaiting_bridge_wallet',
        submissionOutcomeUnknown: false,
      ),
    );
  }

  Future<void> _handleWalletFailure(
    BridgeFundingReceipt originalReview,
    _PreparedEvmIntent prepared,
    ExternalWalletException error,
  ) async {
    if (_isKnownWalletRejection(error.code)) {
      await _store.upsert(
        _copyReceipt(
          _requireReceipt(prepared.intentId),
          state: BridgeFundingState.awaitingPlawieReview,
          providerStatus: 'wallet_rejected',
          submissionOutcomeUnknown: false,
        ),
      );
      return;
    }
    await _persistUnknownWalletOutcome(originalReview, prepared);
  }

  Future<void> _persistUnknownWalletOutcome(
    BridgeFundingReceipt originalReview,
    _PreparedEvmIntent prepared,
  ) =>
      _store.upsert(
        _copyReceipt(
          _requireReceipt(prepared.intentId),
          providerStatus: 'wallet_outcome_unknown',
          reviewedPayloadHash: prepared.fingerprint,
          submissionOutcomeUnknown: true,
        ),
      );

  Future<void> _confirmSolanaBridge(String intentId) async {
    final prepared = _requirePreparedSolana(intentId);
    final receipt = _requireReviewReceipt(intentId);
    _validatePreparedSolanaIdentity(prepared);
    if (!_sameEvmAddress(
      receipt.baseDestinationAddress,
      _currentBaseAddress(),
    )) {
      throw const BridgeValidationException('base_destination_changed');
    }
    await _persistSolanaAwaitingWallet(receipt, prepared);

    late SolanaWalletSubmissionResult result;
    try {
      result = await _wallet.submitSolanaTransaction(prepared.payload);
    } on ExternalWalletException catch (error) {
      if (prepared.submissionMode == SolanaWalletSubmissionMode.signOnly ||
          _isKnownWalletRejection(error.code)) {
        await _returnSolanaToReview(
          prepared,
          providerStatus: _isKnownWalletRejection(error.code)
              ? 'wallet_rejected'
              : 'solana_signing_failed',
        );
      } else {
        await _persistSolanaUnknown(
          prepared,
          providerStatus: 'wallet_outcome_unknown',
          providerSubstatus: error.code,
        );
      }
      rethrow;
    }

    if (result.mode != prepared.submissionMode) {
      if (result is SubmittedSolanaTransaction) {
        await _persistSolanaUnknown(
          prepared,
          providerStatus: 'wallet_mode_changed_outcome_unknown',
        );
      } else {
        await _returnSolanaToReview(
          prepared,
          providerStatus: 'wallet_mode_changed',
        );
      }
      throw const BridgeValidationException('solana_wallet_mode_changed');
    }

    switch (result) {
      case SignedSolanaTransaction():
        late SolanaVerifiedTransaction verified;
        try {
          verified = await _solanaEnvelope.verifySigned(
            reviewed: prepared.payload,
            signedTransaction: result.signedTransaction,
          );
        } on BridgeValidationException {
          await _returnSolanaToReview(
            prepared,
            providerStatus: 'solana_signature_rejected',
          );
          rethrow;
        }
        await _store.upsert(
          _copyReceipt(
            _requireReceipt(intentId),
            sourceTransactionHash: verified.signature,
            providerStatus: 'solana_signature_verified',
            submissionOutcomeUnknown: false,
          ),
        );
        _preparedSolana = null;
        late String broadcastSignature;
        try {
          broadcastSignature =
              await _solanaRpc.sendTransaction(verified.transactionBytes);
        } on SolanaRpcException catch (error) {
          await _store.upsert(
            _copyReceipt(
              _requireReceipt(intentId),
              providerStatus: 'solana_broadcast_outcome_unknown',
              providerSubstatus: error.code,
              submissionOutcomeUnknown: true,
            ),
          );
          rethrow;
        } catch (_) {
          await _store.upsert(
            _copyReceipt(
              _requireReceipt(intentId),
              providerStatus: 'solana_broadcast_outcome_unknown',
              providerSubstatus: 'unexpected_broadcast_failure',
              submissionOutcomeUnknown: true,
            ),
          );
          rethrow;
        }
        if (broadcastSignature != verified.signature) {
          await _store.upsert(
            _copyReceipt(
              _requireReceipt(intentId),
              providerStatus: 'solana_broadcast_outcome_unknown',
              providerSubstatus: 'signature_mismatch',
              submissionOutcomeUnknown: true,
            ),
          );
          throw const BridgeValidationException(
            'solana_broadcast_signature_mismatch',
          );
        }
        await _persistSolanaSubmitted(intentId, verified.signature);
      case SubmittedSolanaTransaction():
        late String signature;
        try {
          signature = await _solanaEnvelope.verifySubmittedSignature(
            reviewed: prepared.payload,
            signature: result.signature,
          );
        } on BridgeValidationException {
          await _persistSolanaUnknown(
            prepared,
            providerStatus: 'solana_submitted_signature_invalid',
          );
          rethrow;
        }
        _preparedSolana = null;
        await _persistSolanaSubmitted(intentId, signature);
    }
    await _refreshSolanaSubmitted(intentId);
  }

  Future<void> _persistSolanaAwaitingWallet(
    BridgeFundingReceipt receipt,
    _PreparedSolanaIntent prepared,
  ) async {
    if (receipt.reviewedPayloadHash != prepared.fingerprint ||
        receipt.sourceBlockhash != prepared.inspection.recentBlockhash) {
      throw const BridgeValidationException('reviewed_payload_changed');
    }
    await _store.upsert(
      _copyReceipt(
        receipt,
        state: BridgeFundingState.awaitingExternalWallet,
        reviewedPayloadHash: prepared.fingerprint,
        sourceBlockhash: prepared.inspection.recentBlockhash,
        providerStatus: 'awaiting_bridge_wallet',
        submissionOutcomeUnknown: false,
      ),
    );
  }

  Future<void> _returnSolanaToReview(
    _PreparedSolanaIntent prepared, {
    required String providerStatus,
  }) =>
      _store.upsert(
        _copyReceipt(
          _requireReceipt(prepared.intentId),
          state: BridgeFundingState.awaitingPlawieReview,
          sourceTransactionHash: null,
          providerStatus: providerStatus,
          providerSubstatus: null,
          submissionOutcomeUnknown: false,
        ),
      );

  Future<void> _persistSolanaUnknown(
    _PreparedSolanaIntent prepared, {
    required String providerStatus,
    String? providerSubstatus,
  }) async {
    _preparedSolana = null;
    await _store.upsert(
      _copyReceipt(
        _requireReceipt(prepared.intentId),
        providerStatus: providerStatus,
        providerSubstatus: providerSubstatus,
        reviewedPayloadHash: prepared.fingerprint,
        sourceBlockhash: prepared.inspection.recentBlockhash,
        submissionOutcomeUnknown: true,
      ),
    );
  }

  Future<void> _persistSolanaSubmitted(
    String intentId,
    String signature,
  ) =>
      _store.upsert(
        _copyReceipt(
          _requireReceipt(intentId),
          state: BridgeFundingState.submitted,
          sourceTransactionHash: signature,
          providerStatus: 'submitted',
          providerSubstatus: null,
          submissionOutcomeUnknown: false,
        ),
      );

  Future<void> _refreshSolanaSubmitted(String intentId) async {
    final receipt = _requireReceipt(intentId);
    final signature = receipt.sourceTransactionHash;
    if (signature == null) {
      throw const BridgeValidationException('source_transaction_hash_missing');
    }
    late SolanaSignatureObservation observation;
    try {
      observation = await _solanaRpc.signatureStatus(signature);
    } on SolanaRpcException catch (error) {
      await _store.upsert(
        _copyReceipt(
          receipt,
          state: receipt.state == BridgeFundingState.submitted
              ? BridgeFundingState.sourcePending
              : receipt.state,
          providerStatus: 'source_receipt_pending',
          providerSubstatus: error.code,
        ),
      );
      return;
    }
    switch (observation.status) {
      case SolanaSignatureStatus.notFound:
        if (receipt.state == BridgeFundingState.awaitingExternalWallet &&
            receipt.submissionOutcomeUnknown) {
          await _store.upsert(
            _copyReceipt(
              receipt,
              providerStatus: 'solana_signature_not_found',
            ),
          );
          return;
        }
        await _store.upsert(
          _copyReceipt(
            receipt,
            state: receipt.state == BridgeFundingState.submitted
                ? BridgeFundingState.sourcePending
                : receipt.state,
            providerStatus: 'source_receipt_pending',
          ),
        );
      case SolanaSignatureStatus.processed:
      case SolanaSignatureStatus.confirmed:
      case SolanaSignatureStatus.finalized:
        await _store.upsert(
          _copyReceipt(
            receipt,
            state: BridgeFundingState.sourcePending,
            providerStatus: switch (observation.status) {
              SolanaSignatureStatus.processed => 'solana_processed',
              SolanaSignatureStatus.confirmed => 'solana_confirmed',
              SolanaSignatureStatus.finalized => 'solana_finalized',
              _ => throw StateError('unreachable'),
            },
            providerSubstatus: null,
            submissionOutcomeUnknown: false,
          ),
        );
        if (observation.status == SolanaSignatureStatus.finalized) {
          await _refreshLifiStatus(intentId);
        }
      case SolanaSignatureStatus.failed:
        if (receipt.state == BridgeFundingState.awaitingExternalWallet) {
          await _store.upsert(
            _copyReceipt(
              receipt,
              state: BridgeFundingState.sourcePending,
              providerStatus: 'source_transaction_observed',
              providerSubstatus: null,
              submissionOutcomeUnknown: false,
            ),
          );
        }
        await _store.upsert(
          _copyReceipt(
            _requireReceipt(intentId),
            state: BridgeFundingState.failed,
            providerStatus: 'source_transaction_failed',
            providerSubstatus: null,
            submissionOutcomeUnknown: false,
          ),
        );
    }
  }

  Future<void> _refreshAllowance(String intentId) async {
    final receipt = _requireReceipt(intentId);
    final hash = receipt.sourceTransactionHash;
    if (hash == null) {
      throw const BridgeValidationException('approval_hash_missing');
    }
    final observation = await _rpc.waitForReceipt(
      chainId: receipt.sourceChainId,
      transactionHash: hash,
    );
    switch (observation.status) {
      case EvmReceiptStatus.pending:
        await _store.upsert(
          _copyReceipt(receipt, providerStatus: 'approval_pending'),
        );
      case EvmReceiptStatus.reverted:
        await _store.upsert(
          _copyReceipt(
            receipt,
            state: BridgeFundingState.awaitingPlawieReview,
            providerStatus: 'approval_reverted',
            sourceTransactionHash: null,
          ),
        );
        throw const BridgeValidationException('approval_reverted');
      case EvmReceiptStatus.succeeded:
        final prepared = _prepared;
        if (prepared == null || prepared.intentId != intentId) {
          await _store.upsert(
            _copyReceipt(
              receipt,
              state: BridgeFundingState.awaitingPlawieReview,
              providerStatus: 'approval_confirmed_requote_required',
              sourceTransactionHash: null,
            ),
          );
          return;
        }
        var review = _copyReceipt(
          receipt,
          state: BridgeFundingState.awaitingPlawieReview,
          providerStatus: 'approval_confirmed',
          sourceTransactionHash: null,
        );
        await _store.upsert(review);
        review = _copyReceipt(review, state: BridgeFundingState.quoting);
        await _store.upsert(review);
        final refreshed = await _prepareLifiReview(
          intentId: intentId,
          request: prepared.request,
          identity: prepared.identity,
        );
        _prepared = refreshed;
        await _persistReview(review, refreshed);
    }
  }

  Future<void> _refreshSubmitted(String intentId) async {
    var receipt = _requireReceipt(intentId);
    final hash = receipt.sourceTransactionHash;
    if (hash == null) {
      throw const BridgeValidationException('source_transaction_hash_missing');
    }
    late EvmReceiptObservation observation;
    try {
      observation = await _rpc.waitForReceipt(
        chainId: receipt.sourceChainId,
        transactionHash: hash,
      );
    } on EvmRpcException catch (error) {
      if (receipt.state == BridgeFundingState.submitted) {
        receipt = _copyReceipt(
          receipt,
          state: BridgeFundingState.sourcePending,
          providerStatus: 'source_receipt_pending',
          providerSubstatus: error.code,
        );
      } else {
        receipt = _copyReceipt(
          receipt,
          providerStatus: 'source_receipt_pending',
          providerSubstatus: error.code,
        );
      }
      await _store.upsert(receipt);
      return;
    }
    switch (observation.status) {
      case EvmReceiptStatus.pending:
        await _store.upsert(
          _copyReceipt(
            receipt,
            state: receipt.state == BridgeFundingState.submitted
                ? BridgeFundingState.sourcePending
                : receipt.state,
            providerStatus: 'source_receipt_pending',
          ),
        );
      case EvmReceiptStatus.reverted:
        await _store.upsert(
          _copyReceipt(
            receipt,
            state: BridgeFundingState.failed,
            providerStatus: 'source_reverted',
          ),
        );
      case EvmReceiptStatus.succeeded:
        if (receipt.provider != 'direct_base') {
          await _store.upsert(
            _copyReceipt(
              receipt,
              state: receipt.state == BridgeFundingState.submitted
                  ? BridgeFundingState.sourcePending
                  : receipt.state,
              providerStatus: 'source_confirmed',
            ),
          );
          await _refreshLifiStatus(intentId);
          return;
        }
        final settled = _copyReceipt(
          receipt,
          state: BridgeFundingState.completed,
          providerStatus: 'direct_transfer_completed',
          providerSubstatus: null,
          actualOutputUnits: receipt.sourceAmountUnits,
          balanceRefreshPending: true,
        );
        await _store.upsert(settled);
        final reconciled = await _baseBalance.refresh();
        await _store.upsert(
          _copyReceipt(
            settled,
            providerSubstatus:
                reconciled ? null : 'base_balance_refresh_failed',
            balanceRefreshPending: !reconciled,
          ),
        );
    }
  }

  Future<void> _refreshLifiStatus(String intentId) async {
    final receipt = _requireReceipt(intentId);
    final hash = receipt.sourceTransactionHash;
    final tool = receipt.routeTool;
    if (receipt.provider != 'lifi' || hash == null || tool == null) {
      throw const BridgeValidationException('lifi_status_not_available');
    }
    final observation = await _lifiStatus.status(
      sourceTransactionHash: hash,
      sourceChainId: receipt.sourceChainId,
      routeTool: tool,
    );
    final state = receipt.state == BridgeFundingState.destinationPending &&
            observation.state == BridgeFundingState.sourcePending
        ? BridgeFundingState.destinationPending
        : observation.state;
    final completed = state == BridgeFundingState.completed;
    final observed = _copyReceipt(
      receipt,
      state: state,
      destinationTransactionHash:
          observation.destinationTransactionHash ?? _unchanged,
      actualOutputUnits: observation.actualOutputUnits ?? _unchanged,
      providerStatus: observation.providerStatus,
      providerSubstatus: observation.providerSubstatus,
      balanceRefreshPending: completed,
      submissionOutcomeUnknown: false,
    );
    await _store.upsert(observed);
    if (!completed) return;

    final reconciled = await _baseBalance.refresh();
    if (!reconciled) return;
    await _store.upsert(
      _copyReceipt(observed, balanceRefreshPending: false),
    );
  }

  Future<void> _refreshRelayStatus(String intentId) async {
    final relay = _relay;
    if (relay == null) {
      throw const BridgeValidationException('relay_deposit_disabled');
    }
    var receipt = _requireReceipt(intentId);
    final observation = await relay.status(receipt);
    final observedSourceHash = observation.sourceTransactionHash;
    if (receipt.state == BridgeFundingState.awaitingDeposit &&
        observation.state == BridgeFundingState.awaitingDeposit &&
        observedSourceHash == null &&
        receipt.sourceTransactionHash == null &&
        receipt.expiresAt != null &&
        !_now().isBefore(receipt.expiresAt!)) {
      await _store.upsert(
        _copyReceipt(
          receipt,
          state: BridgeFundingState.expired,
          providerStatus: observation.providerStatus,
          providerSubstatus: 'instruction_expired_without_deposit',
        ),
      );
      return;
    }

    final terminal = observation.state == BridgeFundingState.completed ||
        observation.state == BridgeFundingState.refunded ||
        observation.state == BridgeFundingState.partial;
    if ((receipt.state == BridgeFundingState.awaitingDeposit ||
            receipt.state == BridgeFundingState.expired) &&
        (observation.state == BridgeFundingState.depositDetected ||
            observation.state == BridgeFundingState.destinationPending ||
            terminal)) {
      final lateDepositEvidence = receipt.state == BridgeFundingState.expired
          ? _relayLateDepositEvidence(receipt, observation)
          : null;
      receipt = _copyReceipt(
        receipt,
        state: BridgeFundingState.depositDetected,
        sourceTransactionHash: observation.sourceTransactionHash ?? _unchanged,
        providerStatus: 'deposit_detected',
        providerSubstatus: null,
      );
      await _store.upsert(
        receipt,
        relayLateDepositEvidence: lateDepositEvidence,
      );
    }
    var nextState = observation.state;
    if (receipt.state == BridgeFundingState.expired &&
        observation.state == BridgeFundingState.awaitingDeposit) {
      nextState = BridgeFundingState.expired;
    } else if ((receipt.state == BridgeFundingState.depositDetected ||
            receipt.state == BridgeFundingState.destinationPending) &&
        observation.state == BridgeFundingState.awaitingDeposit) {
      nextState = receipt.state;
    } else if (receipt.state == BridgeFundingState.destinationPending &&
        observation.state == BridgeFundingState.depositDetected) {
      nextState = receipt.state;
    }
    final refreshBaseBalance = nextState == BridgeFundingState.completed ||
        nextState == BridgeFundingState.partial;
    final observed = _copyReceipt(
      receipt,
      state: nextState,
      sourceTransactionHash: observation.sourceTransactionHash ?? _unchanged,
      destinationTransactionHash:
          observation.destinationTransactionHash ?? _unchanged,
      actualOutputUnits: observation.actualOutputUnits ?? _unchanged,
      providerStatus: observation.providerStatus,
      providerSubstatus: observation.providerSubstatus,
      balanceRefreshPending: refreshBaseBalance,
    );
    await _store.upsert(observed);
    if (!refreshBaseBalance) return;
    if (!await _baseBalance.refresh()) return;
    await _store.upsert(
      _copyReceipt(observed, balanceRefreshPending: false),
    );
  }

  RelayLateDepositEvidence _relayLateDepositEvidence(
    BridgeFundingReceipt receipt,
    BridgeFundingObservation observation,
  ) {
    final requestId = receipt.providerRequestId;
    final depositAddress = receipt.depositAddress;
    final sourceHash = observation.sourceTransactionHash;
    if (requestId == null || depositAddress == null || sourceHash == null) {
      throw const BridgeValidationException(
        'relay_late_deposit_evidence_missing',
      );
    }
    return RelayLateDepositEvidence(
      requestId: requestId,
      depositAddress: depositAddress,
      sourceTransactionHash: sourceHash,
    );
  }

  Future<ExternalWalletIdentity> _connectedIdentity(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  }) async {
    final selected = transport ??
        (chain.type == BridgeChainType.evm
            ? ExternalWalletTransport.reownEvm
            : null);
    var existing = _wallet.identity;
    final existingDoesNotMatchRequest = existing != null &&
        ((selected != null && existing.transport != selected) ||
            existing.chainType != chain.type ||
            existing.chainId != chain.id);
    if (existingDoesNotMatchRequest) {
      await _wallet.disconnect();
      existing = null;
    }
    final identity = existing ??
        await _wallet.connect(
          chain,
          transport: selected,
        );
    final selectionMatches = selected == null || identity.transport == selected;
    final valid = switch (chain.type) {
      BridgeChainType.evm => selectionMatches &&
          _evmTransportEnabled(identity.transport) &&
          identity.chainType == BridgeChainType.evm &&
          identity.chainId == chain.id &&
          _validEvmAddress(identity.publicAddress) &&
          identity.approvedMethods.contains('eth_sendTransaction'),
      BridgeChainType.svm => selectionMatches &&
          identity.chainType == BridgeChainType.svm &&
          identity.chainId == BridgeConstants.solanaChainId &&
          _validSolanaPublicKey(identity.publicAddress) &&
          _solanaTransportEnabled(identity.transport) &&
          (identity.approvedMethods.contains('solana_signTransaction') ||
              identity.approvedMethods
                  .contains('solana_signAndSendTransaction')),
    };
    if (!valid) {
      throw const BridgeValidationException('connected_wallet_mismatch');
    }
    return identity;
  }

  void _validatePreparedIdentity(_PreparedEvmIntent prepared) {
    final current = _wallet.identity;
    if (current == null ||
        current.transport != prepared.identity.transport ||
        current.chainId != prepared.identity.chainId ||
        !_sameEvmAddress(
          current.publicAddress,
          prepared.identity.publicAddress,
        ) ||
        !current.approvedMethods.contains('eth_sendTransaction') ||
        prepared.fingerprint != _payloadFingerprint(prepared.payload)) {
      throw const BridgeValidationException('prepared_wallet_context_changed');
    }
  }

  void _validatePreparedSolanaIdentity(_PreparedSolanaIntent prepared) {
    final current = _wallet.identity;
    final currentInspection = _solanaEnvelope.inspect(prepared.payload);
    final methodUnchanged = switch (prepared.submissionMode) {
      SolanaWalletSubmissionMode.signOnly =>
        current?.approvedMethods.contains('solana_signTransaction') ?? false,
      SolanaWalletSubmissionMode.signAndSend => !(current?.approvedMethods
                  .contains('solana_signTransaction') ??
              true) &&
          (current?.approvedMethods.contains('solana_signAndSendTransaction') ??
              false),
    };
    if (current == null ||
        current.transport != prepared.identity.transport ||
        current.chainType != BridgeChainType.svm ||
        current.chainId != prepared.identity.chainId ||
        current.publicAddress != prepared.identity.publicAddress ||
        !_solanaTransportEnabled(current.transport) ||
        !methodUnchanged ||
        currentInspection.messageSha256 != prepared.fingerprint ||
        currentInspection.recentBlockhash !=
            prepared.inspection.recentBlockhash) {
      throw const BridgeValidationException('prepared_wallet_context_changed');
    }
  }

  Future<void> _runConfirmation(
    String intentId,
    Future<void> Function() action,
  ) async {
    if (_confirmationInFlight != null) {
      throw const BridgeValidationException('bridge_confirmation_in_progress');
    }
    _confirmationInFlight = intentId;
    try {
      await action();
    } finally {
      _confirmationInFlight = null;
    }
  }

  _PreparedEvmIntent _requirePrepared(
    String intentId,
    BridgeReviewKind kind,
  ) {
    final prepared = _prepared;
    if (prepared == null ||
        prepared.intentId != intentId ||
        prepared.reviewKind != kind) {
      throw const BridgeValidationException(
        'bridge_confirmation_not_available',
      );
    }
    return prepared;
  }

  _PreparedSolanaIntent _requirePreparedSolana(String intentId) {
    final prepared = _preparedSolana;
    if (prepared == null || prepared.intentId != intentId) {
      throw const BridgeValidationException(
        'bridge_confirmation_not_available',
      );
    }
    return prepared;
  }

  BridgeFundingReceipt _requireReviewReceipt(String intentId) {
    final receipt = _requireReceipt(intentId);
    if (receipt.state != BridgeFundingState.awaitingPlawieReview ||
        receipt.submissionOutcomeUnknown) {
      throw const BridgeValidationException(
        'bridge_confirmation_not_available',
      );
    }
    return receipt;
  }

  BridgeFundingReceipt _requireReceipt(String intentId) {
    final receipt = _store.receiptForIntent(intentId);
    if (receipt == null) {
      throw const BridgeValidationException('bridge_receipt_not_found');
    }
    return receipt;
  }

  Future<void> _failPreparationIfPossible(String intentId) async {
    final receipt = _store.receiptForIntent(intentId);
    if (receipt == null ||
        receipt.state == BridgeFundingState.failed ||
        receipt.state == BridgeFundingState.cancelled) {
      return;
    }
    try {
      await _store.upsert(
        _copyReceipt(
          receipt,
          state: BridgeFundingState.failed,
          providerStatus: 'preparation_failed',
        ),
      );
    } on Object {
      // Preserve the original preparation failure.
    }
    _prepared = null;
    _preparedSolana = null;
  }

  void _validatePreparationRequest(BridgeFundingRequest request) {
    if (request.method != BridgeFundingMethod.connectedWallet) {
      throw const BridgeValidationException('connected_bridge_disabled');
    }
    if (request.sourceChain.type == BridgeChainType.svm) {
      if (request.sourceChain.id != BridgeConstants.solanaChainId ||
          (!_solanaMwaEnabled && !_reownSolanaFallbackEnabled)) {
        throw const BridgeValidationException(
          'solana_connected_bridge_disabled',
        );
      }
      if (request.sourceToken.chainId != request.sourceChain.id ||
          !_validSolanaPublicKey(request.sourceToken.address) ||
          !_validEvmAddress(request.baseDestinationAddress) ||
          !_sameEvmAddress(
            request.baseDestinationAddress,
            _currentBaseAddress(),
          )) {
        throw const BridgeValidationException('invalid_bridge_request');
      }
      _positiveAmount(request.amountUnits);
      return;
    }
    if (!_reownEvmEnabled && !_baseAccountMwpEnabled) {
      throw const BridgeValidationException('evm_connected_bridge_disabled');
    }
    if (request.sourceToken.chainId != request.sourceChain.id ||
        !_validEvmAddress(request.sourceToken.address) ||
        !_validEvmAddress(request.baseDestinationAddress) ||
        !_sameEvmAddress(
          request.baseDestinationAddress,
          _currentBaseAddress(),
        )) {
      throw const BridgeValidationException('invalid_bridge_request');
    }
    _positiveAmount(request.amountUnits);
  }

  bool _isDirectBaseUsdc(BridgeFundingRequest request) =>
      request.sourceChain.type == BridgeChainType.evm &&
      request.sourceChain.id == BridgeConstants.baseChainId &&
      _sameEvmAddress(request.sourceToken.address, BridgeConstants.baseUsdc);

  bool _solanaTransportEnabled(ExternalWalletTransport transport) =>
      switch (transport) {
        ExternalWalletTransport.solanaMwa => _solanaMwaEnabled,
        ExternalWalletTransport.reownSolanaPhantom ||
        ExternalWalletTransport.reownSolanaSolflare =>
          _reownSolanaFallbackEnabled,
        _ => false,
      };

  bool _evmTransportEnabled(ExternalWalletTransport transport) =>
      switch (transport) {
        ExternalWalletTransport.reownEvm => _reownEvmEnabled,
        ExternalWalletTransport.baseAccountMwp => _baseAccountMwpEnabled,
        _ => false,
      };

  bool _validSolanaPublicKey(String value) {
    try {
      _solanaEnvelope.base58Decode(value, expectedLength: 32);
      return true;
    } on BridgeValidationException {
      return false;
    }
  }

  String _currentBaseAddress() {
    final address = _internalBaseAddress();
    if (!_validEvmAddress(address)) {
      throw const BridgeValidationException(
          'internal_base_address_unavailable');
    }
    return address;
  }

  DateTime _now() => _clock().toUtc();
}

final class _PreparedEvmIntent {
  const _PreparedEvmIntent({
    required this.intentId,
    required this.request,
    required this.identity,
    required this.quote,
    required this.payload,
    required this.reviewKind,
  });

  final String intentId;
  final BridgeFundingRequest request;
  final ExternalWalletIdentity identity;
  final BridgeExecutableQuote quote;
  final EvmBridgeExecutionPayload payload;
  final BridgeReviewKind reviewKind;

  String get fingerprint => _payloadFingerprint(payload);
}

final class _PreparedSolanaIntent {
  const _PreparedSolanaIntent({
    required this.intentId,
    required this.request,
    required this.identity,
    required this.quote,
    required this.payload,
    required this.inspection,
    required this.submissionMode,
  });

  final String intentId;
  final BridgeFundingRequest request;
  final ExternalWalletIdentity identity;
  final BridgeExecutableQuote quote;
  final SolanaBridgeExecutionPayload payload;
  final SolanaTransactionInspection inspection;
  final SolanaWalletSubmissionMode submissionMode;

  String get fingerprint => inspection.messageSha256;
}

BridgeFundingReceipt _newReceipt(
  BridgeFundingRequest request,
  String intentId,
  DateTime now,
) =>
    BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: intentId,
      method: request.method,
      provider: 'pending',
      state: BridgeFundingState.draft,
      sourceChainId: request.sourceChain.id,
      sourceTokenAddress: request.sourceToken.address,
      sourceTokenSymbol: request.sourceToken.symbol,
      sourceAmountUnits: request.amountUnits,
      baseDestinationAddress: request.baseDestinationAddress,
      sourceAddress: request.sourceAddress,
      refundAddress: request.refundAddress,
      createdAt: now,
      updatedAt: now,
    );

const _unchanged = Object();

BridgeFundingReceipt _copyReceipt(
  BridgeFundingReceipt source, {
  BridgeFundingState? state,
  String? provider,
  Object? sourceAddress = _unchanged,
  Object? depositAddress = _unchanged,
  Object? providerQuoteId = _unchanged,
  Object? providerRequestId = _unchanged,
  Object? routeTool = _unchanged,
  Object? minimumOutputUnits = _unchanged,
  Object? actualOutputUnits = _unchanged,
  Object? sourceTransactionHash = _unchanged,
  Object? destinationTransactionHash = _unchanged,
  Object? providerStatus = _unchanged,
  Object? providerSubstatus = _unchanged,
  Object? walletTransport = _unchanged,
  Object? reviewedPayloadHash = _unchanged,
  Object? sourceBlockhash = _unchanged,
  Object? expiresAt = _unchanged,
  Object? archivedAt = _unchanged,
  bool? depositAddressExposed,
  bool? balanceRefreshPending,
  bool? submissionOutcomeUnknown,
}) =>
    BridgeFundingReceipt(
      schemaVersion: source.schemaVersion,
      intentId: source.intentId,
      method: source.method,
      provider: provider ?? source.provider,
      state: state ?? source.state,
      sourceChainId: source.sourceChainId,
      sourceTokenAddress: source.sourceTokenAddress,
      sourceTokenSymbol: source.sourceTokenSymbol,
      sourceAmountUnits: source.sourceAmountUnits,
      baseDestinationAddress: source.baseDestinationAddress,
      sourceAddress: identical(sourceAddress, _unchanged)
          ? source.sourceAddress
          : sourceAddress as String?,
      refundAddress: source.refundAddress,
      depositAddress: identical(depositAddress, _unchanged)
          ? source.depositAddress
          : depositAddress as String?,
      providerQuoteId: identical(providerQuoteId, _unchanged)
          ? source.providerQuoteId
          : providerQuoteId as String?,
      providerRequestId: identical(providerRequestId, _unchanged)
          ? source.providerRequestId
          : providerRequestId as String?,
      routeTool: identical(routeTool, _unchanged)
          ? source.routeTool
          : routeTool as String?,
      minimumOutputUnits: identical(minimumOutputUnits, _unchanged)
          ? source.minimumOutputUnits
          : minimumOutputUnits as String?,
      actualOutputUnits: identical(actualOutputUnits, _unchanged)
          ? source.actualOutputUnits
          : actualOutputUnits as String?,
      sourceTransactionHash: identical(sourceTransactionHash, _unchanged)
          ? source.sourceTransactionHash
          : sourceTransactionHash as String?,
      destinationTransactionHash:
          identical(destinationTransactionHash, _unchanged)
              ? source.destinationTransactionHash
              : destinationTransactionHash as String?,
      providerStatus: identical(providerStatus, _unchanged)
          ? source.providerStatus
          : providerStatus as String?,
      providerSubstatus: identical(providerSubstatus, _unchanged)
          ? source.providerSubstatus
          : providerSubstatus as String?,
      walletTransport: identical(walletTransport, _unchanged)
          ? source.walletTransport
          : walletTransport as ExternalWalletTransport?,
      reviewedPayloadHash: identical(reviewedPayloadHash, _unchanged)
          ? source.reviewedPayloadHash
          : reviewedPayloadHash as String?,
      sourceBlockhash: identical(sourceBlockhash, _unchanged)
          ? source.sourceBlockhash
          : sourceBlockhash as String?,
      createdAt: source.createdAt,
      updatedAt: DateTime.now().toUtc(),
      expiresAt: identical(expiresAt, _unchanged)
          ? source.expiresAt
          : expiresAt as DateTime?,
      archivedAt: identical(archivedAt, _unchanged)
          ? source.archivedAt
          : archivedAt as DateTime?,
      depositAddressExposed:
          depositAddressExposed ?? source.depositAddressExposed,
      balanceRefreshPending:
          balanceRefreshPending ?? source.balanceRefreshPending,
      submissionOutcomeUnknown:
          submissionOutcomeUnknown ?? source.submissionOutcomeUnknown,
    );

BridgeFundingRequest _withConnectedAddress(
  BridgeFundingRequest request,
  String connectedAddress,
) =>
    BridgeFundingRequest(
      method: request.method,
      sourceChain: request.sourceChain,
      sourceToken: request.sourceToken,
      amount: request.amount,
      amountUnits: request.amountUnits,
      baseDestinationAddress: request.baseDestinationAddress,
      sourceAddress: connectedAddress,
      refundAddress: request.refundAddress,
      selfCustodyConfirmed: request.selfCustodyConfirmed,
    );

String _payloadFingerprint(EvmBridgeExecutionPayload payload) {
  final canonical = <Object?>[
    payload.chainId,
    payload.from.toLowerCase(),
    payload.to.toLowerCase(),
    _normalizedQuantity(payload.valueHex),
    payload.dataHex.toLowerCase(),
  ];
  return sha256.convert(utf8.encode(canonical.join('|'))).toString();
}

String _normalizedQuantity(String value) {
  if (!RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value)) {
    throw const BridgeValidationException('invalid_evm_transaction');
  }
  return _quantity(BigInt.parse(value.substring(2), radix: 16));
}

String _quantity(BigInt value) => '0x${value.toRadixString(16)}';

void _validateGasLimit(String raw) {
  if (!RegExp(r'^0x(?:0|[1-9a-fA-F][0-9a-fA-F]*)$').hasMatch(raw)) {
    throw const BridgeValidationException('invalid_evm_gas_limit');
  }
  final value = BigInt.parse(raw.substring(2), radix: 16);
  if (value < BigInt.from(21000) || value > BigInt.from(5000000)) {
    throw const BridgeValidationException('evm_gas_limit_out_of_bounds');
  }
}

BigInt _positiveAmount(String raw) {
  final amount = BigInt.tryParse(raw);
  if (amount == null || amount <= BigInt.zero) {
    throw const BridgeValidationException('invalid_bridge_amount');
  }
  return amount;
}

bool _validEvmAddress(String value) =>
    RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value);

bool _sameEvmAddress(String left, String right) =>
    left.toLowerCase() == right.toLowerCase();

bool _validTransactionHash(String value) =>
    RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(value);

bool _hasLifiObservation(BridgeFundingReceipt receipt) =>
    receipt.providerStatus == 'NOT_FOUND' ||
    receipt.providerStatus == 'PENDING' ||
    receipt.providerStatus == 'DONE' ||
    receipt.providerStatus == 'FAILED';

bool _isTerminalState(BridgeFundingState state) =>
    state == BridgeFundingState.completed ||
    state == BridgeFundingState.failed ||
    state == BridgeFundingState.refunded ||
    state == BridgeFundingState.partial ||
    state == BridgeFundingState.expired ||
    state == BridgeFundingState.cancelled;

bool _alwaysForeground() => true;

bool _isNativeToken(String address) {
  final normalized = address.toLowerCase();
  return normalized == '0x0000000000000000000000000000000000000000' ||
      normalized == '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
}

bool _isKnownWalletRejection(String code) {
  final normalized = code.toLowerCase();
  return normalized == '4001' ||
      normalized == 'user_rejected' ||
      normalized == 'request_rejected' ||
      normalized == 'wallet_user_rejected' ||
      normalized.contains('user rejected');
}

String _secureIntentId() {
  final random = Random.secure();
  return List<int>.generate(16, (_) => random.nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}
