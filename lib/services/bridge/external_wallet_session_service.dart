import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import 'bridge_models.dart';

enum SolanaWalletSubmissionMode { signOnly, signAndSend }

sealed class SolanaWalletSubmissionResult {
  const SolanaWalletSubmissionResult();

  SolanaWalletSubmissionMode get mode;
}

final class SignedSolanaTransaction extends SolanaWalletSubmissionResult {
  const SignedSolanaTransaction(this.signedTransaction);

  final Uint8List signedTransaction;

  @override
  SolanaWalletSubmissionMode get mode => SolanaWalletSubmissionMode.signOnly;
}

final class SubmittedSolanaTransaction extends SolanaWalletSubmissionResult {
  const SubmittedSolanaTransaction(this.signature);

  final String signature;

  @override
  SolanaWalletSubmissionMode get mode => SolanaWalletSubmissionMode.signAndSend;
}

final class ExternalWalletOption extends Equatable {
  const ExternalWalletOption({
    required this.transport,
    required this.label,
    required this.available,
    this.reason,
  });

  final ExternalWalletTransport transport;
  final String label;
  final bool available;
  final String? reason;

  @override
  List<Object?> get props => <Object?>[transport, label, available, reason];
}

final class ExternalWalletIdentity extends Equatable {
  const ExternalWalletIdentity({
    required this.transport,
    required this.walletLabel,
    required this.publicAddress,
    required this.chainId,
    required this.chainType,
    required this.approvedMethods,
    required this.approvedFeatures,
  });

  final ExternalWalletTransport transport;
  final String walletLabel;
  final String publicAddress;
  final int chainId;
  final BridgeChainType chainType;
  final Set<String> approvedMethods;
  final Set<String> approvedFeatures;

  Map<String, Object> toSafeJson() {
    final methods = approvedMethods.toList()..sort();
    final features = approvedFeatures.toList()..sort();
    return <String, Object>{
      'transport': transport.name,
      'walletLabel': walletLabel,
      'publicAddress': publicAddress,
      'chainId': chainId,
      'chainType': chainType.name,
      'approvedMethods': methods,
      'approvedFeatures': features,
    };
  }

  @override
  List<Object?> get props => <Object?>[
        transport,
        walletLabel,
        publicAddress,
        chainId,
        chainType,
        approvedMethods,
        approvedFeatures,
      ];
}

final class ExternalWalletException implements Exception {
  const ExternalWalletException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => message.isEmpty
      ? 'ExternalWalletException: $code'
      : 'ExternalWalletException: $code ($message)';
}

abstract interface class ExternalWalletSessionService {
  Future<List<ExternalWalletOption>> discover(BridgeChain chain);

  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  });

  Future<void> disconnect();

  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload);

  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  );

  ExternalWalletIdentity? get identity;
}

abstract interface class ExternalWalletSessionTransport {
  Future<List<ExternalWalletOption>> discover(BridgeChain chain);

  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  });

  Future<void> disconnect();

  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload);

  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  );
}

abstract interface class ExternalWalletAdapter {
  ExternalWalletTransport get transport;

  Future<ExternalWalletOption> discover(BridgeChain chain);

  Future<ExternalWalletIdentity> connect(BridgeChain chain);

  Future<void> disconnect();

  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload);

  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  );
}

final class RoutedExternalWalletSessionService
    implements ExternalWalletSessionService {
  RoutedExternalWalletSessionService({
    required ExternalWalletSessionTransport transport,
    DateTime Function()? clock,
    String Function()? operationIdFactory,
  })  : _transport = transport,
        _clock = clock ?? DateTime.now,
        _operationIdFactory = operationIdFactory ?? _secureOperationId;

  static const Duration operationTtl = Duration(minutes: 10);

  final ExternalWalletSessionTransport _transport;
  final DateTime Function() _clock;
  final String Function() _operationIdFactory;

  ExternalWalletIdentity? _identity;
  _PendingWalletOperation? _pending;

  @override
  ExternalWalletIdentity? get identity => _identity;

  @override
  Future<List<ExternalWalletOption>> discover(BridgeChain chain) =>
      _transport.discover(chain);

  @override
  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  }) async {
    if (_identity != null) {
      throw const ExternalWalletException('wallet_already_connected');
    }
    final expectedTransport = transport ??
        (chain.type == BridgeChainType.evm
            ? ExternalWalletTransport.reownEvm
            : ExternalWalletTransport.solanaMwa);
    final connected = await _runOperation<ExternalWalletIdentity>(
      transport: expectedTransport,
      method: 'connect',
      account: '',
      chainId: chain.id,
      reviewedFingerprint: _fingerprint(<Object?>[
        'connect',
        chain.id,
        chain.type.name,
        transport?.name ?? 'automatic',
      ]),
      action: () async {
        final result = await _transport.connect(chain, transport: transport);
        try {
          _validateIdentity(result, chain, requested: transport);
        } on ExternalWalletException {
          await _transport.disconnect();
          rethrow;
        }
        return result;
      },
    );
    _identity = connected;
    return connected;
  }

  @override
  Future<void> disconnect() async {
    _pending = null;
    _identity = null;
    try {
      await _transport.disconnect();
    } on ExternalWalletException {
      rethrow;
    } catch (_) {
      throw const ExternalWalletException('wallet_disconnect_failed');
    }
  }

  @override
  Future<String> sendEvmTransaction(
    EvmBridgeExecutionPayload payload,
  ) async {
    final current = _requireIdentity(BridgeChainType.evm);
    if (current.chainId != payload.chainId) {
      throw const ExternalWalletException('wallet_chain_mismatch');
    }
    if (!_sameEvmAddress(current.publicAddress, payload.from)) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    if (!current.approvedMethods.contains('eth_sendTransaction')) {
      throw const ExternalWalletException('wallet_method_not_approved');
    }
    return _runOperation<String>(
      transport: current.transport,
      method: 'eth_sendTransaction',
      account: current.publicAddress,
      chainId: current.chainId,
      reviewedFingerprint: _fingerprint(<Object?>[
        payload.chainId,
        payload.from.toLowerCase(),
        payload.to.toLowerCase(),
        payload.valueHex,
        payload.dataHex,
        payload.gasLimitHex,
        payload.approvalAddress?.toLowerCase(),
      ]),
      action: () => _transport.sendEvmTransaction(payload),
    );
  }

  @override
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  ) async {
    final current = _requireIdentity(BridgeChainType.svm);
    if (current.chainId != BridgeConstants.solanaChainId) {
      throw const ExternalWalletException('wallet_chain_mismatch');
    }
    if (current.publicAddress != payload.from) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    final method = current.approvedMethods.contains('solana_signTransaction')
        ? 'solana_signTransaction'
        : current.approvedMethods.contains('solana_signAndSendTransaction')
            ? 'solana_signAndSendTransaction'
            : null;
    if (method == null) {
      throw const ExternalWalletException('wallet_method_not_approved');
    }
    return _runOperation<SolanaWalletSubmissionResult>(
      transport: current.transport,
      method: method,
      account: current.publicAddress,
      chainId: current.chainId,
      reviewedFingerprint: _fingerprint(<Object?>[
        payload.from,
        payload.base64Transaction,
      ]),
      action: () => _transport.submitSolanaTransaction(payload),
    );
  }

  ExternalWalletIdentity _requireIdentity(BridgeChainType type) {
    final current = _identity;
    if (current == null) {
      throw const ExternalWalletException('wallet_not_connected');
    }
    if (current.chainType != type) {
      throw const ExternalWalletException('wallet_chain_type_mismatch');
    }
    return current;
  }

  Future<T> _runOperation<T>({
    required ExternalWalletTransport transport,
    required String method,
    required String account,
    required int chainId,
    required String reviewedFingerprint,
    required Future<T> Function() action,
  }) async {
    final existing = _pending;
    if (existing != null) {
      if (!_clock().toUtc().isBefore(existing.expiresAt)) {
        _pending = null;
        throw const ExternalWalletException('wallet_operation_expired');
      }
      throw const ExternalWalletException('wallet_operation_in_progress');
    }

    final operationId = _operationIdFactory();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(operationId)) {
      throw const ExternalWalletException('wallet_operation_id_invalid');
    }
    final now = _clock().toUtc();
    final operation = _PendingWalletOperation(
      id: operationId,
      transport: transport,
      method: method,
      account: account,
      chainId: chainId,
      reviewedFingerprint: reviewedFingerprint,
      expiresAt: now.add(operationTtl),
    );
    _pending = operation;

    try {
      final result = await action();
      if (!identical(_pending, operation)) {
        throw const ExternalWalletException('wallet_operation_invalidated');
      }
      if (!_clock().toUtc().isBefore(operation.expiresAt)) {
        _pending = null;
        throw const ExternalWalletException('wallet_operation_expired');
      }
      _pending = null;
      return result;
    } on ExternalWalletException {
      if (identical(_pending, operation)) _pending = null;
      rethrow;
    } catch (_) {
      if (identical(_pending, operation)) _pending = null;
      throw const ExternalWalletException('wallet_request_failed');
    }
  }
}

final class _PendingWalletOperation {
  const _PendingWalletOperation({
    required this.id,
    required this.transport,
    required this.method,
    required this.account,
    required this.chainId,
    required this.reviewedFingerprint,
    required this.expiresAt,
  });

  final String id;
  final ExternalWalletTransport transport;
  final String method;
  final String account;
  final int chainId;
  final String reviewedFingerprint;
  final DateTime expiresAt;
}

void _validateIdentity(
  ExternalWalletIdentity identity,
  BridgeChain chain, {
  ExternalWalletTransport? requested,
}) {
  if (identity.chainId != chain.id || identity.chainType != chain.type) {
    throw const ExternalWalletException('wallet_chain_mismatch');
  }
  if (requested != null && identity.transport != requested) {
    throw const ExternalWalletException('wallet_transport_mismatch');
  }
  final validAddress = switch (chain.type) {
    BridgeChainType.evm =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(identity.publicAddress),
    BridgeChainType.svm =>
      RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(identity.publicAddress),
  };
  if (!validAddress) {
    throw const ExternalWalletException('wallet_account_invalid');
  }
  if (identity.walletLabel.trim().isEmpty) {
    throw const ExternalWalletException('wallet_identity_invalid');
  }
}

bool _sameEvmAddress(String left, String right) =>
    left.toLowerCase() == right.toLowerCase();

String _fingerprint(List<Object?> fields) =>
    sha256.convert(utf8.encode(jsonEncode(fields))).toString();

String _secureOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
