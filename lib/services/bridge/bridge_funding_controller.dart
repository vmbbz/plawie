import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'bridge_models.dart';
import 'bridge_receipt_store.dart';
import 'evm_bridge_rpc_service.dart';
import 'external_wallet_session_service.dart';
import 'lifi_bridge_service.dart';
import 'lifi_transaction_validator.dart';

enum BridgeReviewKind { allowance, bridge }

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

final class BridgeFundingController {
  BridgeFundingController({
    required BridgeExecutableQuoteProvider quoteProvider,
    required ExternalWalletSessionService wallet,
    required BridgeReceiptStore receiptStore,
    required EvmBridgeRpc rpc,
    required BaseBalanceRefreshService baseBalance,
    required String Function() internalBaseAddress,
    bool lifiConnectedEnabled = BridgeFeatureConfig.lifiConnectedEnabled,
    bool reownEvmEnabled = BridgeFeatureConfig.reownEvmWalletsEnabled,
    LifiTransactionValidator transactionValidator =
        const LifiTransactionValidator(),
    DateTime Function()? clock,
    String Function()? intentIdFactory,
  })  : _quoteProvider = quoteProvider,
        _wallet = wallet,
        _store = receiptStore,
        _rpc = rpc,
        _baseBalance = baseBalance,
        _internalBaseAddress = internalBaseAddress,
        _lifiConnectedEnabled = lifiConnectedEnabled,
        _reownEvmEnabled = reownEvmEnabled,
        _transactionValidator = transactionValidator,
        _clock = clock ?? DateTime.now,
        _intentIdFactory = intentIdFactory ?? _secureIntentId;

  final BridgeExecutableQuoteProvider _quoteProvider;
  final ExternalWalletSessionService _wallet;
  final BridgeReceiptStore _store;
  final EvmBridgeRpc _rpc;
  final BaseBalanceRefreshService _baseBalance;
  final String Function() _internalBaseAddress;
  final bool _lifiConnectedEnabled;
  final bool _reownEvmEnabled;
  final LifiTransactionValidator _transactionValidator;
  final DateTime Function() _clock;
  final String Function() _intentIdFactory;

  _PreparedEvmIntent? _prepared;
  String? _confirmationInFlight;

  BridgeReviewKind? pendingReviewKind(String intentId) {
    final prepared = _prepared;
    return prepared?.intentId == intentId ? prepared?.reviewKind : null;
  }

  Future<void> prepareConnected(BridgeFundingRequest request) async {
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

      final identity = await _connectedIdentity(request.sourceChain);
      receipt = _copyReceipt(
        receipt,
        state: BridgeFundingState.quoting,
        sourceAddress: identity.publicAddress,
        walletTransport: identity.transport,
      );
      await _store.upsert(receipt);

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

  Future<void> confirmConnectedBridge(String intentId) =>
      _runConfirmation(intentId, () async {
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
    await _wallet.disconnect();
  }

  Future<void> refreshStatus(String intentId) async {
    final receipt = _requireReceipt(intentId);
    if (receipt.state == BridgeFundingState.awaitingExternalWallet &&
        receipt.sourceTransactionHash == null) {
      await _store.upsert(
        _copyReceipt(
          receipt,
          providerStatus: 'wallet_outcome_unknown',
          submissionOutcomeUnknown: true,
        ),
      );
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
          return;
        }
        final reconciled = await _baseBalance.refresh();
        await _store.upsert(
          _copyReceipt(
            receipt,
            state: reconciled
                ? BridgeFundingState.completed
                : (receipt.state == BridgeFundingState.submitted
                    ? BridgeFundingState.sourcePending
                    : receipt.state),
            providerStatus:
                reconciled ? 'direct_transfer_completed' : 'source_confirmed',
            providerSubstatus:
                reconciled ? null : 'base_balance_refresh_failed',
            actualOutputUnits: reconciled
                ? receipt.sourceAmountUnits
                : receipt.actualOutputUnits,
            balanceRefreshPending: !reconciled,
          ),
        );
    }
  }

  Future<ExternalWalletIdentity> _connectedIdentity(BridgeChain chain) async {
    final existing = _wallet.identity;
    final identity = existing ??
        await _wallet.connect(
          chain,
          transport: ExternalWalletTransport.reownEvm,
        );
    if (identity.transport != ExternalWalletTransport.reownEvm ||
        identity.chainType != BridgeChainType.evm ||
        identity.chainId != chain.id ||
        !_validEvmAddress(identity.publicAddress) ||
        !identity.approvedMethods.contains('eth_sendTransaction')) {
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
  }

  void _validatePreparationRequest(BridgeFundingRequest request) {
    if (request.method != BridgeFundingMethod.connectedWallet ||
        request.sourceChain.type != BridgeChainType.evm ||
        !_reownEvmEnabled) {
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
      request.sourceChain.id == BridgeConstants.baseChainId &&
      _sameEvmAddress(request.sourceToken.address, BridgeConstants.baseUsdc);

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
  Object? providerQuoteId = _unchanged,
  Object? routeTool = _unchanged,
  Object? minimumOutputUnits = _unchanged,
  Object? actualOutputUnits = _unchanged,
  Object? sourceTransactionHash = _unchanged,
  Object? providerStatus = _unchanged,
  Object? providerSubstatus = _unchanged,
  Object? walletTransport = _unchanged,
  Object? reviewedPayloadHash = _unchanged,
  Object? expiresAt = _unchanged,
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
      depositAddress: source.depositAddress,
      providerQuoteId: identical(providerQuoteId, _unchanged)
          ? source.providerQuoteId
          : providerQuoteId as String?,
      providerRequestId: source.providerRequestId,
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
      destinationTransactionHash: source.destinationTransactionHash,
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
      sourceBlockhash: source.sourceBlockhash,
      createdAt: source.createdAt,
      updatedAt: DateTime.now().toUtc(),
      expiresAt: identical(expiresAt, _unchanged)
          ? source.expiresAt
          : expiresAt as DateTime?,
      archivedAt: source.archivedAt,
      depositAddressExposed: source.depositAddressExposed,
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
      normalized.contains('user rejected');
}

String _secureIntentId() {
  final random = Random.secure();
  return List<int>.generate(16, (_) => random.nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}
