import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'native_bridge.dart';
import 'paid_provider_approval_broker.dart';
import 'paid_provider_http_client.dart';
import 'paid_provider_proxy_models.dart';
import 'x402_payment_service.dart';
import 'x402_payment_transport_service.dart';

typedef BlockRunWalletStatusReader = Future<SecureWalletStatus> Function();

/// Executes the exact BlockRun x402 v2 request sequence. Every paid retry is
/// bound to one foreground approval and one device-authenticated EIP-3009
/// signature. A consumed request fingerprint is never sent again blindly.
class BlockRunPaidProviderProxyHandler {
  BlockRunPaidProviderProxyHandler({
    required PaidProviderHttpClient httpClient,
    PaidProviderApprovalBroker? approvals,
    X402PaymentApprovalService? paymentApprovals,
    X402PaymentReceiptStore? receiptStore,
    X402AuthorizationSigner? signer,
    BlockRunWalletStatusReader? walletStatus,
    DateTime Function()? clock,
  })  : _httpClient = httpClient,
        _approvals = approvals ?? PaidProviderApprovalBroker.instance,
        _paymentApprovals = paymentApprovals ??
            X402PaymentApprovalService(clock: clock ?? DateTime.now),
        _receiptStore = receiptStore ?? X402PaymentReceiptStore(),
        _signer = signer ?? NativeBridge.signSecureX402Authorization,
        _walletStatus = walletStatus ?? NativeBridge.getSecureEvmWalletStatus,
        _clock = clock ?? DateTime.now;

  final PaidProviderHttpClient _httpClient;
  final PaidProviderApprovalBroker _approvals;
  final X402PaymentApprovalService _paymentApprovals;
  final X402PaymentReceiptStore _receiptStore;
  final X402AuthorizationSigner _signer;
  final BlockRunWalletStatusReader _walletStatus;
  final DateTime Function() _clock;

  final Set<String> _inFlightFingerprints = <String>{};
  final Map<String, X402PaymentReceipt> _consumedFingerprints =
      <String, X402PaymentReceipt>{};

  Future<PaidProviderProxyResponse> call(
    PaidProviderProxyRequest request,
  ) async {
    if (request.provider != PaidProviderId.blockrun ||
        request.route.provider != PaidProviderId.blockrun) {
      throw const PaidProviderProxyException(
        'The BlockRun handler received another provider.',
        code: 'provider_route_mismatch',
      );
    }
    if (request.route.kind != PaidProviderProxyRouteKind.chatCompletions) {
      return _httpClient.send(request);
    }

    final modelId = request.gatewayModelId?.trim() ?? '';
    final encodedBody = request.encodedJsonBodyBytes;
    if (!modelId.startsWith('blockrun/') ||
        modelId.length == 'blockrun/'.length ||
        encodedBody == null) {
      throw const PaidProviderProxyException(
        'A namespaced BlockRun model and exact request body are required.',
        code: 'invalid_provider_model',
      );
    }
    // Human approval is asynchronous. Freeze the mapped bytes before the first
    // send so neither an internal caller nor later request reuse can alter the
    // fingerprinted payload while approval is pending.
    final bodyBytes = List<int>.unmodifiable(encodedBody);
    final upstreamUri = _httpClient.upstreamUriFor(request.route);
    final fingerprint = _fingerprint(
      provider: request.provider,
      method: request.route.method,
      uri: upstreamUri,
      bodyBytes: bodyBytes,
    );
    await _rejectConsumedFingerprint(fingerprint);
    if (!_inFlightFingerprints.add(fingerprint)) {
      throw const PaidProviderProxyException(
        'This exact BlockRun request is already awaiting payment.',
        code: 'payment_request_busy',
        statusCode: HttpStatus.conflict,
      );
    }

    try {
      return await _sendWithPaymentIfRequired(
        request: request,
        upstreamUri: upstreamUri,
        modelId: modelId,
        bodyBytes: bodyBytes,
        fingerprint: fingerprint,
      );
    } finally {
      _inFlightFingerprints.remove(fingerprint);
    }
  }

  Future<PaidProviderProxyResponse> _sendWithPaymentIfRequired({
    required PaidProviderProxyRequest request,
    required Uri upstreamUri,
    required String modelId,
    required List<int> bodyBytes,
    required String fingerprint,
  }) async {
    final initial = await _httpClient.send(
      request,
      exactRequestBodyBytes: bodyBytes,
    );
    if (initial.statusCode != HttpStatus.paymentRequired) return initial;

    final challengeHeader = _header(initial.headers, 'payment-required') ??
        _header(initial.headers, 'x-payment-required');
    await initial.openBodyStream().drain<void>();
    if (challengeHeader == null || challengeHeader.isEmpty) {
      throw const PaidProviderProxyException(
        'BlockRun returned 402 without a payment challenge.',
        code: 'payment_challenge_missing',
        statusCode: HttpStatus.badGateway,
      );
    }

    late X402PaymentChallenge challenge;
    late PendingPaymentIntent intent;
    try {
      challenge = X402PaymentChallenge.fromHeader(
        challengeHeader,
        policy: const X402PaymentPolicy(allowedHosts: <String>{'blockrun.ai'}),
      );
      intent = _paymentApprovals.createIntent(
        challenge: challenge,
        requestMethod: request.route.method,
        requestUrl: upstreamUri,
        requestBody: bodyBytes,
      );
    } on X402PaymentPolicyException catch (error) {
      if (_paymentApprovals.activeIntent != null) {
        throw const PaidProviderProxyException(
          'Another BlockRun payment request is already active.',
          code: 'payment_request_busy',
          statusCode: HttpStatus.conflict,
        );
      }
      throw PaidProviderProxyException(
        error.message,
        code: 'payment_challenge_invalid',
        statusCode: HttpStatus.badGateway,
      );
    }

    await _persistStateOrThrow(
      _receiptForIntent(
        intent: intent,
        state: X402PaymentState.awaitingHumanApproval,
        providerId: 'blockrun',
        modelId: modelId,
        requestFingerprint: fingerprint,
        paidRetryConsumed: false,
      ),
      intentId: intent.intentId,
    );

    final pending = PendingPaidProviderApproval(
      intentId: intent.intentId,
      provider: PaidProviderId.blockrun,
      modelId: modelId,
      amountUnits: challenge.requirement.amount,
      asset: 'USDC',
      network: 'Base Mainnet',
      payTo: challenge.requirement.payTo,
      resource: challenge.resourceUrl,
      expiresAt: intent.expiresAt,
      requestFingerprint: fingerprint,
      reason: 'Pay for one BlockRun model request.',
    );

    late PaidProviderApprovalDecision decision;
    try {
      decision = await _approvals.requestApproval(pending);
    } on PaidProviderApprovalException catch (error) {
      await _rejectAndPersistSafely(
        intent: intent,
        state: X402PaymentState.failed,
        modelId: modelId,
        requestFingerprint: fingerprint,
        errorCode: error.code,
      );
      throw PaidProviderProxyException(
        error.message,
        code: error.code,
        statusCode: HttpStatus.serviceUnavailable,
      );
    }
    if (decision != PaidProviderApprovalDecision.approved) {
      await _rejectAndPersistSafely(
        intent: intent,
        state: decision == PaidProviderApprovalDecision.expired
            ? X402PaymentState.expired
            : X402PaymentState.rejected,
        modelId: modelId,
        requestFingerprint: fingerprint,
        errorCode: decision.name,
      );
      throw PaidProviderProxyException(
        decision == PaidProviderApprovalDecision.expired
            ? 'The BlockRun payment approval expired.'
            : 'The BlockRun payment was cancelled.',
        code: decision == PaidProviderApprovalDecision.expired
            ? 'payment_approval_expired'
            : 'payment_cancelled',
        statusCode: HttpStatus.conflict,
      );
    }

    late SecureWalletStatus wallet;
    try {
      wallet = await _walletStatus();
    } catch (_) {
      await _rejectAndPersistSafely(
        intent: intent,
        state: X402PaymentState.failed,
        modelId: modelId,
        requestFingerprint: fingerprint,
        errorCode: 'WALLET_STATUS_UNAVAILABLE',
      );
      throw const PaidProviderProxyException(
        'The secure Base wallet status could not be verified.',
        code: 'wallet_status_unavailable',
        statusCode: HttpStatus.serviceUnavailable,
      );
    }
    final walletAddress = wallet.address?.trim() ?? '';
    if (!wallet.isConnected ||
        !wallet.authenticationAvailable ||
        !wallet.hardwareBacked ||
        !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(walletAddress)) {
      await _rejectAndPersistSafely(
        intent: intent,
        state: X402PaymentState.failed,
        modelId: modelId,
        requestFingerprint: fingerprint,
        errorCode: 'WALLET_NOT_READY',
      );
      throw const PaidProviderProxyException(
        'A healthy hardware-backed Base wallet is required.',
        code: 'wallet_not_ready',
        statusCode: HttpStatus.serviceUnavailable,
      );
    }

    late PendingPaymentIntent claimed;
    late String paymentHeader;
    try {
      final ticket = _paymentApprovals.approve(
        intent.intentId,
        source: PaymentApprovalSource.visibleUi,
      );
      claimed = _paymentApprovals.claimForSigning(ticket);
      paymentHeader = await _signPaymentHeader(
        claimed,
        walletAddress: walletAddress,
      );
    } catch (error) {
      await _recordTerminalSafely(
        intentId: intent.intentId,
        state: X402PaymentState.failed,
        providerId: 'blockrun',
        modelId: modelId,
        requestFingerprint: fingerprint,
        errorCode: 'SIGNING_FAILED',
        paidRetryConsumed: false,
      );
      throw const PaidProviderProxyException(
        'The authenticated BlockRun payment signature was not created.',
        code: 'payment_signing_failed',
        statusCode: HttpStatus.serviceUnavailable,
      );
    }

    _paymentApprovals.markSubmitted(claimed.intentId);
    await _persistStateOrThrow(
      _receiptForIntent(
        intent: claimed,
        state: X402PaymentState.submitted,
        providerId: 'blockrun',
        modelId: modelId,
        requestFingerprint: fingerprint,
        paidRetryConsumed: true,
      ),
      intentId: claimed.intentId,
      paidRetryWasPrepared: true,
    );
    _rememberConsumed(
      fingerprint,
      _receiptForIntent(
        intent: claimed,
        state: X402PaymentState.submitted,
        providerId: 'blockrun',
        modelId: modelId,
        requestFingerprint: fingerprint,
        paidRetryConsumed: true,
      ),
    );
    PaidProviderProxyResponse paidResponse;
    try {
      paidResponse = await _httpClient.send(
        request,
        exactRequestBodyBytes: bodyBytes,
        upstreamHeaders: <String, String>{
          'PAYMENT-SIGNATURE': paymentHeader,
        },
      );
    } catch (_) {
      await _recordTerminalSafely(
        intentId: claimed.intentId,
        state: X402PaymentState.uncertain,
        providerId: 'blockrun',
        modelId: modelId,
        requestFingerprint: fingerprint,
        errorCode: 'PAID_RETRY_UNCERTAIN',
        paidRetryConsumed: true,
      );
      rethrow;
    }

    if (paidResponse.statusCode == HttpStatus.paymentRequired) {
      await paidResponse.openBodyStream().drain<void>();
      await _recordTerminalSafely(
        intentId: claimed.intentId,
        state: X402PaymentState.failed,
        providerId: 'blockrun',
        modelId: modelId,
        requestFingerprint: fingerprint,
        errorCode: 'PAID_RETRY_REJECTED',
        httpStatus: paidResponse.statusCode,
        paidRetryConsumed: true,
      );
      throw const PaidProviderProxyException(
        'BlockRun rejected the one permitted paid retry.',
        code: 'paid_retry_rejected',
        statusCode: HttpStatus.badGateway,
      );
    }

    final receiptHeader = _header(paidResponse.headers, 'x-payment-receipt') ??
        _header(paidResponse.headers, 'payment-response') ??
        _header(paidResponse.headers, 'x-payment-response');
    final transactionHash = _transactionHash(receiptHeader);
    await _recordTerminalSafely(
      intentId: claimed.intentId,
      state: transactionHash == null
          ? X402PaymentState.uncertain
          : X402PaymentState.settled,
      providerId: 'blockrun',
      modelId: modelId,
      requestFingerprint: fingerprint,
      transactionHash: transactionHash,
      errorCode: transactionHash == null ? 'PAYMENT_RECEIPT_MISSING' : null,
      httpStatus: paidResponse.statusCode,
      paidRetryConsumed: true,
    );
    return paidResponse;
  }

  Future<String> _signPaymentHeader(
    PendingPaymentIntent intent, {
    required String walletAddress,
  }) async {
    final now = _clock().toUtc();
    final validAfter =
        now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch ~/ 1000;
    final validBefore = intent.expiresAt.millisecondsSinceEpoch ~/ 1000;
    final requirement = intent.challenge.requirement;
    final signed = await _signer(<String, dynamic>{
      'host': intent.requestUrl.host,
      'chainId': 8453,
      'verifyingContract': requirement.asset,
      'from': walletAddress,
      'to': requirement.payTo,
      'value': requirement.amount,
      'validAfter': validAfter,
      'validBefore': validBefore,
      'nonce': intent.paymentNonce,
      'name': requirement.extra['name']?.toString(),
      'version': requirement.extra['version']?.toString(),
    });
    final signature = signed['signature']?.toString() ?? '';
    final payer = signed['payer']?.toString() ?? '';
    if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature) ||
        payer.toLowerCase() != walletAddress.toLowerCase()) {
      throw const FormatException('The secure wallet signature is invalid.');
    }
    final authorization = <String, dynamic>{
      'from': payer,
      'to': requirement.payTo,
      'value': requirement.amount,
      'validAfter': validAfter,
      'validBefore': validBefore,
      'nonce': intent.paymentNonce,
    };
    return base64Encode(utf8.encode(jsonEncode(<String, dynamic>{
      'x402Version': intent.challenge.x402Version,
      'resource': intent.challenge.resource,
      'accepted': requirement.toJson(),
      'payload': <String, dynamic>{
        'signature': signature,
        'authorization': authorization,
      },
    })));
  }

  Future<void> _recordTerminalSafely({
    required String intentId,
    required X402PaymentState state,
    required String providerId,
    required String modelId,
    required String requestFingerprint,
    required bool paidRetryConsumed,
    String? transactionHash,
    String? errorCode,
    int? httpStatus,
  }) async {
    X402PaymentReceipt receipt;
    try {
      receipt = _paymentApprovals.recordReceipt(
        intentId: intentId,
        state: state,
        transactionHash: transactionHash,
        errorCode: errorCode,
        providerId: providerId,
        httpStatus: httpStatus,
        requestFingerprint: requestFingerprint,
        modelId: modelId,
        paidRetryConsumed: paidRetryConsumed,
      );
    } catch (_) {
      return;
    }
    if (paidRetryConsumed) {
      _rememberConsumed(requestFingerprint, receipt);
    }
    try {
      await _receiptStore.append(receipt);
    } catch (_) {
      // Keep the process-local recovery fence even if durable storage is
      // temporarily unavailable; never make a paid retry look safely replayable.
    }
  }

  Future<void> _rejectAndPersistSafely({
    required PendingPaymentIntent intent,
    required X402PaymentState state,
    required String modelId,
    required String requestFingerprint,
    required String errorCode,
  }) async {
    _rejectIntentSafely(intent.intentId);
    final base = _receiptForIntent(
      intent: intent,
      state: state,
      providerId: 'blockrun',
      modelId: modelId,
      requestFingerprint: requestFingerprint,
      paidRetryConsumed: false,
    );
    final receipt = X402PaymentReceipt(
      intentId: base.intentId,
      state: base.state,
      recordedAt: base.recordedAt,
      errorCode: errorCode,
      providerId: base.providerId,
      network: base.network,
      asset: base.asset,
      amount: base.amount,
      payTo: base.payTo,
      resourceUrl: base.resourceUrl,
      challengeHash: base.challengeHash,
      requestFingerprint: base.requestFingerprint,
      modelId: base.modelId,
      paidRetryConsumed: false,
    );
    try {
      await _receiptStore.append(receipt);
    } catch (_) {
      // No paid retry was sent, so persistence loss cannot hide a settlement.
    }
  }

  X402PaymentReceipt _receiptForIntent({
    required PendingPaymentIntent intent,
    required X402PaymentState state,
    required String providerId,
    required String modelId,
    required String requestFingerprint,
    required bool paidRetryConsumed,
  }) {
    final requirement = intent.challenge.requirement;
    return X402PaymentReceipt(
      intentId: intent.intentId,
      state: state,
      recordedAt: _clock().toUtc(),
      providerId: providerId,
      network: requirement.network,
      asset: requirement.asset,
      amount: requirement.amount,
      payTo: requirement.payTo,
      resourceUrl: intent.requestUrl.toString(),
      challengeHash: intent.challenge.challengeHash,
      requestFingerprint: requestFingerprint,
      modelId: modelId,
      paidRetryConsumed: paidRetryConsumed,
    );
  }

  Future<void> _persistStateOrThrow(
    X402PaymentReceipt receipt, {
    required String intentId,
    bool paidRetryWasPrepared = false,
  }) async {
    try {
      await _receiptStore.append(receipt);
    } catch (_) {
      if (paidRetryWasPrepared) {
        await _recordTerminalSafely(
          intentId: intentId,
          state: X402PaymentState.failed,
          providerId: receipt.providerId ?? 'blockrun',
          modelId: receipt.modelId ?? '',
          requestFingerprint: receipt.requestFingerprint ?? '',
          errorCode: 'RECEIPT_PERSISTENCE_FAILED',
          paidRetryConsumed: false,
        );
      } else {
        _rejectIntentSafely(intentId);
      }
      throw const PaidProviderProxyException(
        'Payment recovery storage is unavailable; no paid request was sent.',
        code: 'payment_receipts_unavailable',
        statusCode: HttpStatus.serviceUnavailable,
      );
    }
  }

  Future<void> _rejectConsumedFingerprint(String fingerprint) async {
    if (_consumedFingerprints.containsKey(fingerprint)) {
      throw const PaidProviderProxyException(
        'This exact paid request already consumed its retry; inspect receipts before retrying.',
        code: 'payment_recovery_required',
        statusCode: HttpStatus.conflict,
      );
    }
    try {
      final receipts = await _receiptStore.read();
      for (final receipt in receipts) {
        if (receipt.requestFingerprint == fingerprint &&
            receipt.paidRetryConsumed) {
          _rememberConsumed(fingerprint, receipt);
          throw const PaidProviderProxyException(
            'This exact paid request already consumed its retry; inspect receipts before retrying.',
            code: 'payment_recovery_required',
            statusCode: HttpStatus.conflict,
          );
        }
      }
    } on PaidProviderProxyException {
      rethrow;
    } catch (_) {
      throw const PaidProviderProxyException(
        'Payment recovery storage is unavailable; retry safety cannot be verified.',
        code: 'payment_receipts_unavailable',
        statusCode: HttpStatus.serviceUnavailable,
      );
    }
  }

  void _rememberConsumed(String fingerprint, X402PaymentReceipt receipt) {
    _consumedFingerprints[fingerprint] = receipt;
    while (_consumedFingerprints.length > 64) {
      _consumedFingerprints.remove(_consumedFingerprints.keys.first);
    }
  }

  void _rejectIntentSafely(String intentId) {
    try {
      _paymentApprovals.reject(intentId);
    } catch (_) {}
  }

  String _fingerprint({
    required PaidProviderId provider,
    required String method,
    required Uri uri,
    required List<int> bodyBytes,
  }) {
    final prefix = utf8.encode(
      '${provider.wireName}\u0000${method.toUpperCase()}\u0000$uri\u0000',
    );
    return sha256.convert(<int>[...prefix, ...bodyBytes]).toString();
  }

  String? _header(Map<String, String> headers, String name) {
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) return entry.value;
    }
    return null;
  }

  String? _transactionHash(String? receipt) {
    if (receipt == null || receipt.length > 32 * 1024) return null;
    final direct = receipt.trim();
    if (RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(direct)) return direct;
    dynamic decoded;
    try {
      decoded = jsonDecode(direct);
    } catch (_) {
      try {
        decoded = jsonDecode(
          utf8.decode(base64.decode(base64.normalize(direct))),
        );
      } catch (_) {
        return null;
      }
    }
    return _findTransactionHash(decoded);
  }

  String? _findTransactionHash(dynamic value, [int depth = 0]) {
    if (depth > 5) return null;
    if (value is Map) {
      for (final key in const <String>[
        'transactionHash',
        'transaction',
        'txHash',
        'tx_hash',
      ]) {
        final candidate = value[key]?.toString();
        if (candidate != null &&
            RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(candidate)) {
          return candidate;
        }
      }
      for (final nested in value.values) {
        final found = _findTransactionHash(nested, depth + 1);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final nested in value) {
        final found = _findTransactionHash(nested, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  void close() => _httpClient.close();
}
