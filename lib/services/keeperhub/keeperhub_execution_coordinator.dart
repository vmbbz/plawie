import 'dart:async';

import 'package:uuid/uuid.dart';

import '../native_bridge.dart';
import 'keeperhub_api_client.dart';
import 'keeperhub_approval_broker.dart';
import 'keeperhub_auth_store.dart';
import 'keeperhub_execution_models.dart';
import 'keeperhub_models.dart';
import 'keeperhub_policy.dart';
import 'keeperhub_receipt_store.dart';

typedef KeeperHubExecutionAttester = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> execution,
);

/// Reliability coordinator for one deliberately narrow proof action:
/// zero-value Base Sepolia self-transfer from the KeeperHub Agent Wallet.
class KeeperHubExecutionCoordinator {
  KeeperHubExecutionCoordinator({
    KeeperHubApiClient? api,
    KeeperHubAuthStore? authStore,
    KeeperHubReceiptStore? receiptStore,
    KeeperHubApprovalBroker? approvalBroker,
    KeeperHubExecutionAttester? attester,
    DateTime Function()? clock,
    Future<void> Function(Duration duration)? delay,
    Uuid? uuid,
    this.maxPollAttempts = 90,
  })  : _api = api ?? KeeperHubApiClient(),
        _authStore = authStore ?? KeeperHubAuthStore(),
        receiptStore = receiptStore ?? KeeperHubReceiptStore(),
        approvalBroker = approvalBroker ?? KeeperHubApprovalBroker.instance,
        _attester = attester ?? NativeBridge.attestSecureKeeperHubExecution,
        _clock = clock ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed,
        _uuid = uuid ?? const Uuid();

  final KeeperHubApiClient _api;
  final KeeperHubAuthStore _authStore;
  final KeeperHubExecutionAttester _attester;
  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _delay;
  final Uuid _uuid;
  final int maxPollAttempts;
  final KeeperHubReceiptStore receiptStore;
  final KeeperHubApprovalBroker approvalBroker;

  Future<KeeperHubExecutionRecord> prepareProof({
    required String taskId,
    required String reason,
  }) async {
    if (await receiptStore.active() != null) {
      throw const KeeperHubException(
        'execution_already_active',
        'Recover or finish the active Agent Wallet execution first.',
      );
    }
    final credential = await _requireReadyCredential();
    final agentWallet = credential.record.agentWalletAddress!;
    final normalizedTask = KeeperHubProofPolicy.normalizeTaskId(taskId);
    final normalizedReason = KeeperHubProofPolicy.normalizeReason(reason);
    final transfer = KeeperHubProofPolicy.transferBody(agentWallet);
    final now = _clock().toUtc();
    var record = KeeperHubExecutionRecord(
      intentId: 'kh_${_uuid.v4().replaceAll('-', '')}',
      taskId: normalizedTask,
      phase: KeeperHubExecutionPhase.proposed,
      personalWalletAddress: credential.record.personalWalletAddress,
      agentWalletAddress: agentWallet,
      reason: normalizedReason,
      transfer: Map<String, dynamic>.unmodifiable(transfer),
      createdAt: now,
      updatedAt: now,
    );
    await receiptStore.upsert(record);

    KeeperHubApiResponse response;
    try {
      response = await _api.simulateTransfer(
        apiKey: credential.apiKey,
        transfer: transfer,
      );
    } on KeeperHubException catch (error) {
      record = record.copyWith(
        phase: KeeperHubExecutionPhase.simulationFailed,
        errorCode: error.code,
        errorMessage: 'KeeperHub simulation could not be completed safely.',
        updatedAt: _clock().toUtc(),
      );
      await receiptStore.upsert(record);
      rethrow;
    }
    try {
      final simulation = KeeperHubProofPolicy.parseSimulation(
        body: response.body,
        expectedAgentWallet: agentWallet,
      );
      final safe = response.statusCode == 200 &&
          simulation.success &&
          !simulation.wouldRevert;
      if (!safe) {
        record = record.copyWith(
          phase: KeeperHubExecutionPhase.simulationFailed,
          simulation: simulation,
          errorCode: simulation.code ?? 'simulation_reverted',
          errorMessage:
              simulation.revertReason ?? 'The proof would fail on-chain.',
          updatedAt: _clock().toUtc(),
        );
        await receiptStore.upsert(record);
        throw KeeperHubException(
          record.errorCode!,
          record.errorMessage!,
        );
      }
      final fingerprint = KeeperHubProofPolicy.simulationFingerprint(
        transfer: transfer,
        simulation: simulation,
      );
      final idempotencyKey = KeeperHubProofPolicy.idempotencyKey(
        taskId: normalizedTask,
        recipientAddress: agentWallet,
      );
      record = record.copyWith(
        phase: KeeperHubExecutionPhase.awaitingApproval,
        simulation: simulation,
        simulationFingerprint: fingerprint,
        idempotencyKey: idempotencyKey,
        approvalExpiresAt: _clock().toUtc().add(const Duration(minutes: 5)),
        updatedAt: _clock().toUtc(),
      );
      await receiptStore.upsert(record);
      return record;
    } on KeeperHubException {
      rethrow;
    } on FormatException {
      record = record.copyWith(
        phase: KeeperHubExecutionPhase.simulationFailed,
        errorCode: 'simulation_response_invalid',
        errorMessage: 'KeeperHub returned an invalid simulation response.',
        updatedAt: _clock().toUtc(),
      );
      await receiptStore.upsert(record);
      throw const KeeperHubException(
        'simulation_response_invalid',
        'KeeperHub returned an invalid simulation response.',
      );
    }
  }

  Future<KeeperHubExecutionRecord> reviewAndExecute(String intentId) async {
    var record = await _requireRecord(intentId);
    if (record.phase != KeeperHubExecutionPhase.awaitingApproval ||
        record.simulation == null ||
        record.simulationFingerprint == null ||
        record.idempotencyKey == null ||
        record.approvalExpiresAt == null) {
      throw const KeeperHubException(
        'execution_not_awaiting_approval',
        'This Agent Wallet execution is not awaiting review.',
      );
    }
    _validateBoundRecord(record, requireAttestation: false);
    final decision = await approvalBroker.requestApproval(
      PendingKeeperHubApproval(
        intentId: record.intentId,
        personalWalletAddress: record.personalWalletAddress,
        agentWalletAddress: record.agentWalletAddress,
        chainId: KeeperHubProofPolicy.baseSepoliaChainId,
        amount: '0 ETH',
        reason: record.reason,
        simulation: record.simulation!,
        simulationFingerprint: record.simulationFingerprint!,
        idempotencyKey: record.idempotencyKey!,
        expiresAt: record.approvalExpiresAt!,
      ),
    );
    if (decision != KeeperHubApprovalDecision.approved) {
      record = record.copyWith(
        phase: KeeperHubExecutionPhase.rejected,
        errorCode: 'approval_${decision.name}',
        errorMessage: 'The Agent Wallet execution was not authorized.',
        updatedAt: _clock().toUtc(),
      );
      await receiptStore.upsert(record);
      return record;
    }

    final attestation = await _attester(<String, dynamic>{
      'intentId': record.intentId,
      'chainId': KeeperHubProofPolicy.baseSepoliaChainId,
      'from': record.agentWalletAddress,
      'to': record.transfer['recipientAddress'],
      'amount': record.transfer['amount'],
      'simulationFingerprint': record.simulationFingerprint,
      'idempotencyKey': record.idempotencyKey,
      'expiresAt': record.approvalExpiresAt!.toUtc().toIso8601String(),
    });
    final attestingWallet = requireKeeperHubAddress(
      attestation['walletAddress'],
      'attesting Personal Wallet',
    );
    if (attestingWallet.toLowerCase() !=
            record.personalWalletAddress.toLowerCase() ||
        attestation['intentId'] != record.intentId ||
        attestation['simulationFingerprint'] != record.simulationFingerprint ||
        attestation['idempotencyKey'] != record.idempotencyKey) {
      throw const KeeperHubException(
        'attestation_mismatch',
        'Android attested different Agent Wallet execution details.',
      );
    }
    final digest = attestation['attestationDigest']?.toString() ?? '';
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(digest)) {
      throw const KeeperHubException(
        'attestation_invalid',
        'Android returned an invalid execution attestation.',
      );
    }
    // The EIP-191 signature is intentionally discarded here. The local receipt
    // retains only the digest and public Personal Wallet identity.
    record = record.copyWith(
      phase: KeeperHubExecutionPhase.approved,
      attestationDigest: digest,
      updatedAt: _clock().toUtc(),
    );
    await receiptStore.upsert(record);
    return _submit(record);
  }

  Future<KeeperHubExecutionRecord?> resumeActive() async {
    var record = await receiptStore.active();
    if (record == null) return null;
    switch (record.phase) {
      case KeeperHubExecutionPhase.approved:
        return _submit(record);
      case KeeperHubExecutionPhase.outcomeUnknown:
        // If KeeperHub already returned an execution ID, reconciliation is
        // read-only. Replay the exact payload/key only when no status handle
        // was ever received.
        return record.executionId == null ? _submit(record) : _poll(record);
      case KeeperHubExecutionPhase.submitting:
        record = record.copyWith(
          phase: KeeperHubExecutionPhase.outcomeUnknown,
          errorCode: 'submission_interrupted',
          errorMessage: 'Recovering the exact idempotent submission.',
          updatedAt: _clock().toUtc(),
        );
        await receiptStore.upsert(record);
        return _submit(record);
      case KeeperHubExecutionPhase.polling:
        return _poll(record);
      case KeeperHubExecutionPhase.proposed:
      case KeeperHubExecutionPhase.awaitingApproval:
      case KeeperHubExecutionPhase.simulationFailed:
      case KeeperHubExecutionPhase.rejected:
      case KeeperHubExecutionPhase.completed:
      case KeeperHubExecutionPhase.failed:
        return record;
    }
  }

  Future<KeeperHubExecutionRecord> discardPrepared(String intentId) async {
    var record = await _requireRecord(intentId);
    if (record.phase != KeeperHubExecutionPhase.proposed &&
        record.phase != KeeperHubExecutionPhase.awaitingApproval) {
      throw const KeeperHubException(
        'execution_cannot_be_discarded',
        'Only a proof that has not been authorized or submitted can be discarded.',
      );
    }
    record = record.copyWith(
      phase: KeeperHubExecutionPhase.rejected,
      errorCode: 'user_discarded',
      errorMessage: 'The proof was discarded before authorization.',
      updatedAt: _clock().toUtc(),
    );
    await receiptStore.upsert(record);
    return record;
  }

  Future<KeeperHubExecutionRecord> _submit(
    KeeperHubExecutionRecord record,
  ) async {
    _validateBoundRecord(record, requireAttestation: true);
    final credential = await _requireReadyCredential();
    if (record.attestationDigest == null || record.idempotencyKey == null) {
      throw const KeeperHubException(
        'execution_not_attested',
        'The Agent Wallet execution has no device-authenticated approval.',
      );
    }
    record = record.copyWith(
      phase: KeeperHubExecutionPhase.submitting,
      clearError: true,
      updatedAt: _clock().toUtc(),
    );
    await receiptStore.upsert(record);
    KeeperHubApiResponse response;
    try {
      response = await _api.executeTransfer(
        apiKey: credential.apiKey,
        transfer: record.transfer,
        idempotencyKey: record.idempotencyKey!,
      );
    } on KeeperHubException catch (error) {
      record = record.copyWith(
        phase: KeeperHubExecutionPhase.outcomeUnknown,
        errorCode: error.code,
        errorMessage:
            'Submission outcome is unknown. Plawie will reconcile using the same work key.',
        updatedAt: _clock().toUtc(),
      );
      await receiptStore.upsert(record);
      return record;
    }

    var executionId = response.body['executionId']?.toString().trim();
    if (response.statusCode == 409) {
      executionId = response.body['originalExecutionId']?.toString().trim();
      if (executionId == null || executionId.isEmpty) {
        record = record.copyWith(
          phase: KeeperHubExecutionPhase.outcomeUnknown,
          errorCode:
              response.body['code']?.toString() ?? 'idempotency_in_progress',
          errorMessage:
              'The exact submission is still reconciling; its key was not rotated.',
          updatedAt: _clock().toUtc(),
        );
        await receiptStore.upsert(record);
        return record;
      }
    } else if (!response.isSuccess) {
      final ambiguous = response.statusCode >= 500;
      record = record.copyWith(
        phase: ambiguous
            ? KeeperHubExecutionPhase.outcomeUnknown
            : KeeperHubExecutionPhase.failed,
        errorCode: response.body['code']?.toString() ??
            'execution_http_${response.statusCode}',
        errorMessage: ambiguous
            ? 'KeeperHub response was ambiguous; the exact work key remains active.'
            : 'KeeperHub rejected the reviewed proof before execution.',
        updatedAt: _clock().toUtc(),
      );
      await receiptStore.upsert(record);
      return record;
    }
    if (executionId == null ||
        !RegExp(r'^[A-Za-z0-9_-]{8,160}$').hasMatch(executionId)) {
      record = record.copyWith(
        phase: KeeperHubExecutionPhase.outcomeUnknown,
        errorCode: 'execution_id_missing',
        errorMessage:
            'KeeperHub accepted the request without a recoverable execution ID.',
        updatedAt: _clock().toUtc(),
      );
      await receiptStore.upsert(record);
      return record;
    }
    record = record.copyWith(
      phase: KeeperHubExecutionPhase.polling,
      executionId: executionId,
      remoteStatus: response.body['status']?.toString(),
      idempotentReplay: response.body['idempotentReplay'] == true,
      clearError: true,
      updatedAt: _clock().toUtc(),
    );
    await receiptStore.upsert(record);
    return _poll(record);
  }

  Future<KeeperHubExecutionRecord> _poll(
    KeeperHubExecutionRecord record,
  ) async {
    _validateBoundRecord(record, requireAttestation: true);
    final credential = await _requireReadyCredential();
    final executionId = record.executionId;
    if (executionId == null) {
      throw const KeeperHubException(
        'execution_id_missing',
        'The Agent Wallet execution cannot be polled without an ID.',
      );
    }
    for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
      KeeperHubApiResponse response;
      try {
        response = await _api.executionStatus(
          apiKey: credential.apiKey,
          executionId: executionId,
        );
      } on KeeperHubException catch (error) {
        record = record.copyWith(
          phase: KeeperHubExecutionPhase.outcomeUnknown,
          errorCode: error.code,
          errorMessage:
              'Status is temporarily unknown; no new execution will be created.',
          updatedAt: _clock().toUtc(),
        );
        await receiptStore.upsert(record);
        return record;
      }
      if (!response.isSuccess) {
        record = record.copyWith(
          phase: KeeperHubExecutionPhase.outcomeUnknown,
          errorCode: response.body['code']?.toString() ??
              'status_http_${response.statusCode}',
          errorMessage:
              'KeeperHub status could not be reconciled; the work key remains active.',
          updatedAt: _clock().toUtc(),
        );
        await receiptStore.upsert(record);
        return record;
      }
      try {
        record = _applyStatus(record, response.body);
      } on Object catch (error) {
        if (error is! KeeperHubException && error is! FormatException) {
          rethrow;
        }
        record = record.copyWith(
          phase: KeeperHubExecutionPhase.outcomeUnknown,
          errorCode: 'execution_status_invalid',
          errorMessage:
              'KeeperHub returned an invalid status; no new execution will be created.',
          updatedAt: _clock().toUtc(),
        );
      }
      await receiptStore.upsert(record);
      if (record.phase != KeeperHubExecutionPhase.polling) return record;
      final hint = int.tryParse(
            response.headers['x-poll-interval-hint'] ?? '',
          ) ??
          2;
      await _delay(Duration(seconds: hint.clamp(1, 15)));
    }
    record = record.copyWith(
      phase: KeeperHubExecutionPhase.outcomeUnknown,
      errorCode: 'poll_deadline_exceeded',
      errorMessage:
          'Execution is still unsettled. Resume later without changing its work key.',
      updatedAt: _clock().toUtc(),
    );
    await receiptStore.upsert(record);
    return record;
  }

  KeeperHubExecutionRecord _applyStatus(
    KeeperHubExecutionRecord record,
    Map<String, dynamic> body,
  ) {
    final status = body['status']?.toString().trim() ?? '';
    if (status == 'pending' || status == 'running') {
      return record.copyWith(
        phase: KeeperHubExecutionPhase.polling,
        remoteStatus: status,
        sponsored: _optionalSponsored(body['sponsored']),
        updatedAt: _clock().toUtc(),
      );
    }
    final receipts = _parseReceipts(body['receipts']);
    final hash = _optionalTransactionHash(body['transactionHash']);
    final link = _optionalHttpsLink(body['transactionLink']);
    if (status == 'completed') {
      final verified = hash != null &&
          receipts.length == 1 &&
          receipts.single.hash.toLowerCase() == hash.toLowerCase() &&
          receipts.single.chainId == KeeperHubProofPolicy.baseSepoliaChainId &&
          receipts.single.verified &&
          receipts.single.receiptStatus == 'success' &&
          receipts.single.verifiedAt != null;
      return record.copyWith(
        phase: verified
            ? KeeperHubExecutionPhase.completed
            : KeeperHubExecutionPhase.outcomeUnknown,
        remoteStatus: status,
        sponsored: _optionalSponsored(body['sponsored']),
        transactionHash: hash,
        transactionLink: link,
        receipts: receipts,
        errorCode: verified ? null : 'receipt_not_verified',
        errorMessage: verified
            ? null
            : 'KeeperHub completion lacks a fully verified on-chain receipt.',
        clearError: verified,
        updatedAt: _clock().toUtc(),
      );
    }
    if (status == 'failed') {
      final uncertain = receipts.any(
        (receipt) => const <String>{'not_found', 'timeout'}
            .contains(receipt.receiptStatus),
      );
      return record.copyWith(
        phase: uncertain
            ? KeeperHubExecutionPhase.outcomeUnknown
            : KeeperHubExecutionPhase.failed,
        remoteStatus: status,
        sponsored: _optionalSponsored(body['sponsored']),
        transactionHash: hash,
        transactionLink: link,
        receipts: receipts,
        errorCode: uncertain ? 'receipt_unsettled' : 'execution_failed',
        errorMessage: uncertain
            ? 'A claimed transaction has not reached a definitive receipt state.'
            : 'KeeperHub reports that the reviewed execution failed.',
        updatedAt: _clock().toUtc(),
      );
    }
    throw const KeeperHubException(
      'execution_status_invalid',
      'KeeperHub returned an unknown execution status.',
    );
  }

  List<KeeperHubVerifiedReceipt> _parseReceipts(Object? value) {
    if (value is! List) return const <KeeperHubVerifiedReceipt>[];
    return value
        .whereType<Map>()
        .map(
          (receipt) => KeeperHubVerifiedReceipt.fromJson(
            Map<String, dynamic>.from(receipt),
          ),
        )
        .toList(growable: false);
  }

  String? _optionalTransactionHash(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(text)) {
      throw const KeeperHubException(
        'transaction_hash_invalid',
        'KeeperHub returned an invalid transaction hash.',
      );
    }
    return text;
  }

  String? _optionalHttpsLink(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    final uri = Uri.tryParse(text);
    if (text.length > 500 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const KeeperHubException(
        'transaction_link_invalid',
        'KeeperHub returned an invalid transaction link.',
      );
    }
    return text;
  }

  bool? _optionalSponsored(Object? value) {
    if (value == null) return null;
    if (value is! bool) {
      throw const KeeperHubException(
        'sponsorship_state_invalid',
        'KeeperHub returned an invalid sponsorship state.',
      );
    }
    return value;
  }

  Future<KeeperHubStoredCredential> _requireReadyCredential() async {
    final credential = await _authStore.read();
    if (credential == null || !credential.record.isReady) {
      throw const KeeperHubException(
        'agent_wallet_not_ready',
        'Connect and verify the Agent Execution Wallet first.',
      );
    }
    return credential;
  }

  Future<KeeperHubExecutionRecord> _requireRecord(String intentId) async {
    final record = await receiptStore.forIntent(intentId);
    if (record == null) {
      throw const KeeperHubException(
        'execution_not_found',
        'The Agent Wallet execution record was not found.',
      );
    }
    return record;
  }

  void _validateBoundRecord(
    KeeperHubExecutionRecord record, {
    required bool requireAttestation,
  }) {
    KeeperHubProofPolicy.validateProofTransfer(
      transfer: record.transfer,
      expectedAgentWallet: record.agentWalletAddress,
    );
    final simulation = record.simulation;
    final fingerprint = record.simulationFingerprint;
    final idempotencyKey = record.idempotencyKey;
    if (simulation == null || fingerprint == null || idempotencyKey == null) {
      throw const KeeperHubException(
        'execution_binding_missing',
        'The Agent Wallet execution is missing its simulation binding.',
      );
    }
    if (!simulation.success ||
        simulation.wouldRevert ||
        simulation.valueWei != '0' ||
        simulation.from.toLowerCase() !=
            record.agentWalletAddress.toLowerCase() ||
        simulation.to.toLowerCase() !=
            record.agentWalletAddress.toLowerCase()) {
      throw const KeeperHubException(
        'execution_simulation_invalid',
        'The stored Agent Wallet simulation is no longer safe.',
      );
    }
    final expectedFingerprint = KeeperHubProofPolicy.simulationFingerprint(
      transfer: record.transfer,
      simulation: simulation,
    );
    final expectedIdempotency = KeeperHubProofPolicy.idempotencyKey(
      taskId: record.taskId,
      recipientAddress: record.agentWalletAddress,
    );
    if (fingerprint != expectedFingerprint ||
        idempotencyKey != expectedIdempotency) {
      throw const KeeperHubException(
        'execution_binding_mismatch',
        'The stored Agent Wallet execution does not match its reviewed binding.',
      );
    }
    if (requireAttestation && record.attestationDigest == null) {
      throw const KeeperHubException(
        'execution_not_attested',
        'The Agent Wallet execution has no device-authenticated approval.',
      );
    }
  }

  void close() => _api.close();
}
