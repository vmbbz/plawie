import 'dart:convert';
import 'dart:math';

import 'paid_provider_proxy_models.dart';

class PaidProviderTurnAuthorizationException implements Exception {
  const PaidProviderTurnAuthorizationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() =>
      'PaidProviderTurnAuthorizationException($code): $message';
}

class PaidProviderTurnLease {
  const PaidProviderTurnLease({
    required this.leaseId,
    required this.conversationId,
    required this.provider,
    required this.modelId,
    required this.createdAt,
    required this.expiresAt,
    required this.remainingProxyCalls,
    required this.remainingPaymentApprovals,
  });

  final String leaseId;
  final String conversationId;
  final PaidProviderId provider;
  final String modelId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int remainingProxyCalls;
  final int remainingPaymentApprovals;

  PaidProviderTurnLease consumeOne() => PaidProviderTurnLease(
        leaseId: leaseId,
        conversationId: conversationId,
        provider: provider,
        modelId: modelId,
        createdAt: createdAt,
        expiresAt: expiresAt,
        remainingProxyCalls: remainingProxyCalls - 1,
        remainingPaymentApprovals: remainingPaymentApprovals,
      );

  PaidProviderTurnLease consumePaymentApproval() => PaidProviderTurnLease(
        leaseId: leaseId,
        conversationId: conversationId,
        provider: provider,
        modelId: modelId,
        createdAt: createdAt,
        expiresAt: expiresAt,
        remainingProxyCalls: remainingProxyCalls,
        remainingPaymentApprovals: remainingPaymentApprovals - 1,
      );
}

/// Holds one process-local authorization for a user-visible paid-provider turn.
///
/// Only foreground UI code calls [authorizeForegroundUserTurn]. The Gateway
/// proxy can consume the lease, but cannot create or extend one. No lease is
/// persisted, logged, exposed to OpenClaw, or treated as a payment approval.
class PaidProviderTurnAuthorizationService {
  PaidProviderTurnAuthorizationService({
    DateTime Function()? clock,
    String Function()? leaseIdFactory,
    this.maxProxyCalls = 8,
    this.maxPaymentApprovals = 1,
    this.leaseLifetime = const Duration(minutes: 10),
  })  : _clock = clock ?? DateTime.now,
        _leaseIdFactory = leaseIdFactory ?? _secureLeaseId {
    if (maxProxyCalls <= 0 ||
        maxPaymentApprovals <= 0 ||
        leaseLifetime <= Duration.zero) {
      throw ArgumentError('Paid-provider turn bounds must be positive.');
    }
  }

  static final PaidProviderTurnAuthorizationService instance =
      PaidProviderTurnAuthorizationService();

  final DateTime Function() _clock;
  final String Function() _leaseIdFactory;
  final int maxProxyCalls;
  final int maxPaymentApprovals;
  final Duration leaseLifetime;

  bool _appForeground = false;
  PaidProviderTurnLease? _activeLease;

  bool get isAppForeground => _appForeground;
  PaidProviderTurnLease? get activeLease => _activeLease;

  void markAppForeground() {
    _appForeground = true;
  }

  void markAppBackground() {
    _appForeground = false;
    _activeLease = null;
  }

  PaidProviderTurnLease authorizeForegroundUserTurn({
    required String conversationId,
    required PaidProviderId provider,
    required String modelId,
  }) {
    if (!_appForeground) {
      throw const PaidProviderTurnAuthorizationException(
        'app_not_foreground',
        'Paid-provider turns can only start from the foreground chat UI.',
      );
    }
    final normalizedConversation = conversationId.trim();
    final normalizedModel = modelId.trim();
    final prefix = '${provider.wireName}/';
    if (normalizedConversation.isEmpty ||
        !normalizedModel.startsWith(prefix) ||
        normalizedModel.length == prefix.length) {
      throw const PaidProviderTurnAuthorizationException(
        'invalid_foreground_turn',
        'The foreground conversation and provider model are required.',
      );
    }
    final createdAt = _clock().toUtc();
    final lease = PaidProviderTurnLease(
      leaseId: _leaseIdFactory(),
      conversationId: normalizedConversation,
      provider: provider,
      modelId: normalizedModel,
      createdAt: createdAt,
      expiresAt: createdAt.add(leaseLifetime),
      remainingProxyCalls: maxProxyCalls,
      remainingPaymentApprovals: maxPaymentApprovals,
    );
    if (lease.leaseId.trim().isEmpty) {
      throw StateError('Paid-provider lease identifier is empty.');
    }
    _activeLease = lease;
    return lease;
  }

  PaidProviderTurnLease consumeForProxy({
    required PaidProviderId provider,
    required String gatewayModelId,
  }) {
    final lease = _requireMatchingLease(
      provider: provider,
      gatewayModelId: gatewayModelId,
    );
    if (lease.remainingProxyCalls <= 0) {
      throw const PaidProviderTurnAuthorizationException(
        'foreground_turn_exhausted',
        'The foreground provider turn reached its request limit.',
      );
    }
    final consumed = lease.consumeOne();
    _activeLease = consumed;
    return consumed;
  }

  /// Claims the single visible payment boundary attached to this user turn.
  /// A changed request body, Gateway retry, or tool loop cannot mint another
  /// approval. The user must send a new foreground message for another charge.
  PaidProviderTurnLease claimPaymentApprovalForProxy({
    required PaidProviderId provider,
    required String gatewayModelId,
  }) {
    final lease = _requireMatchingLease(
      provider: provider,
      gatewayModelId: gatewayModelId,
    );
    if (lease.remainingPaymentApprovals <= 0) {
      throw const PaidProviderTurnAuthorizationException(
        'foreground_payment_limit_reached',
        'This message already used its one payment approval. Send a new message to authorize another paid model call.',
      );
    }
    final consumed = lease.consumePaymentApproval();
    _activeLease = consumed;
    return consumed;
  }

  PaidProviderTurnLease _requireMatchingLease({
    required PaidProviderId provider,
    required String gatewayModelId,
  }) {
    if (!_appForeground) {
      _activeLease = null;
      throw const PaidProviderTurnAuthorizationException(
        'foreground_turn_required',
        'A foreground user turn is required for this provider.',
      );
    }
    final lease = _activeLease;
    if (lease == null) {
      throw const PaidProviderTurnAuthorizationException(
        'foreground_turn_required',
        'A foreground user turn is required for this provider.',
      );
    }
    final now = _clock().toUtc();
    if (!now.isBefore(lease.expiresAt)) {
      _activeLease = null;
      throw const PaidProviderTurnAuthorizationException(
        'foreground_turn_expired',
        'The foreground provider turn expired.',
      );
    }
    if (lease.provider != provider || lease.modelId != gatewayModelId.trim()) {
      throw const PaidProviderTurnAuthorizationException(
        'foreground_turn_mismatch',
        'The provider request does not match the visible user turn.',
      );
    }
    return lease;
  }

  void closeLease(String leaseId) {
    if (_activeLease?.leaseId == leaseId) _activeLease = null;
  }

  static String _secureLeaseId() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      18,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
